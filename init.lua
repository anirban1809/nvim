if vim.fn.has("nvim-0.11") == 0 then
  error("This configuration requires Neovim 0.11 or newer")
end

-- Entry point. Order matters: options/keymaps before plugins.
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.buffers").setup()
require("config.lazy")
