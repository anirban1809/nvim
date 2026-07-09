local M = {}

local show_warnings = true
local installed = false

local handled_diagnostic_groups = {
  "signs",
  "underline",
  "virtual_text",
  "virtual_lines",
}

local visible_without_warnings = {
  vim.diagnostic.severity.ERROR,
  vim.diagnostic.severity.INFO,
  vim.diagnostic.severity.HINT,
}

local function is_go_buffer(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  return bufnr
    and vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].filetype == "go"
end

function M.warnings_visible(bufnr)
  return show_warnings or not is_go_buffer(bufnr)
end

function M.visible_severities(bufnr)
  if M.warnings_visible(bufnr) then
    return nil
  end
  return visible_without_warnings
end

function M.is_visible(diagnostic, bufnr)
  return M.warnings_visible(bufnr) or diagnostic.severity ~= vim.diagnostic.severity.WARN
end

local function filter_warnings(bufnr, diagnostics)
  if M.warnings_visible(bufnr) then
    return diagnostics
  end

  return vim.tbl_filter(function(diagnostic)
    return M.is_visible(diagnostic, bufnr)
  end, diagnostics)
end

function M.setup()
  if installed then
    return
  end
  installed = true

  for _, name in ipairs(handled_diagnostic_groups) do
    local handler = vim.diagnostic.handlers[name]
    if handler then
      vim.diagnostic.handlers[name] = setmetatable({
        show = function(namespace, bufnr, diagnostics, opts)
          handler.show(namespace, bufnr, filter_warnings(bufnr, diagnostics), opts)
        end,
        hide = function(namespace, bufnr)
          if handler.hide then
            handler.hide(namespace, bufnr)
          end
        end,
      }, { __index = handler })
    end
  end
end

local function refresh_go_diagnostics()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if is_go_buffer(bufnr) then
      vim.diagnostic.hide(nil, bufnr)
      vim.diagnostic.show(nil, bufnr)
    end
  end
end

function M.toggle()
  M.setup()
  show_warnings = not show_warnings
  refresh_go_diagnostics()

  local state = show_warnings and "shown" or "hidden"
  vim.notify("Go warnings " .. state, vim.log.levels.INFO, { title = "Diagnostics" })
end

return M
