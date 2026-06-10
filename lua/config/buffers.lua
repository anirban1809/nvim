local M = {}

local storage_path = vim.fs.joinpath(vim.fn.stdpath("state"), "open-buffers.json")

local function buffer_path(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.bo[bufnr].buflisted
    or vim.bo[bufnr].buftype ~= "" then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  local path = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "file" and path or nil
end

local function read_storage()
  local ok, lines = pcall(vim.fn.readfile, storage_path)
  if not ok or #lines == 0 then
    return nil
  end

  local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(data) ~= "table" or type(data.buffers) ~= "table" then
    return nil
  end
  return data
end

local function write_storage(data)
  vim.fn.mkdir(vim.fs.dirname(storage_path), "p")
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return
  end

  local temporary_path = storage_path .. ".tmp"
  if vim.fn.writefile({ encoded }, temporary_path) == 0 then
    vim.uv.fs_rename(temporary_path, storage_path)
  end
end

local function save_buffers()
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local buffers = {}
  local seen = {}
  local current = buffer_path(vim.api.nvim_get_current_buf())
  local most_recent
  local most_recent_time = -1

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local path = buffer_path(info.bufnr)
    if path and not seen[path] then
      buffers[#buffers + 1] = path
      seen[path] = true
      if info.lastused > most_recent_time then
        most_recent = path
        most_recent_time = info.lastused
      end
    end
  end

  write_storage({
    version = 1,
    current = current or most_recent,
    buffers = buffers,
  })
end

local function restore_buffers(directory_args)
  local data = read_storage()
  if not data then
    return
  end

  local buffers = {}
  local seen = {}
  for _, path in ipairs(data.buffers) do
    if type(path) == "string" and not seen[path] then
      local stat = vim.uv.fs_stat(path)
      if stat and stat.type == "file" then
        buffers[#buffers + 1] = path
        seen[path] = true
      end
    end
  end
  if #buffers == 0 then
    return
  end

  local current = type(data.current) == "string" and data.current or nil
  if not current or not seen[current] then
    current = buffers[1]
  end

  vim.cmd.edit(vim.fn.fnameescape(current))
  for _, path in ipairs(buffers) do
    if path ~= current then
      local bufnr = vim.fn.bufadd(path)
      vim.bo[bufnr].buflisted = true
    end
  end

  for _, path in ipairs(directory_args) do
    local bufnr = vim.fn.bufnr(path)
    if bufnr > 0 and bufnr ~= vim.api.nvim_get_current_buf() then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

local function startup_directory_args()
  local directories = {}
  for _, argument in ipairs(vim.fn.argv()) do
    local path = vim.fs.normalize(vim.fn.fnamemodify(argument, ":p"))
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.type ~= "directory" then
      return nil
    end
    directories[#directories + 1] = path
  end
  return directories
end

function M.setup()
  local started_with_stdin = false
  local startup_complete = false
  local save_scheduled = false
  local group = vim.api.nvim_create_augroup("persistent_open_buffers", { clear = true })

  local function schedule_save()
    if not startup_complete or save_scheduled then
      return
    end
    save_scheduled = true
    vim.schedule(function()
      save_scheduled = false
      save_buffers()
    end)
  end

  vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function()
      started_with_stdin = true
    end,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      if started_with_stdin then
        return
      end

      local directory_args = startup_directory_args()
      if directory_args then
        vim.schedule(function()
          restore_buffers(directory_args)
          startup_complete = true
          schedule_save()
        end)
      else
        startup_complete = true
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter" }, {
    group = group,
    callback = schedule_save,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = save_buffers,
  })
end

return M
