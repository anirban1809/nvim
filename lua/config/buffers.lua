local M = {}

local storage_path = vim.fs.joinpath(vim.fn.stdpath("state"), "open-buffers.json")

local function normalize_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function working_directory()
  return normalize_path(vim.fn.getcwd())
end

local function is_path_in_directory(path, directory)
  local relative = vim.fs.relpath(directory, path)
  return relative and relative ~= ".." and not relative:match("^%.%.[/\\]")
end

function M.listed_file_buffers()
  local buffers = {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if vim.api.nvim_buf_is_valid(info.bufnr) and vim.bo[info.bufnr].buftype == "" then
      buffers[#buffers + 1] = info.bufnr
    end
  end
  table.sort(buffers)
  return buffers
end

local function adjacent_buffer(bufnr)
  local buffers = M.listed_file_buffers()
  local index = vim.fn.index(buffers, bufnr) + 1
  if index == 0 then
    return
  end
  return buffers[index + 1] or buffers[index - 1]
end

function M.close_current()
  local win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.bo[current_buf].buftype ~= "" then
    vim.cmd.close()
    return
  end

  local target_buf = adjacent_buffer(current_buf)
  vim.cmd("confirm bdelete " .. current_buf)
  if vim.api.nvim_buf_is_valid(current_buf) and vim.bo[current_buf].buflisted then
    return
  end

  if target_buf
    and vim.api.nvim_buf_is_valid(target_buf)
    and vim.bo[target_buf].buflisted
    and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_buf(win, target_buf)
    vim.api.nvim_set_current_win(win)
  end
end

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
  local path = normalize_path(name)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "file" and path or nil
end

local function read_storage()
  local ok, lines = pcall(vim.fn.readfile, storage_path)
  if not ok or #lines == 0 then
    return nil
  end

  local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(data) ~= "table" then
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

local function workspace_storage(data)
  if type(data) ~= "table" then
    return {}
  end
  if type(data.workspaces) == "table" then
    return data.workspaces
  end
  return {}
end

local function legacy_session_for_directory(data, directory)
  if type(data) ~= "table" or type(data.buffers) ~= "table" then
    return nil
  end

  local buffers = {}
  local seen = {}
  for _, path in ipairs(data.buffers) do
    if type(path) == "string" then
      local normalized = normalize_path(path)
      if not seen[normalized] and is_path_in_directory(normalized, directory) then
        buffers[#buffers + 1] = normalized
        seen[normalized] = true
      end
    end
  end
  if #buffers == 0 then
    return nil
  end

  local current = type(data.current) == "string" and normalize_path(data.current) or nil
  if not current or not seen[current] then
    current = buffers[1]
  end

  return {
    current = current,
    buffers = buffers,
  }
end

local function session_for_directory(data, directory)
  local workspaces = workspace_storage(data)
  local session = workspaces[directory]
  if type(session) == "table" and type(session.buffers) == "table" then
    return session
  end
  return legacy_session_for_directory(data, directory)
end

local function save_buffers()
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local directory = working_directory()
  local buffers = {}
  local seen = {}
  local current = buffer_path(vim.api.nvim_get_current_buf())
  local most_recent
  local most_recent_time = -1

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local path = buffer_path(info.bufnr)
    if path and is_path_in_directory(path, directory) and not seen[path] then
      buffers[#buffers + 1] = path
      seen[path] = true
      if info.lastused > most_recent_time then
        most_recent = path
        most_recent_time = info.lastused
      end
    end
  end

  if current and not seen[current] then
    current = nil
  end

  local data = read_storage() or {}
  local workspaces = workspace_storage(data)
  workspaces[directory] = {
    current = current or most_recent,
    buffers = buffers,
    updated_at = os.time(),
  }

  write_storage({
    version = 2,
    workspaces = workspaces,
  })
end

local function restore_buffers(directory_args)
  local directory = working_directory()
  local session = session_for_directory(read_storage(), directory)
  if not session then
    return
  end

  local buffers = {}
  local seen = {}
  for _, path in ipairs(session.buffers) do
    if type(path) == "string" then
      local normalized = normalize_path(path)
      if not seen[normalized] and is_path_in_directory(normalized, directory) then
        local stat = vim.uv.fs_stat(normalized)
        if stat and stat.type == "file" then
          buffers[#buffers + 1] = normalized
          seen[normalized] = true
        end
      end
    end
  end
  if #buffers == 0 then
    return
  end

  local current = type(session.current) == "string" and normalize_path(session.current) or nil
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
    local path = normalize_path(argument)
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
  vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter" }, {
    group = group,
    callback = schedule_save,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(event)
      local affected_windows = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == event.buf then
          affected_windows[#affected_windows + 1] = win
        end
      end
      local target_buf = vim.bo[event.buf].buftype == "" and adjacent_buffer(event.buf) or nil

      vim.schedule(function()
        if target_buf
          and vim.api.nvim_buf_is_valid(target_buf)
          and vim.bo[target_buf].buflisted then
          for _, win in ipairs(affected_windows) do
            if vim.api.nvim_win_is_valid(win) then
              vim.api.nvim_win_set_buf(win, target_buf)
            end
          end
        end
      end)
      schedule_save()
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = save_buffers,
  })
end

return M
