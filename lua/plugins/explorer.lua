return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      require("nvim-tree").setup({
        sort = { sorter = "case_sensitive" },
        view = {
          width = 34,
          side = "left",
          signcolumn = "yes",
        },
        renderer = {
          group_empty = true,
          highlight_git = true,
          icons = {
            show = { file = true, folder = true, folder_arrow = true, git = true },
            glyphs = {
              git = {
                unstaged  = "M", staged    = "S", unmerged  = "U",
                renamed   = "R", untracked = "?", deleted   = "D",
                ignored   = "!",
              },
            },
          },
        },
        filters = { dotfiles = false, custom = { "^.git$" } },
        git = { enable = true, ignore = false },
        diagnostics = { enable = true, show_on_dirs = true },
        actions = { open_file = { quit_on_open = false, resize_window = true } },
      })
    end,
  },
}
