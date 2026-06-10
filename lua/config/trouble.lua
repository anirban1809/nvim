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
  return filetype == "dap-view" or filetype == "dap-view-hover" or filetype == "dap-repl"
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
  local attempts = 0
  local function restore()
    if not debugging() then
      M.open()
      return
    end
    attempts = attempts + 1
    if attempts < 10 then
      vim.defer_fn(restore, 100)
    end
  end
  vim.defer_fn(restore, 100)
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

  vim.schedule(M.open)
end

return M
