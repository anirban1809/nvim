-- This configuration is fully managed by lazy.nvim. Prevent old packer or
-- native packages under stdpath("data")/site/pack from loading first and
-- shadowing the pinned plugins.
local legacy_pack_root = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack")
vim.opt.packpath = { vim.fn.stdpath("config") }
vim.opt.runtimepath = vim.tbl_filter(function(path)
  return not vim.startswith(vim.fs.normalize(path), legacy_pack_root)
end, vim.opt.runtimepath:get())

if vim.fn.has("nvim-0.12") == 0 then
  error("This configuration requires Neovim 0.12 or newer")
end

-- Entry point. Order matters: options/keymaps before plugins.
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.buffers").setup()
require("config.lazy")
