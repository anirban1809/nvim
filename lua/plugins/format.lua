return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<S-M-f>",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "v" },
        desc = "Format Document",
      },
      {
        "<D-k><D-f>",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = "v",
        desc = "Format Selection",
      },
    },
    opts = {
      formatters_by_ft = {
        lua        = { "stylua" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        json       = { "prettierd", "prettier", stop_after_first = true },
        jsonc      = { "prettierd", "prettier", stop_after_first = true },
        yaml       = { "prettierd", "prettier", stop_after_first = true },
        markdown   = { "prettierd", "prettier", stop_after_first = true },
        html       = { "prettierd", "prettier", stop_after_first = true },
        css        = { "prettierd", "prettier", stop_after_first = true },
        go         = { "goimports", "golines" },
        c          = { "clang-format" },
        cpp        = { "clang-format" },
        rust       = { "rustfmt" },
      },
      formatters = {
        golines = {
          append_args = { "--max-len=100", "--tab-len=8", "--base-formatter=gofumpt" },
        },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,
    },
    init = function()
      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then vim.b.disable_autoformat = true else vim.g.disable_autoformat = true end
      end, { desc = "Disable autoformat-on-save", bang = true })
      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = "Re-enable autoformat-on-save" })
    end,
  },
}
