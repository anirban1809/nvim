local M = {}

M.host_commands = { "nvim", "git", "make", "cc", "rg", "fd", "go", "node", "npm", "tree-sitter" }

M.mason_tools = {
  "clang-format",
  "clangd",
  "codelldb",
  "dlv",
  "eslint_d",
  "gofumpt",
  "goimports",
  "golines",
  "gopls",
  "js-debug-adapter",
  "lua-language-server",
  "prettier",
  "prettierd",
  "rust-analyzer",
  "stylua",
  "typescript-language-server",
}

M.treesitter_parsers = {
  "bash", "c", "cpp", "cmake", "css", "diff", "dockerfile",
  "go", "gomod", "gosum", "gowork",
  "html", "javascript", "json", "lua", "luadoc",
  "make", "markdown", "markdown_inline", "python",
  "regex", "rust", "toml", "tsx", "typescript",
  "vim", "vimdoc", "yaml",
}

function M.errors()
  local errors = {}
  for _, name in ipairs(M.host_commands) do
    if vim.fn.executable(name) ~= 1 then
      errors[#errors + 1] = "Missing host command: " .. name
    end
  end

  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin")
  for _, name in ipairs(M.mason_tools) do
    if not vim.uv.fs_stat(vim.fs.joinpath(mason_bin, name)) then
      errors[#errors + 1] = "Missing Mason tool: " .. name
    end
  end

  for _, name in ipairs(M.treesitter_parsers) do
    if #vim.api.nvim_get_runtime_file("parser/" .. name .. ".*", true) == 0 then
      errors[#errors + 1] = "Missing Tree-sitter parser: " .. name
    end
  end

  for _, command in ipairs({ "Mason", "ThemeHub", "TSUpdate" }) do
    if vim.fn.exists(":" .. command) ~= 2 then
      errors[#errors + 1] = "Missing Neovim command: " .. command
    end
  end
  return errors
end

function M.assert_ready()
  local errors = M.errors()
  assert(#errors == 0, table.concat(errors, "\n"))
end

return M
