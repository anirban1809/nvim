return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "bash", "c", "cpp", "cmake", "css", "diff", "dockerfile",
          "go", "gomod", "gosum", "gowork",
          "html", "javascript", "json", "jsonc", "lua", "luadoc",
          "make", "markdown", "markdown_inline", "python",
          "regex", "rust", "toml", "tsx", "typescript",
          "vim", "vimdoc", "yaml",
        },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true, disable = { "python" } },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-S-Right>",
            node_incremental = "<C-S-Right>",
            scope_incremental = false,
            node_decremental = "<C-S-Left>",
          },
        },
      })
    end,
  },
}
