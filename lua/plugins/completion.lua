return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = function()
      return {
        keymap = {
          preset = "none",
          ["<PageUp>"] = { "scroll_documentation_up", "fallback" },
          ["<PageDown>"] = { "scroll_documentation_down", "fallback" },
          ["<C-Space>"] = { "show" },
          ["<D-i>"] = { "show" },
          ["<Esc>"] = { "cancel", "fallback" },
          ["<CR>"] = { "select_and_accept", "fallback" },
          ["<Up>"] = { "select_prev", "fallback" },
          ["<Down>"] = { "select_next", "fallback" },
          ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
          ["<C-n>"] = { "select_next", "fallback_to_mappings" },
        },
        completion = {
          list = {
            selection = {
              preselect = false,
              auto_insert = false,
            },
          },
          menu = {
            border = "rounded",
            max_height = 12,
            draw = {
              columns = {
                { "kind_icon" },
                { "label", "label_description", gap = 1 },
                { "source_name" },
              },
            },
          },
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 300,
            window = {
              border = "rounded",
            },
          },
          ghost_text = {
            enabled = true,
          },
        },
        signature = {
          enabled = true,
          window = {
            border = "rounded",
          },
        },
        sources = {
          default = { "lsp", "snippets", "buffer", "path" },
        },
        cmdline = {
          keymap = { preset = "cmdline" },
          sources = function()
            if vim.fn.getcmdtype() == ":" then
              return { "cmdline", "path" }
            end
            return {}
          end,
          completion = {
            menu = {
              auto_show = function()
                return vim.fn.getcmdtype() == ":"
              end,
            },
          },
        },
        appearance = {
          nerd_font_variant = "mono",
        },
      }
    end,
    opts_extend = { "sources.default" },
  },
}
