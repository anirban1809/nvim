return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      local ok, error_message = pcall(function()
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
          local neutral = colors.fg_dark or colors.fg or "#a9b1d6"
          local function rgb(color)
            if type(color) ~= "string" or not color:match("^#%x%x%x%x%x%x$") then
              return nil
            end
            return {
              tonumber(color:sub(2, 3), 16),
              tonumber(color:sub(4, 5), 16),
              tonumber(color:sub(6, 7), 16),
            }
          end
          local function mute(color, amount)
            local foreground = rgb(color)
            local background = rgb(neutral)
            if not foreground or not background then
              return color
            end

            local alpha = amount or 0.78
            local channels = {}
            for index = 1, 3 do
              channels[index] = math.floor(
                alpha * foreground[index] + (1 - alpha) * background[index] + 0.5
              )
            end
            return string.format("#%02x%02x%02x", unpack(channels))
          end

          for _, name in ipairs({
            "blue", "blue0", "blue1", "blue2", "blue5", "blue6", "blue7",
            "cyan", "green", "green1", "green2", "magenta", "magenta2",
            "orange", "purple", "red", "red1", "teal", "yellow",
          }) do
            if colors[name] then
              colors[name] = mute(colors[name])
            end
          end

          colors.error = colors.red1 or colors.red
          colors.warning = colors.yellow
          colors.info = colors.blue2 or colors.blue
          colors.hint = colors.teal or colors.cyan
          colors.todo = colors.blue
          colors.border_highlight = colors.blue1 or colors.blue

          for _, name in ipairs({ "add", "change", "delete" }) do
            if colors.git and colors.git[name] then
              colors.git[name] = mute(colors.git[name])
            end
          end
          for _, name in ipairs({ "add", "change", "delete", "text" }) do
            if colors.diff and colors.diff[name] then
              colors.diff[name] = mute(colors.diff[name], 0.82)
            end
          end
          for _, name in ipairs({
            "red", "red_bright", "green", "green_bright", "yellow",
            "yellow_bright", "blue", "blue_bright", "magenta",
            "magenta_bright", "cyan", "cyan_bright",
          }) do
            if colors.terminal and colors.terminal[name] then
              colors.terminal[name] = mute(colors.terminal[name])
            end
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
      end)
      if not ok then
        vim.cmd.colorscheme("habamax")
        vim.schedule(function()
          vim.notify(
            "TokyoNight failed to load; using habamax so ThemeHub remains available:\n" .. error_message,
            vim.log.levels.ERROR,
            { title = "Colorscheme" }
          )
        end)
      end
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
        blink_cmp = { enabled = true, style = "bordered" },
        gitsigns = true,
        treesitter = true,
        telescope = { enabled = true },
        mason = true,
        which_key = true,
        dap = true,
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
  {
    "Erl-koenig/theme-hub.nvim",
    lazy = false,
    priority = 900,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "rktjmp/lush.nvim",
    },
    keys = {
      {
        "<D-k><D-i>",
        "<cmd>ThemeHub<CR>",
        desc = "Preferences: Install Color Theme",
      },
    },
    opts = {
      install_dir = vim.fn.stdpath("data") .. "/theme-hub",
      auto_install_on_select = true,
      apply_after_install = true,
      persistent = true,
    },
  },
}
