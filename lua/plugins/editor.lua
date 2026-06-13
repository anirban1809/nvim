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
    opts = { check_ts = true },
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
    event = "VeryLazy",
    opts = {
      open_no_results = true,
      warn_no_results = false,
      keys = {
        q = function()
          require("config.trouble").toggle()
        end,
        o = "jump",
      },
    },
    config = function(_, opts)
      require("trouble").setup(opts)
      require("config.trouble").setup()
    end,
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
