return {
  -- Comments (gcc / gc)
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      {
        "<D-/>",
        function() require("Comment.api").toggle.linewise.current() end,
        mode = "n",
        desc = "Editor: Toggle Line Comment",
      },
      {
        "<D-/>",
        '<Esc><cmd>lua require("Comment.api").locked("toggle.linewise")(vim.fn.visualmode())<CR>',
        mode = "x",
        desc = "Editor: Toggle Line Comment",
      },
      {
        "<D-/>",
        '<Esc><cmd>lua require("Comment.api").toggle.linewise.current()<CR>gi',
        mode = "i",
        desc = "Editor: Toggle Line Comment",
      },
      {
        "<S-M-a>",
        function() require("Comment.api").toggle.blockwise.current() end,
        mode = "n",
        desc = "Editor: Toggle Block Comment",
      },
      {
        "<S-M-a>",
        '<Esc><cmd>lua require("Comment.api").locked("toggle.blockwise")(vim.fn.visualmode())<CR>',
        mode = "x",
        desc = "Editor: Toggle Block Comment",
      },
      {
        "<D-k><D-c>",
        function() require("Comment.api").comment.linewise.current() end,
        mode = "n",
        desc = "Editor: Add Line Comment",
      },
      {
        "<D-k><D-c>",
        '<Esc><cmd>lua require("Comment.api").locked("comment.linewise")(vim.fn.visualmode())<CR>',
        mode = "x",
        desc = "Editor: Add Line Comment",
      },
      {
        "<D-k><D-u>",
        function() require("Comment.api").uncomment.linewise.current() end,
        mode = "n",
        desc = "Editor: Remove Line Comment",
      },
      {
        "<D-k><D-u>",
        '<Esc><cmd>lua require("Comment.api").locked("uncomment.linewise")(vim.fn.visualmode())<CR>',
        mode = "x",
        desc = "Editor: Remove Line Comment",
      },
    },
    opts = {
      mappings = {
        basic = false,
        extra = false,
      },
    },
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local autopairs = require("nvim-autopairs")
      autopairs.setup({ check_ts = true })
      local cmp_status, cmp = pcall(require, "cmp")
      if cmp_status then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },

  -- Surround (cs"' etc.)
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },

  -- Better diagnostics list
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {},
  },

  -- TODO / FIXME comments highlighting
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- VS Code-style multiple cursors.
  {
    "mg979/vim-visual-multi",
    branch = "master",
    init = function()
      vim.g.VM_maps = {
        ["Find Under"] = "<D-d>",
        ["Find Subword Under"] = "<D-d>",
        ["Select All"] = "<D-S-l>",
        ["Add Cursor Down"] = "<M-D-Down>",
        ["Add Cursor Up"] = "<M-D-Up>",
        ["Select h"] = "",
        ["Select l"] = "",
      }
    end,
  },

  -- Project-wide search and replace.
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = {},
  },

  -- Smooth scrolling / nicer UI
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Terminal
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = { "ToggleTerm", "TermExec" },
    opts = {
      shade_terminals = true,
      float_opts = { border = "curved" },
      open_mapping = nil,
    },
  },
}
