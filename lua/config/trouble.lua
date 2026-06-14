local M = {}

local last_editor_win
local setup_done = false

local function is_trouble_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "trouble"
end

local function is_debug_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  if vim.w[win].dapview_win or vim.w[win].dapview_win_term then
    return true
  end
  local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
  return filetype == "dap-view"
    or filetype == "dap-view-hover"
    or filetype == "dap-value-hover"
    or filetype == "dap-repl"
end

local function debugging()
  local dap = package.loaded.dap
  return dap and dap.session() ~= nil
end

local function trouble_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_trouble_window(win) then
      return win
    end
  end
end

function M.editor_window()
  if last_editor_win and vim.api.nvim_win_is_valid(last_editor_win) then
    return last_editor_win
  end
end

function M.open()
  if debugging() then
    return
  end
  require("trouble").open({ mode = "diagnostics", focus = false })
end

function M.close()
  if package.loaded.trouble then
    require("trouble").close({ mode = "diagnostics" })
  end
end

function M.next_error()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr, {
    severity = vim.diagnostic.severity.ERROR,
  })
  if #diagnostics == 0 then
    vim.notify("No errors in the current file", vim.log.levels.INFO)
    return
  end

  table.sort(diagnostics, function(left, right)
    return left.lnum < right.lnum
      or (left.lnum == right.lnum and left.col < right.col)
  end)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row, current_col = cursor[1] - 1, cursor[2]
  local target = diagnostics[1]
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.lnum > current_row
      or (diagnostic.lnum == current_row and diagnostic.col > current_col) then
      target = diagnostic
      break
    end
  end

  vim.api.nvim_win_set_cursor(0, { target.lnum + 1, target.col })
  vim.cmd.normal({ args = { "zz" }, bang = true })
  vim.diagnostic.open_float(bufnr, {
    scope = "cursor",
    focus = false,
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  })
end

function M.toggle()
  local win = trouble_window()
  if win then
    local current_win = vim.api.nvim_get_current_win()
    M.close()
    if is_trouble_window(current_win)
      and last_editor_win
      and vim.api.nvim_win_is_valid(last_editor_win) then
      vim.api.nvim_set_current_win(last_editor_win)
    end
    return
  end

  if debugging() then
    return
  end

  local current_win = vim.api.nvim_get_current_win()
  if not is_debug_window(current_win) then
    last_editor_win = current_win
  end
  require("trouble").open({ mode = "diagnostics", focus = true })
end

function M.toggle_focus()
  local current_win = vim.api.nvim_get_current_win()
  if is_trouble_window(current_win) then
    if last_editor_win and vim.api.nvim_win_is_valid(last_editor_win) then
      vim.api.nvim_set_current_win(last_editor_win)
    else
      vim.cmd.wincmd("p")
    end
    return
  end

  if debugging() then
    return
  end

  if not is_debug_window(current_win) then
    last_editor_win = current_win
  end

  local win = trouble_window()
  if not win then
    require("trouble").open({ mode = "diagnostics" })
    return
  end
  vim.api.nvim_set_current_win(win)
end

function M.debug_started()
  M.close()
end

function M.debug_stopped()
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  vim.api.nvim_create_autocmd("WinEnter", {
    group = vim.api.nvim_create_augroup("trouble_focus", { clear = true }),
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if not is_trouble_window(win) and not is_debug_window(win) then
        last_editor_win = win
      end
    end,
  })

  local current_win = vim.api.nvim_get_current_win()
  if not is_trouble_window(current_win) and not is_debug_window(current_win) then
    last_editor_win = current_win
  end

end

return M
