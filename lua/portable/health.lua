local M = {}

local function executable(name)
  return vim.fn.executable(name) == 1
end

local function check_executables(names, required)
  for _, name in ipairs(names) do
    if executable(name) then
      vim.health.ok(("%s: %s"):format(name, vim.fn.exepath(name)))
    elseif required then
      vim.health.error(("%s is missing"):format(name))
    else
      vim.health.warn(("%s is missing; related language features will be unavailable"):format(name))
    end
  end
end

function M.check()
  vim.health.start("Portable macOS configuration")

  if vim.fn.has("mac") == 1 then
    vim.health.ok("Running on macOS")
  else
    vim.health.error("This installation profile targets macOS")
  end

  if vim.fn.has("nvim-0.11") == 1 then
    local version = vim.version()
    vim.health.ok(("Neovim %d.%d.%d"):format(version.major, version.minor, version.patch))
  else
    vim.health.error("Neovim 0.11 or newer is required")
  end

  vim.health.start("Host dependencies")
  check_executables({ "git", "make", "cc", "rg", "fd" }, true)

  vim.health.start("Language runtimes")
  check_executables({ "go", "node", "npm", "rustup", "cargo", "rustc" }, false)

  vim.health.start("Mason tools")
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin")
  for _, name in ipairs({
    "clang-format",
    "clangd",
    "codelldb",
    "dlv",
    "eslint_d",
    "gofumpt",
    "goimports",
    "gopls",
    "js-debug-adapter",
    "lua-language-server",
    "prettier",
    "prettierd",
    "rust-analyzer",
    "stylua",
    "typescript-language-server",
  }) do
    local path = vim.fs.joinpath(mason_bin, name)
    if vim.uv.fs_stat(path) then
      vim.health.ok(name)
    else
      vim.health.warn(("%s is not installed; rerun scripts/bootstrap-macos.sh"):format(name))
    end
  end

  vim.health.start("Machine-local state")
  vim.health.info("Open buffers and DAP breakpoints stay local because they contain absolute project paths")
  vim.health.info("ThemeHub stores installed themes and the selected theme under stdpath('data')")
end

return M
