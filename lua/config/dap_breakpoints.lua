local M = {}

local storage_path = vim.fs.joinpath(vim.fn.stdpath("state"), "dap-breakpoints.json")

local function buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or vim.bo[bufnr].buftype ~= "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

local function read_storage()
  local read_ok, lines = pcall(vim.fn.readfile, storage_path)
  if not read_ok or #lines == 0 then
    return { version = 1, files = {} }
  end

  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(data) ~= "table" or type(data.files) ~= "table" then
    vim.notify("Ignoring invalid breakpoint storage: " .. storage_path, vim.log.levels.WARN, { title = "DAP" })
    return { version = 1, files = {} }
  end
  return data
end

local function write_storage(data)
  vim.fn.mkdir(vim.fs.dirname(storage_path), "p")
  local temporary_path = storage_path .. ".tmp"
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    vim.notify("Could not encode persistent breakpoints", vim.log.levels.ERROR, { title = "DAP" })
    return
  end

  if vim.fn.writefile({ encoded }, temporary_path) ~= 0 or vim.uv.fs_rename(temporary_path, storage_path) == nil then
    vim.notify("Could not save breakpoints to " .. storage_path, vim.log.levels.ERROR, { title = "DAP" })
  end
end

function M.setup()
  local breakpoints = require("dap.breakpoints")
  local stored = read_storage()
  local restored = {}

  local function restore_buffer(bufnr)
    if restored[bufnr] or not vim.api.nvim_buf_is_loaded(bufnr) then
      return
    end

    local path = buffer_path(bufnr)
    if not path then
      return
    end
    restored[bufnr] = true

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    for _, breakpoint in ipairs(stored.files[path] or {}) do
      local line = tonumber(breakpoint.line)
      if line and line >= 1 and line <= line_count then
        breakpoints.set({
          condition = breakpoint.condition,
          hit_condition = breakpoint.hitCondition,
          log_message = breakpoint.logMessage,
        }, bufnr, line)
      end
    end
  end

  local function capture_buffer(bufnr)
    local path = buffer_path(bufnr)
    if not path then
      return
    end

    local captured = {}
    for _, breakpoint in ipairs((breakpoints.get(bufnr) or {})[bufnr] or {}) do
      captured[#captured + 1] = {
        line = breakpoint.line,
        condition = breakpoint.condition,
        hitCondition = breakpoint.hitCondition,
        logMessage = breakpoint.logMessage,
      }
    end
    table.sort(captured, function(left, right)
      return left.line < right.line
    end)
    stored.files[path] = #captured > 0 and captured or nil
  end

  local group = vim.api.nvim_create_augroup("dap_persistent_breakpoints", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(event)
      restore_buffer(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(event)
      capture_buffer(event.buf)
      write_storage(stored)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
          capture_buffer(bufnr)
        end
      end
      write_storage(stored)
    end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    restore_buffer(bufnr)
  end
end

return M
