local function map(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

local editor_modes = { "n", "i", "v" }
local closed_files = {}

local function save_as()
  vim.ui.input({
    prompt = "Save as: ",
    default = vim.fn.expand("%:p"),
    completion = "file",
  }, function(path)
    if path and path ~= "" then
      vim.cmd.saveas(vim.fn.fnameescape(path))
    end
  end)
end

local function goto_line()
  vim.ui.input({ prompt = "Go to line: " }, function(value)
    local line = tonumber(value)
    if line then
      vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(line, vim.api.nvim_buf_line_count(0))), 0 })
    end
  end)
end

local function focus_window(index)
  local win = vim.fn.win_getid(index)
  if win ~= 0 then
    vim.fn.win_gotoid(win)
  end
end

local function search_selection()
  vim.cmd.normal({ args = { '"zy' }, bang = true })
  local text = vim.fn.getreg("z"):gsub("\n", "\\n")
  vim.fn.setreg("/", "\\V" .. vim.fn.escape(text, "\\"))
  vim.cmd.normal({ args = { "n" }, bang = true })
end

local function select_current_word()
  vim.cmd.normal({ args = { "viw" }, bang = true })
end

local function select_adjacent_word(direction)
  local anchor = vim.fn.getpos("v")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local anchor_pos = { anchor[2], anchor[3] - 1 }
  local cursor_before_anchor = cursor[1] < anchor_pos[1]
    or (cursor[1] == anchor_pos[1] and cursor[2] < anchor_pos[2])
  local start_pos = cursor_before_anchor and cursor or anchor_pos
  local end_pos = cursor_before_anchor and anchor_pos or cursor

  vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  vim.api.nvim_win_set_cursor(0, direction > 0 and end_pos or start_pos)
  vim.cmd.normal({ args = { direction > 0 and "wviw" or "bviw" }, bang = true })
end

vim.api.nvim_create_autocmd("BufDelete", {
  group = vim.api.nvim_create_augroup("vscode_closed_files", { clear = true }),
  callback = function(event)
    local name = vim.api.nvim_buf_get_name(event.buf)
    if name ~= "" and vim.bo[event.buf].buftype == "" then
      if closed_files[#closed_files] ~= name then
        table.insert(closed_files, name)
      end
    end
  end,
})

local function reopen_closed_file()
  while #closed_files > 0 do
    local file = table.remove(closed_files)
    if vim.uv.fs_stat(file) then
      vim.cmd.edit(vim.fn.fnameescape(file))
      return
    end
  end
  vim.notify("No recently closed file", vim.log.levels.INFO)
end

-- Leave insert mode, then write the buffer. Only saves real, modified, writable
-- file buffers, so [No Name], terminal, prompt, and read-only buffers are left
-- alone (and unchanged buffers don't trigger BufWritePre formatting on every Esc).
local function escape_and_save()
  vim.cmd("stopinsert")
  if vim.bo.buftype == ""
    and vim.bo.modifiable
    and not vim.bo.readonly
    and vim.bo.modified
    and vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd("silent! write")
  end
end

map("n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")
map("n", "<CR>", "i", "Enter Insert Mode")
map("x", "<CR>", '"_c', "Replace Selection")
for _, key in ipairs({
  "i", "I", "a", "A", "o", "O", "gi", "gI", "c", "C", "s", "S",
  "<Insert>", "<D-CR>", "<D-S-CR>",
}) do
  map("n", key, "<Nop>", "Disabled: Use Enter for Insert Mode")
end

-- Files and editor tabs
map(editor_modes, "<D-s>", "<cmd>write<CR>", "File: Save")
map("i", "<Esc>", escape_and_save, "Insert: Exit Insert Mode and Save")
map(editor_modes, "<D-S-s>", save_as, "File: Save As")
map(editor_modes, "<D-n>", "<cmd>enew<CR>", "File: New Untitled File")
map(editor_modes, "<D-o>", "<cmd>Telescope find_files<CR>", "File: Open")
map(editor_modes, "<D-p>", "<cmd>Telescope find_files<CR>", "Go to File")
map(editor_modes, "<D-S-p>", "<cmd>Telescope commands<CR>", "Show All Commands")
map(editor_modes, "<F1>", "<cmd>Telescope commands<CR>", "Show All Commands")
map("n", "<D-w>", "<cmd>confirm bdelete<CR>", "View: Close Editor")
map(editor_modes, "<D-S-x>", "<cmd>confirm bdelete<CR>", "View: Close Editor")
map("t", "<D-w>", "<C-\\><C-n><cmd>close<CR>", "View: Close Terminal")
map("n", "<D-S-w>", "<cmd>confirm qall<CR>", "Window: Close")
-- `:exit` -> save every buffer and quit, without prompts.
-- `exit` is a built-in command and user commands must be uppercase, so use a
-- guarded command-line abbreviation that only fires for a bare `:exit`.
vim.cmd([[cnoreabbrev <expr> exit (getcmdtype() ==# ':' && getcmdline() ==# 'exit') ? 'wqall' : 'exit']])
map("n", "<D-S-t>", reopen_closed_file, "View: Reopen Closed Editor")
map("n", "<C-Tab>", "<cmd>bnext<CR>", "View: Open Next Editor")
map("n", "<C-S-Tab>", "<cmd>bprevious<CR>", "View: Open Previous Editor")
map("n", "<D-S-]>", "<cmd>bnext<CR>", "View: Open Next Editor")
map("n", "<D-S-[>", "<cmd>bprevious<CR>", "View: Open Previous Editor")
map("n", "<D-,>", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end, "Preferences: Open Settings")

-- Search and navigation
map("n", "<D-f>", "/", "Find")
map("i", "<D-f>", "<Esc>/", "Find")
map("x", "<D-f>", search_selection, "Find Selection")
map("n", "<D-e>", "*", "Find With Selection")
map("x", "<D-e>", search_selection, "Find With Selection")
map("n", "<Tab>", "nzzzv", "Find Next")
map("n", "<S-Tab>", "Nzzzv", "Find Previous")
vim.cmd([[
  cnoremap <expr> <Tab> getcmdtype() =~# '[/?]' ? "\<C-G>" : "\<Tab>"
  cnoremap <expr> <S-Tab> getcmdtype() =~# '[/?]' ? "\<C-T>" : "\<S-Tab>"
]])
map("n", "<D-g>", "nzzzv", "Find Next")
map("n", "<D-S-g>", "Nzzzv", "Find Previous")
map("n", "<D-S-f>", "<cmd>Telescope live_grep<CR>", "Search: Find in Files")
map("n", "<D-S-h>", "<cmd>GrugFar<CR>", "Search: Replace in Files")
map("n", "<M-D-f>", ":%s/", "Replace")
map("x", "<M-D-f>", ":s/", "Replace in Selection")
map("n", "<D-t>", "<cmd>Telescope lsp_workspace_symbols<CR>", "Go to Symbol in Workspace")
map("n", "<D-S-o>", "<cmd>Telescope lsp_document_symbols<CR>", "Go to Symbol in Editor")
map("n", "<C-g>", goto_line, "Go to Line")
map("n", "<C-->", "<C-o>", "Go Back")
map("n", "<C-S-->", "<C-i>", "Go Forward")

-- Workbench
map("n", "<D-b>", "<cmd>NvimTreeToggle<CR>", "View: Toggle Primary Side Bar")
map("n", "<D-S-e>", "<cmd>NvimTreeFocus<CR>", "View: Show Explorer")
map("n", "<C-S-g>", "<cmd>Telescope git_status<CR>", "View: Show Source Control")
map("n", "<D-S-m>", "<cmd>Trouble diagnostics toggle<CR>", "View: Show Problems")
map({ "n", "t" }, "<D-j>", "<cmd>ToggleTerm direction=horizontal<CR>", "View: Toggle Panel")
map({ "n", "t" }, "<C-S-`>", "<cmd>ToggleTerm direction=horizontal<CR>", "Terminal: New Terminal")

-- Editor groups
map("n", "<D-\\>", "<cmd>vsplit<CR>", "View: Split Editor Right")
map("n", "<D-k><D-\\>", "<cmd>split<CR>", "View: Split Editor Down")
map("n", "<D-k><D-Left>", "<C-w>h", "View: Focus Left Group")
map("n", "<D-k><D-Down>", "<C-w>j", "View: Focus Below Group")
map("n", "<D-k><D-Up>", "<C-w>k", "View: Focus Above Group")
map("n", "<D-k><D-Right>", "<C-w>l", "View: Focus Right Group")
map("n", "<D-0>", "<cmd>NvimTreeFocus<CR>", "View: Focus Side Bar")
for index = 1, 8 do
  map("n", "<D-" .. index .. ">", function()
    focus_window(index)
  end, "View: Focus Editor Group " .. index)
end

-- Selection, clipboard, undo, and redo
map("n", "<D-a>", "ggVG", "Select All")
map("i", "<D-a>", "<Esc>ggVG", "Select All")
map("x", "<D-a>", "<Esc>ggVG", "Select All")
map("n", "<D-c>", '"+yy', "Copy Line")
map("i", "<D-c>", '<C-o>"+yy', "Copy Line")
map("x", "<D-c>", '"+y', "Copy")
map("n", "<D-x>", '"+dd', "Cut Line")
map("x", "<D-x>", '"+d', "Cut")
map("n", "<D-v>", '"+p', "Paste")
map("x", "<D-v>", '"_d"+P', "Paste")
map("i", "<D-v>", "<C-r>+", "Paste")
map("n", "<D-z>", "u", "Undo")
map("i", "<D-z>", "<C-o>u", "Undo")
map("x", "<D-z>", "<Esc>u", "Undo")
map("n", "<D-S-z>", "<C-r>", "Redo")
map("i", "<D-S-z>", "<C-o><C-r>", "Redo")
map("x", "<D-S-z>", "<Esc><C-r>", "Redo")
map("n", "<D-l>", "V", "Expand Line Selection")
map("x", "<D-l>", function()
  return vim.fn.mode() == "V" and "j" or "V"
end, "Expand Line Selection", { expr = true })
map("n", "w", select_current_word, "Select Current Word")
map("x", "w", function()
  select_adjacent_word(1)
end, "Select Next Word")
map("n", "q", select_current_word, "Select Current Word")
map("x", "q", function()
  select_adjacent_word(-1)
end, "Select Previous Word")
map("n", "{", "va{", "Select Enclosing Braces")
map("n", "(", "va(", "Select Enclosing Parentheses")
map("n", "[", "va[", "Select Enclosing Brackets")

-- Cursor movement
map("n", "<D-Left>", "b", "Cursor Word Left")
map("n", "<D-Right>", "w", "Cursor Word Right")
map("n", "<D-Up>", "gg", "Cursor Top")
map("n", "<D-Down>", "G", "Cursor Bottom")
map("i", "<D-Left>", "<C-o>b", "Cursor Word Left")
map("i", "<D-Right>", "<C-o>w", "Cursor Word Right")
map("i", "<D-Up>", "<C-o>gg", "Cursor Top")
map("i", "<D-Down>", "<C-o>G", "Cursor Bottom")
map("x", "<D-Left>", "b", "Cursor Word Left")
map("x", "<D-Right>", "w", "Cursor Word Right")
map("n", "<D-S-Left>", "vb", "Select Word Left")
map("n", "<D-S-Right>", "vw", "Select Word Right")
map("n", "<D-S-Up>", "vgg", "Cursor Top Select")
map("n", "<D-S-Down>", "vG", "Cursor Bottom Select")
map("i", "<D-S-Left>", "<Esc>vb", "Select Word Left")
map("i", "<D-S-Right>", "<Esc>vw", "Select Word Right")
map("i", "<D-S-Up>", "<Esc>vgg", "Cursor Top Select")
map("i", "<D-S-Down>", "<Esc>vG", "Cursor Bottom Select")
map("x", "<D-S-Left>", "b", "Select Word Left")
map("x", "<D-S-Right>", "w", "Select Word Right")
local function set_visual_arrow_keymaps(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    for _, key in ipairs({ "<Left>", "<Right>", "<Up>", "<Down>" }) do
      pcall(vim.keymap.del, "x", key, { buffer = bufnr })
    end
    return
  end

  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("x", "<Left>", "<Esc><Left>", vim.tbl_extend("force", opts, {
    desc = "Clear Selection and Move Left",
  }))
  vim.keymap.set("x", "<Right>", "<Esc><Right>", vim.tbl_extend("force", opts, {
    desc = "Clear Selection and Move Right",
  }))
  vim.keymap.set("x", "<Up>", "<Esc><Up>", vim.tbl_extend("force", opts, {
    desc = "Clear Selection and Move Up",
  }))
  vim.keymap.set("x", "<Down>", "<Esc><Down>", vim.tbl_extend("force", opts, {
    desc = "Clear Selection and Move Down",
  }))
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("editor_visual_arrow_keymaps", { clear = true }),
  callback = function(event)
    set_visual_arrow_keymaps(event.buf)
  end,
})
set_visual_arrow_keymaps(0)

map("n", "<S-Left>", "v<Left>", "Select Left")
map("n", "<S-Right>", "v<Right>", "Select Right")
map("i", "<S-Left>", "<Esc>v<Left>", "Select Left")
map("i", "<S-Right>", "<Esc>v<Right>", "Select Right")
map("x", "<S-Left>", "<Left>", "Select Left")
map("x", "<S-Right>", "<Right>", "Select Right")
map("n", "<S-Up>", "V<Up>", "Select Line Up")
map("n", "<S-Down>", "V<Down>", "Select Line Down")
map("i", "<S-Up>", "<Esc>V<Up>", "Select Line Up")
map("i", "<S-Down>", "<Esc>V<Down>", "Select Line Down")
map("x", "<S-Up>", function()
  return vim.fn.mode() == "V" and "k" or "Vk"
end, "Select Line Up", { expr = true })
map("x", "<S-Down>", function()
  return vim.fn.mode() == "V" and "j" or "Vj"
end, "Select Line Down", { expr = true })

-- Line editing
map("n", "<M-Down>", "<cmd>move .+1<CR>==", "Move Line Down")
map("n", "<M-Up>", "<cmd>move .-2<CR>==", "Move Line Up")
map("i", "<M-Down>", "<Esc><cmd>move .+1<CR>==gi", "Move Line Down")
map("i", "<M-Up>", "<Esc><cmd>move .-2<CR>==gi", "Move Line Up")
map("x", "<M-Down>", ":move '>+1<CR>gv=gv", "Move Selection Down")
map("x", "<M-Up>", ":move '<-2<CR>gv=gv", "Move Selection Up")
map("n", "<S-M-Down>", "<cmd>copy .<CR>", "Copy Line Down")
map("n", "<S-M-Up>", "<cmd>copy .-1<CR>", "Copy Line Up")
map("x", "<S-M-Down>", ":copy '><CR>gv", "Copy Selection Down")
map("x", "<S-M-Up>", ":copy '<-1<CR>gv", "Copy Selection Up")
map("n", "<D-S-k>", "dd", "Delete Line")
map("i", "<D-S-k>", "<Esc>ddi", "Delete Line")
map("x", "<D-S-k>", "d", "Delete Selection")
map("i", "<D-CR>", "<Esc>o", "Insert Line Below")
map("i", "<D-S-CR>", "<Esc>O", "Insert Line Above")
map("i", "<D-BS>", "<C-u>", "Delete All Left")
map("i", "<D-Del>", "<C-o>D", "Delete All Right")
map("n", "<D-]>", ">>", "Indent Line")
map("n", "<D-[>", "<<", "Outdent Line")
map("x", "<D-]>", ">gv", "Indent Lines")
map("x", "<D-[>", "<gv", "Outdent Lines")
map("i", "<D-]>", "<C-t>", "Indent Line")
map("i", "<D-[>", "<C-d>", "Outdent Line")

-- Folding
map("n", "<M-D-[>", "zc", "Fold")
map("n", "<M-D-]>", "zo", "Unfold")
map("n", "<D-k><D-0>", "zM", "Fold All")
map("n", "<D-k><D-j>", "zR", "Unfold All")
for level = 1, 7 do
  map("n", "<D-k><D-" .. level .. ">", "<cmd>setlocal foldlevel=" .. level .. "<CR>", "Fold Level " .. level)
end
