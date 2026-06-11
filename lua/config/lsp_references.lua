local M = {}

local active

local function valid_window(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function window_view(win)
  return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

local function reference_item()
  if not active or not valid_window(active.list_win) then
    return
  end

  local index = vim.api.nvim_win_get_cursor(active.list_win)[1]
  local items = vim.fn.getqflist({ items = 0 }).items
  local item = items[index]
  if not item or item.valid ~= 1 then
    return
  end

  vim.fn.setqflist({}, "a", { idx = index })
  return item
end

local function item_buffer(item)
  if item.bufnr and item.bufnr > 0 then
    vim.fn.bufload(item.bufnr)
    return item.bufnr
  end
  if not item.filename or item.filename == "" then
    return
  end

  local bufnr = vim.fn.bufadd(item.filename)
  vim.fn.bufload(bufnr)
  return bufnr
end

local function preview()
  local item = reference_item()
  if not item or not valid_window(active.editor_win) then
    return
  end

  local bufnr = item_buffer(item)
  if not bufnr then
    return
  end

  vim.api.nvim_win_set_buf(active.editor_win, bufnr)
  vim.api.nvim_win_set_cursor(active.editor_win, {
    math.max(item.lnum, 1),
    math.max(item.col - 1, 0),
  })
  vim.api.nvim_win_call(active.editor_win, function()
    vim.cmd.normal({ args = { "zvzz" }, bang = true })
  end)
end

local function finish(restore)
  if not active then
    return
  end

  local state = active
  active = nil

  if valid_window(state.list_win) then
    vim.api.nvim_win_close(state.list_win, true)
  end
  if not valid_window(state.editor_win) then
    return
  end

  if restore and vim.api.nvim_buf_is_valid(state.origin_buf) then
    vim.api.nvim_win_set_buf(state.editor_win, state.origin_buf)
    vim.api.nvim_win_set_cursor(state.editor_win, state.origin_cursor)
    vim.api.nvim_win_call(state.editor_win, function()
      vim.fn.winrestview(state.origin_view)
    end)
  end
  vim.api.nvim_set_current_win(state.editor_win)
end

local function commit()
  preview()
  finish(false)
end

local function cancel()
  finish(true)
end

function M.open()
  local editor_win = vim.api.nvim_get_current_win()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_cursor = vim.api.nvim_win_get_cursor(editor_win)
  local origin_view = window_view(editor_win)

  vim.lsp.buf.references(nil, {
    on_list = function(options)
      vim.fn.setqflist({}, " ", options)
      vim.cmd("botright copen")

      local list_win = vim.api.nvim_get_current_win()
      local list_buf = vim.api.nvim_get_current_buf()
      active = {
        editor_win = editor_win,
        list_win = list_win,
        origin_buf = origin_buf,
        origin_cursor = origin_cursor,
        origin_view = origin_view,
      }

      local opts = { buffer = list_buf, silent = true }
      vim.keymap.set("n", "<CR>", commit, vim.tbl_extend("force", opts, {
        desc = "References: Open Selection",
      }))
      vim.keymap.set("n", "<Esc>", cancel, vim.tbl_extend("force", opts, {
        desc = "References: Cancel",
      }))
      vim.keymap.set("n", "q", cancel, vim.tbl_extend("force", opts, {
        desc = "References: Cancel",
      }))

      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = list_buf,
        callback = preview,
      })
      preview()
    end,
  })
end

return M
