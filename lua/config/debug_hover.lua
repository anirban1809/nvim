local M = {}

local state = {
  generation = 0,
}

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function reset()
  state.win = nil
  state.buf = nil
  state.source_win = nil
  state.source_buf = nil
  state.source_cursor = nil
  state.session = nil
  state.root = nil
  state.line_nodes = nil
end

local function close_window()
  if valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if valid_buf(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  reset()
end

function M.close()
  state.generation = state.generation + 1
  close_window()
end

local function node_text(node)
  local result = tostring(node.value or "")
  local type_name = node.type and node.type ~= "" and (" [" .. node.type .. "]") or ""
  return node.name .. (result ~= "" and (" = " .. result) or "") .. type_name
end

local function append_visible(node, depth, lines, line_nodes)
  local expandable = node.reference > 0 and node.has_children ~= false
  local marker = expandable and (node.expanded and "- " or "+ ") or "  "
  lines[#lines + 1] = string.rep("  ", depth) .. marker .. node_text(node)
  line_nodes[#lines] = node

  if node.expanded then
    for _, child in ipairs(node.children or {}) do
      append_visible(child, depth + 1, lines, line_nodes)
    end
  end
end

local function render()
  if not valid_win(state.win) or not valid_buf(state.buf) or not state.root then
    return
  end

  local lines = {}
  local line_nodes = {}
  append_visible(state.root, 0, lines, line_nodes)
  state.line_nodes = line_nodes

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  vim.api.nvim_win_set_config(state.win, {
    width = math.min(width, math.max(20, math.floor(vim.o.columns * 0.8))),
    height = math.min(#lines, math.max(1, math.floor(vim.o.lines * 0.5))),
  })

  local row = math.min(vim.api.nvim_win_get_cursor(state.win)[1], #lines)
  vim.api.nvim_win_set_cursor(state.win, { math.max(row, 1), 0 })
end

local function selected_node()
  if not valid_win(state.win) or not state.line_nodes then
    return
  end
  return state.line_nodes[vim.api.nvim_win_get_cursor(state.win)[1]]
end

local function load_children(node, done)
  if node.reference <= 0 or node.children_loaded then
    done()
    return
  end

  local generation = state.generation
  local session = state.session
  session:request("variables", { variablesReference = node.reference }, function(err, response)
    if generation ~= state.generation or session ~= state.session then
      return
    end

    local variables = not err and response and response.variables or {}
    node.children = {}
    node.children_loaded = true
    node.has_children = #variables > 0

    for index, variable in ipairs(variables) do
      if index > 100 then
        node.children[#node.children + 1] = {
          name = "...",
          value = "more fields omitted",
          reference = 0,
        }
        break
      end
      node.children[#node.children + 1] = {
        name = variable.name,
        value = variable.value,
        type = variable.type,
        reference = tonumber(variable.variablesReference) or 0,
        expanded = false,
        has_children = (tonumber(variable.variablesReference) or 0) > 0,
      }
    end

    done()
  end)
end

local function toggle_selected()
  local node = selected_node()
  if not node or node.reference <= 0 then
    return
  end

  if node.expanded then
    node.expanded = false
    render()
    return
  end

  load_children(node, function()
    vim.schedule(function()
      if valid_win(state.win) and node.has_children then
        node.expanded = true
        render()
      end
    end)
  end)
end

function M.toggle_focus()
  local dap = package.loaded.dap
  if not dap or not dap.session() then
    return false
  end

  if not valid_win(state.win) then
    return true
  end
  if vim.api.nvim_get_current_win() == state.win then
    if valid_win(state.source_win) then
      vim.api.nvim_set_current_win(state.source_win)
    end
  else
    vim.api.nvim_set_current_win(state.win)
  end
  return true
end

local function set_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, nowait = true }
  vim.keymap.set("n", "<Up>", "k", vim.tbl_extend("force", opts, { desc = "Debug Hover: Previous Value" }))
  vim.keymap.set("n", "<Down>", "j", vim.tbl_extend("force", opts, { desc = "Debug Hover: Next Value" }))
  vim.keymap.set("n", "<CR>", toggle_selected, vim.tbl_extend("force", opts, {
    desc = "Debug Hover: Expand or Collapse",
  }))
  vim.keymap.set("n", "<Esc>", M.toggle_focus, vim.tbl_extend("force", opts, { desc = "Debug Hover: Focus Editor" }))
end

local function open(root, session, source_win, source_buf, source_cursor, generation)
  vim.schedule(function()
    local dap = package.loaded.dap
    if generation ~= state.generation
      or not dap
      or dap.session() ~= session
      or not valid_win(source_win)
      or not valid_buf(source_buf)
      or vim.api.nvim_get_current_win() ~= source_win
      or vim.api.nvim_get_current_buf() ~= source_buf
      or not vim.deep_equal(vim.api.nvim_win_get_cursor(source_win), source_cursor) then
      return
    end

    close_window()
    state.session = session
    state.source_win = source_win
    state.source_buf = source_buf
    state.source_cursor = source_cursor
    state.root = root
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].filetype = "dap-value-hover"

    state.win = vim.api.nvim_open_win(state.buf, false, {
      relative = "cursor",
      row = 1,
      col = 0,
      width = 1,
      height = 1,
      border = "rounded",
      focusable = true,
      style = "minimal",
      zindex = 60,
    })
    vim.wo[state.win].wrap = false
    vim.wo[state.win].cursorline = true
    set_keymaps(state.buf)
    render()
  end)
end

function M.show(session, expression, source_win, source_buf, source_cursor)
  local frame = session.current_frame
  if not frame or expression == "" then
    return
  end

  M.close()
  local generation = state.generation
  session:request("evaluate", {
    expression = expression,
    frameId = frame.id,
    context = session.capabilities.supportsEvaluateForHovers and "hover" or "repl",
  }, function(err, response)
    if generation ~= state.generation or err or not response or response.result == nil then
      return
    end

    local root = {
      name = expression,
      value = response.result,
      type = response.type,
      reference = tonumber(response.variablesReference) or 0,
      expanded = true,
      has_children = (tonumber(response.variablesReference) or 0) > 0,
    }
    state.session = session
    load_children(root, function()
      open(root, session, source_win, source_buf, source_cursor, generation)
    end)
  end)
end

vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("debug_value_hover", { clear = true }),
  callback = function(event)
    if event.buf == state.source_buf and vim.api.nvim_get_current_win() == state.source_win then
      M.close()
    end
  end,
})

return M
