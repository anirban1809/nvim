return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require("tokyonight").setup({
        style = "storm",
        terminal_colors = true,
        styles = {
          comments = { italic = false },
          keywords = { italic = false },
          functions = { italic = false },
          variables = { italic = false },
        },
        on_colors = function(colors)
          local util = require("tokyonight.util")
          local neutral = colors.fg_dark
          local function mute(color, amount)
            return util.blend(color, amount or 0.78, neutral)
          end

          for _, name in ipairs({
            "blue", "blue0", "blue1", "blue2", "blue5", "blue6", "blue7",
            "cyan", "green", "green1", "green2", "magenta", "magenta2",
            "orange", "purple", "red", "red1", "teal", "yellow",
          }) do
            colors[name] = mute(colors[name])
          end

          colors.error = colors.red1
          colors.warning = colors.yellow
          colors.info = colors.blue2
          colors.hint = colors.teal
          colors.todo = colors.blue
          colors.border_highlight = colors.blue1

          for _, name in ipairs({ "add", "change", "delete" }) do
            colors.git[name] = mute(colors.git[name])
          end
          for _, name in ipairs({ "add", "change", "delete", "text" }) do
            colors.diff[name] = util.blend(colors.diff[name], 0.82, colors.bg)
          end
          for _, name in ipairs({
            "red", "red_bright", "green", "green_bright", "yellow",
            "yellow_bright", "blue", "blue_bright", "magenta",
            "magenta_bright", "cyan", "cyan_bright",
          }) do
            colors.terminal[name] = mute(colors.terminal[name])
          end

          colors.rainbow = {
            colors.blue,
            colors.yellow,
            colors.green,
            colors.teal,
            colors.magenta,
            colors.purple,
            colors.orange,
            colors.red,
          }
          colors.vscode_parameter = mute("#cfc9c2", 0.82)
          colors.vscode_tag_delimiter = mute("#ba3c97")
        end,
        on_highlights = function(highlights, colors)
          -- Match Enkia's official VS Code Tokyo Night Storm token palette.
          highlights.Normal = { bg = colors.bg, fg = colors.fg_dark }
          highlights.NormalNC = { bg = colors.bg, fg = colors.fg_dark }
          highlights.Comment = { fg = "#5f6996" }
          highlights.CursorLineNr = { fg = "#8089b3" }
          highlights.Visual = { bg = "#373d59" }
          highlights.Identifier = { fg = colors.fg }
          highlights.Type = { fg = colors.fg }
          highlights.Operator = { fg = colors.blue5 }

          highlights["@variable"] = { fg = colors.fg }
          highlights["@variable.builtin"] = { fg = colors.red }
          highlights["@variable.parameter"] = { fg = colors.vscode_parameter }
          highlights["@variable.member"] = { fg = colors.cyan }
          highlights["@property"] = { fg = colors.cyan }
          highlights["@type"] = { fg = colors.fg }
          highlights["@type.builtin"] = { fg = colors.blue1 }
          highlights["@module"] = { fg = colors.cyan }
          highlights["@keyword.import"] = { fg = colors.cyan }
          highlights["@operator"] = { fg = colors.blue5 }
          highlights["@punctuation.bracket"] = { fg = colors.blue5 }
          highlights["@punctuation.delimiter"] = { fg = colors.blue5 }
          highlights["@punctuation.special"] = { fg = colors.blue5 }
          highlights["@tag"] = { fg = colors.red }
          highlights["@tag.attribute"] = { fg = colors.magenta }
          highlights["@tag.delimiter"] = { fg = colors.vscode_tag_delimiter }
          highlights["@markup"] = { fg = colors.fg }

          highlights["@lsp.type.parameter"] = { fg = colors.vscode_parameter }
          highlights["@lsp.type.property"] = { fg = colors.cyan }
          highlights["@lsp.type.variable"] = { fg = colors.fg }
          highlights["@lsp.typemod.parameter.declaration"] = { fg = colors.yellow }
          highlights["@lsp.typemod.property.declaration"] = { fg = colors.green1 }
          highlights["@lsp.typemod.variable.declaration"] = { fg = colors.magenta }
          highlights["@lsp.typemod.variable.defaultLibrary"] = { fg = colors.blue1 }
          highlights["@lsp.typemod.property.defaultLibrary"] = { fg = colors.blue1 }

          highlights.Search = {
            bg = colors.bg_visual,
            fg = colors.fg,
          }
          highlights.CurSearch = {
            bg = colors.blue0,
            fg = colors.fg,
            bold = true,
            underline = true,
            sp = colors.yellow,
          }
          highlights.IncSearch = highlights.CurSearch
        end,
      })
      vim.cmd.colorscheme("tokyonight-storm")
    end,
  },

  -- Backup themes (lazy-loaded; switch via :colorscheme)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = {
      flavour = "mocha",
      background = { light = "latte", dark = "mocha" },
      transparent_background = false,
      term_colors = true,
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        telescope = { enabled = true },
        mason = true,
        which_key = true,
        dap = true,
        dap_ui = true,
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
        indent_blankline = { enabled = true },
      },
    },
  },
  { "rebelot/kanagawa.nvim", lazy = true },
}
