local parsers = {
  "bash", "c", "cpp", "cmake", "css", "diff", "dockerfile",
  "go", "gomod", "gosum", "gowork",
  "html", "javascript", "json", "lua", "luadoc",
  "make", "markdown", "markdown_inline", "python",
  "regex", "rust", "toml", "tsx", "typescript",
  "vim", "vimdoc", "yaml",
}

local selection_stack = {}

local function sync_parsers()
  local treesitter = require("nvim-treesitter")
  treesitter.setup({})
  treesitter.update(parsers, { summary = true }):wait(300000)
  treesitter.install(parsers, { summary = true }):wait(300000)
end

local function select_node(node)
  local start_row, start_col, end_row, end_col = node:range()
  if end_col == 0 then
    end_row = end_row - 1
    end_col = #(vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or "")
  end
  if end_row < start_row then
    return
  end

  if vim.fn.mode():match("[vV\22]") then
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  vim.cmd.normal({ args = { "v" }, bang = true })
  vim.api.nvim_win_set_cursor(0, { end_row + 1, math.max(0, end_col - 1) })
end

local function grow_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local stack = selection_stack[bufnr]

  if vim.fn.mode() ~= "v" or not stack or #stack == 0 then
    local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not parser_ok then
      return
    end
    parser:parse()

    local node = vim.treesitter.get_node({ bufnr = bufnr })
    if not node then
      return
    end
    stack = { node }
    selection_stack[bufnr] = stack
    select_node(node)
    return
  end

  local parent = stack[#stack]:parent()
  if parent then
    stack[#stack + 1] = parent
    select_node(parent)
  end
end

local function shrink_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local stack = selection_stack[bufnr]
  if not stack or #stack <= 1 then
    return
  end

  table.remove(stack)
  select_node(stack[#stack])
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = sync_parsers,
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.setup({})

      vim.treesitter.language.register("bash", "sh")
      vim.treesitter.language.register("json", "jsonc")
      vim.treesitter.language.register("javascript", "javascriptreact")
      vim.treesitter.language.register("tsx", "typescriptreact")

      local function start_treesitter(bufnr)
        local language = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
        local ok, parser_available = pcall(vim.treesitter.language.add, language)
        if not ok or not parser_available then
          return
        end

        vim.treesitter.start(bufnr, language)
        if language ~= "python" then
          vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(event)
          start_treesitter(event.buf)
        end,
      })
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype ~= "" then
          start_treesitter(bufnr)
        end
      end

      vim.keymap.set({ "n", "x" }, "<C-S-Right>", grow_selection, {
        desc = "Treesitter: Grow Selection",
      })
      vim.keymap.set("x", "<C-S-Left>", shrink_selection, {
        desc = "Treesitter: Shrink Selection",
      })
    end,
  },
}
