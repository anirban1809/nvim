return {
  {
    "mfussenegger/nvim-dap",
    ft = { "go" },
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "jay-babu/mason-nvim-dap.nvim",
      "leoluz/nvim-dap-go",
      -- TS/JS adapter helper
      {
        "mxsdev/nvim-dap-vscode-js",
        dependencies = { "mfussenegger/nvim-dap" },
      },
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Start/Continue" },
      { "<C-F5>", function() require("dap").continue() end, desc = "Run Without Debugging" },
      { "<S-F5>", function() require("dap").terminate() end, desc = "Debug: Stop" },
      { "<D-S-F5>", function() require("dap").restart() end, desc = "Debug: Restart" },
      { "<F6>", function() require("dap").pause() end, desc = "Debug: Pause" },
      { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
      { "<D-S-d>", function() require("dapui").toggle() end, desc = "View: Run and Debug" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      local vscode = require("dap.ext.vscode")

      local function find_launch_json(bufnr)
        local buffer_path = vim.api.nvim_buf_get_name(bufnr)
        local directory = buffer_path ~= "" and vim.fs.dirname(buffer_path) or vim.fn.getcwd()

        while directory and directory ~= "" do
          local launch_path = vim.fs.joinpath(directory, ".vscode", "launch.json")
          if vim.uv.fs_stat(launch_path) then
            return launch_path
          end

          local parent = vim.fs.dirname(directory)
          if parent == directory then
            break
          end
          directory = parent
        end
      end

      local function resolve_workspace_variables(value, workspace, seen)
        if type(value) == "string" then
          value = value:gsub("%${workspaceFolderBasename}", function()
            return vim.fs.basename(workspace)
          end)
          return value:gsub("%${workspaceFolder}", function()
            return workspace
          end)
        end
        if type(value) ~= "table" then
          return value
        end

        seen = seen or {}
        if seen[value] then
          return value
        end
        seen[value] = true
        for key, item in pairs(value) do
          value[key] = resolve_workspace_variables(item, workspace, seen)
        end
        return value
      end

      -- nvim-dap normally checks only {cwd}/.vscode/launch.json. Resolve it
      -- from the current buffer so launching Neovim outside the project still
      -- applies VS Code settings such as args, cwd, and env.
      dap.providers.configs["dap.launch.json"] = function(bufnr)
        local launch_path = find_launch_json(bufnr)
        if not launch_path then
          return {}
        end

        local ok, configs = pcall(vscode.getconfigs, launch_path)
        if not ok then
          vim.notify(
            ("Can't load DAP configurations from %s:\n%s"):format(launch_path, configs),
            vim.log.levels.ERROR,
            { title = "DAP" }
          )
          return {}
        end
        local workspace = vim.fs.dirname(vim.fs.dirname(launch_path))
        for _, config in ipairs(configs) do
          resolve_workspace_variables(config, workspace)
        end
        return configs
      end

      require("mason-nvim-dap").setup({
        ensure_installed = { "codelldb", "delve", "js-debug-adapter" },
        automatic_installation = true,
        handlers = {
          -- nvim-dap-go configures Delve below. Avoid duplicate "delve"
          -- configurations whose ${workspaceFolder} launch often targets a
          -- module root that is not a runnable main package.
          delve = function() end,
        },
      })

      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.35 },
              { id = "breakpoints", size = 0.20 },
              { id = "stacks",      size = 0.25 },
              { id = "watches",     size = 0.20 },
            },
            position = "left",
            size = 50,
          },
          {
            elements = {
              { id = "repl",    size = 0.5 },
              { id = "console", size = 0.5 },
            },
            position = "bottom",
            size = 12,
          },
        },
        floating = { border = "rounded" },
      })

      require("nvim-dap-virtual-text").setup({
        commented = true,
        virt_text_pos = "eol",
      })

      -- Auto open/close DAP UI
      dap.listeners.before.attach.dapui_config            = function() dapui.open() end
      dap.listeners.before.launch.dapui_config            = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config  = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config      = function() dapui.close() end

      -- Pretty signs
      vim.fn.sign_define("DapBreakpoint",          { text = "●",  texthl = "DiagnosticSignError", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆",  texthl = "DiagnosticSignWarn",  linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint",            { text = "◆",  texthl = "DiagnosticSignInfo",  linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped",             { text = "▶",  texthl = "DiagnosticSignWarn",  linehl = "Visual", numhl = "DiagnosticSignWarn" })
      vim.fn.sign_define("DapBreakpointRejected",  { text = "✗",  texthl = "DiagnosticSignHint",  linehl = "", numhl = "" })

      -- ===== Adapters =====
      local mason_path = vim.fn.stdpath("data") .. "/mason"

      -- C / C++ / Rust via codelldb
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = mason_path .. "/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      local function pick_executable()
        return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
      end

      for _, lang in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[lang] = {
          {
            name = "Launch (codelldb)",
            type = "codelldb",
            request = "launch",
            program = pick_executable,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
            args = function()
              local raw = vim.fn.input("Args (space-separated): ")
              return vim.split(raw, " ", { trimempty = true })
            end,
          },
          {
            name = "Attach to process (codelldb)",
            type = "codelldb",
            request = "attach",
            pid = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end

      -- Read the CLI args for a Go "launch" config from the workspace
      -- root's .vscode/launch.json, resolving ${workspaceFolder} etc. so
      -- `dlv` is invoked with the same arguments VS Code would use.
      local function go_launch_json_args()
        local launch_path = find_launch_json(0)
        if not launch_path then
          return {}
        end

        local ok, configs = pcall(vscode.getconfigs, launch_path)
        if not ok then
          vim.notify(
            ("Can't load Go debug args from %s:\n%s"):format(launch_path, configs),
            vim.log.levels.ERROR,
            { title = "DAP" }
          )
          return {}
        end

        local workspace = vim.fs.dirname(vim.fs.dirname(launch_path))
        for _, config in ipairs(configs) do
          if config.type == "go" and config.request == "launch" and config.args ~= nil then
            return resolve_workspace_variables(config.args, workspace)
          end
        end
        return {}
      end

      -- Go via delve (managed by nvim-dap-go)
      require("dap-go").setup({
        delve = {
          path = mason_path .. "/bin/dlv",
        },
      })

      -- nvim-dap-go's default "launch" configurations ship without args.
      -- Pull them from the workspace .vscode/launch.json at debug time,
      -- leaving configs that already define args (e.g. the prompt-based
      -- "Debug (Arguments)") untouched.
      for _, config in ipairs(dap.configurations.go or {}) do
        if config.request == "launch" and config.args == nil then
          config.args = go_launch_json_args
        end
      end

      local function set_go_debug_keymaps(bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set("n", "0", dap.terminate, vim.tbl_extend("force", opts, { desc = "Debug: Stop" }))
        vim.keymap.set("n", "1", dap.step_over, vim.tbl_extend("force", opts, { desc = "Debug: Step Over" }))
        vim.keymap.set("n", "2", dap.step_into, vim.tbl_extend("force", opts, { desc = "Debug: Step Into" }))
        vim.keymap.set("n", "3", dap.step_out, vim.tbl_extend("force", opts, { desc = "Debug: Step Out" }))
        vim.keymap.set("n", "4", dap.run_to_cursor, vim.tbl_extend("force", opts, { desc = "Debug: Run to Cursor" }))
        vim.keymap.set("n", "5", dap.continue, vim.tbl_extend("force", opts, { desc = "Debug: Run to Next Breakpoint" }))
        vim.keymap.set("n", "b", dap.toggle_breakpoint, vim.tbl_extend("force", opts, { desc = "Debug: Toggle Breakpoint" }))
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("go_debug_keymaps", { clear = true }),
        pattern = "go",
        callback = function(event)
          set_go_debug_keymaps(event.buf)
        end,
      })

      if vim.bo.filetype == "go" then
        set_go_debug_keymaps(0)
      end

      -- TypeScript / JavaScript via vscode-js-debug
      require("dap-vscode-js").setup({
        debugger_path = mason_path .. "/packages/js-debug-adapter",
        debugger_cmd = { mason_path .. "/bin/js-debug-adapter" },
        adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
      })

      for _, ft in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[ft] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            runtimeExecutable = "node",
          },
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch via ts-node",
            runtimeExecutable = "node",
            runtimeArgs = { "--loader", "ts-node/esm" },
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            protocol = "inspector",
            skipFiles = { "<node_internals>/**", "node_modules/**" },
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach to process",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            sourceMaps = true,
          },
          {
            type = "pwa-chrome",
            request = "launch",
            name = "Launch Chrome (localhost:3000)",
            url = "http://localhost:3000",
            webRoot = "${workspaceFolder}",
            sourceMaps = true,
          },
        }
      end
    end,
  },
}
