return {
  -- Mason: tool installer
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed   = "✓",
          package_pending     = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- Bridge mason <-> lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "saghen/blink.cmp",
      { "j-hui/fidget.nvim", opts = {} },
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Diagnostics UI
      vim.diagnostic.config({
        virtual_text     = false,
        virtual_lines    = false,
        signs            = true,
        underline        = true,
        update_in_insert = false,
        severity_sort    = true,
        float = {
          border = "rounded",
          source = true,
          header = "",
          prefix = "",
        },
      })

      -- Show diagnostic text only when the cursor rests on the diagnostic.
      vim.api.nvim_create_autocmd("CursorHold", {
        group = vim.api.nvim_create_augroup("user_diagnostic_float", { clear = true }),
        callback = function(event)
          if vim.bo[event.buf].buftype ~= "" then
            return
          end

          vim.diagnostic.open_float(event.buf, {
            scope = "cursor",
            focus = false,
            border = "rounded",
            source = true,
            header = "",
            prefix = "",
          })
        end,
      })

      -- Pretty signs
      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      -- Hover/signature borders (nvim 0.11+ uses options on the call site)
      local orig_hover = vim.lsp.buf.hover
      vim.lsp.buf.hover = function(opts)
        return orig_hover(vim.tbl_deep_extend("force", { border = "rounded" }, opts or {}))
      end
      local orig_sig = vim.lsp.buf.signature_help
      vim.lsp.buf.signature_help = function(opts)
        return orig_sig(vim.tbl_deep_extend("force", { border = "rounded" }, opts or {}))
      end

      local hover_timer = vim.uv.new_timer()
      local function stop_hover_timer()
        if hover_timer then
          hover_timer:stop()
        end
      end

      local function diagnostic_at_cursor(bufnr, row, col)
        for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = row })) do
          local end_col = diagnostic.end_col or diagnostic.col
          if diagnostic.col <= col and col <= end_col then
            return true
          end
        end
        return false
      end

      local function schedule_type_hover()
        stop_hover_timer()

        if vim.fn.mode() ~= "n" or vim.bo.buftype ~= "" then
          return
        end

        local win = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_get_current_buf()
        local cursor = vim.api.nvim_win_get_cursor(win)

        hover_timer:start(1000, 0, vim.schedule_wrap(function()
          if not vim.api.nvim_win_is_valid(win)
            or not vim.api.nvim_buf_is_valid(bufnr)
            or vim.api.nvim_get_current_win() ~= win
            or vim.api.nvim_get_current_buf() ~= bufnr
            or vim.fn.mode() ~= "n"
            or not vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor) then
            return
          end

          local row, col = cursor[1] - 1, cursor[2]
          local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
          local char = vim.fn.matchstr(line:sub(col + 1), "^.")
          if char == "" or vim.fn.match(char, [[\k]]) ~= 0 then
            return
          end

          if diagnostic_at_cursor(bufnr, row, col) then
            return
          end

          for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
            if client:supports_method("textDocument/hover") then
              vim.lsp.buf.hover()
              return
            end
          end
        end))
      end

      vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "WinEnter", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("user_lsp_type_hover", { clear = true }),
        callback = schedule_type_hover,
      })
      vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave" }, {
        group = "user_lsp_type_hover",
        callback = stop_hover_timer,
      })

      -- Per-buffer LSP keymaps
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
        callback = function(event)
          local bufnr = event.buf
          local map = function(mode, lhs, rhs, desc, opts)
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", {
              buffer = bufnr,
              desc = "LSP: " .. desc,
            }, opts or {}))
          end

          local function go_to_definition()
            stop_hover_timer()
            vim.lsp.buf.definition()
          end

          map("n", "g", go_to_definition, "Go to Definition", { nowait = true })
          map("n", "<F12>", vim.lsp.buf.definition, "Go to Definition")
          map("n", "<D-F12>", vim.lsp.buf.implementation, "Go to Implementation")
          map("n", "<S-F12>", require("config.lsp_references").open, "Go to References")
          map("n", "r", require("config.lsp_references").open, "Go to References")
          map("n", "<F2>", vim.lsp.buf.rename, "Rename Symbol")
          map({ "n", "v" }, "<D-.>", vim.lsp.buf.code_action, "Quick Fix")
          map({ "n", "v" }, "<C-S-r>", vim.lsp.buf.code_action, "Refactor")
          map("n", "<D-k><D-i>", vim.lsp.buf.hover, "Show Hover")
          map({ "n", "i" }, "<D-S-Space>", vim.lsp.buf.signature_help, "Trigger Parameter Hints")
          map("n", "<F8>", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, "Next Problem")
          map("n", "<S-F8>", function()
            vim.diagnostic.jump({ count = -1, float = true })
          end, "Previous Problem")
          map("n", "<M-F8>", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, "Next Problem in File")

          vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
        end,
      })

      -- Server-specific settings
      local servers = {
        -- TypeScript / JavaScript
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "literal",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
            javascript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
                includeInlayEnumMemberValueHints = true,
              },
            },
          },
        },

        -- Go
        gopls = {
          settings = {
            gopls = {
              gofumpt = true,
              completeUnimported = true,
              usePlaceholders = true,
              analyses = {
                unusedparams = true,
                shadow = true,
                nilness = true,
                unusedwrite = true,
                useany = true,
              },
              staticcheck = true,
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                compositeLiteralTypes = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        },

        -- C / C++
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
        },

        -- Rust (basic; rustaceanvim covers richer use)
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true, loadOutDirsFromCheck = true, runBuildScripts = true },
              checkOnSave = { allFeatures = true, command = "clippy", extraArgs = { "--no-deps" } },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"]   = { "async_trait" },
                  ["napi-derive"]   = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "never" },
                lifetimeElisionHints = { enable = "never", useParameterNames = false },
                maxLength = 25,
                parameterHints = { enable = true },
                reborrowHints = { enable = "never" },
                renderColons = true,
                typeHints = { enable = true, hideClosureInitialization = false, hideNamedConstructor = false },
              },
            },
          },
        },

        -- Lua (for editing this very config)
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
              diagnostics = { globals = { "vim" } },
              completion = { callSnippet = "Replace" },
              hint = { enable = true },
            },
          },
        },
      }

      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_installation = true,
        automatic_enable = false,
      })

      -- rustaceanvim owns rust_analyzer; don't double-setup via lspconfig.
      for name, opts in pairs(servers) do
        if name ~= "rust_analyzer" then
          opts.capabilities = vim.tbl_deep_extend("force", capabilities, opts.capabilities or {})
          vim.lsp.config(name, opts)
          vim.lsp.enable(name)
        end
      end

      -- Auxiliary tools (formatters, debug adapters)
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- LSP servers are listed here as well as in mason-lspconfig so the
          -- portable bootstrap can install them synchronously.
          "clangd",
          "gopls",
          "lua-language-server",
          "rust-analyzer",
          "typescript-language-server",
          -- Formatters
          "prettierd", "prettier",
          "stylua",
          "gofumpt", "goimports",
          "clang-format",
          -- Linters
          "eslint_d",
          -- DAP adapters (also installed via mason-nvim-dap, redundant but safe)
          "codelldb",
          "delve",
          "js-debug-adapter",
        },
        auto_update = false,
        run_on_start = true,
      })
    end,
  },

  -- Richer Rust experience (rust-analyzer, runnables, etc.)
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    init = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              checkOnSave = { command = "clippy" },
            },
          },
        },
      }
    end,
  },
}
