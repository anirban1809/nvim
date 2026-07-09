return {
  {
    "mfussenegger/nvim-dap",
    ft = { "go", "c", "cpp", "rust", "zig", "typescript", "javascript", "typescriptreact", "javascriptreact" },
    dependencies = {
      {
        "igorlfs/nvim-dap-view",
        version = "1.*",
        opts = {
          auto_toggle = true,
          windows = {
            position = "below",
            size = 0.3,
            terminal = {
              position = "left",
              size = 0.4,
            },
          },
          winbar = {
            default_section = "scopes",
          },
          hover = {
            border = "rounded",
          },
          keymaps = {
            breakpoints = {
              delete_breakpoint = "x",
            },
            watches = {
              delete_expression = "x",
            },
          },
          virtual_text = {
            enabled = false,
          },
        },
      },
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
      { "<D-S-d>", function() require("dap-view").toggle() end, desc = "View: Run and Debug" },
      { "K", function() require("dap-view").hover(nil, true) end, mode = { "n", "x" }, desc = "Debug: Inspect Value" },
    },
    config = function()
      local dap = require("dap")
      local dap_view = require("dap-view")
      local dap_view_state = require("dap-view.state")
      local vscode = require("dap.ext.vscode")
      local debug_focus_buffers = {}
      local last_editor_win
      local go_module_directory
      local go_main_directory
      local zig_project_directory

      local function is_debug_window(win)
        if not win or not vim.api.nvim_win_is_valid(win) then
          return false
        end
        if vim.w[win].dapview_win or vim.w[win].dapview_win_term then
          return true
        end
        local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        return filetype == "dap-view"
          or filetype == "dap-view-hover"
          or filetype == "dap-value-hover"
          or filetype == "dap-repl"
      end

      local function focus_debugger()
        local current_win = vim.api.nvim_get_current_win()
        if not is_debug_window(current_win) then
          last_editor_win = current_win
        end

        if not dap_view_state.winnr or not vim.api.nvim_win_is_valid(dap_view_state.winnr) then
          dap_view.open()
        end
        if dap_view_state.winnr and vim.api.nvim_win_is_valid(dap_view_state.winnr) then
          vim.api.nvim_set_current_win(dap_view_state.winnr)
        end
      end

      local function focus_editor()
        if last_editor_win and vim.api.nvim_win_is_valid(last_editor_win) then
          vim.api.nvim_set_current_win(last_editor_win)
          return
        end
        vim.cmd.wincmd("p")
      end

      local function map_debug_focus(bufnr)
        if vim.bo[bufnr].buftype ~= "" or debug_focus_buffers[bufnr] then
          return
        end
        vim.keymap.set("n", "d", focus_debugger, {
          buffer = bufnr,
          silent = true,
          nowait = true,
          desc = "Debug: Focus Debugger",
        })
        debug_focus_buffers[bufnr] = true
      end

      local function clear_debug_focus()
        for bufnr in pairs(debug_focus_buffers) do
          if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(vim.keymap.del, "n", "d", { buffer = bufnr })
          end
        end
        debug_focus_buffers = {}
      end

      local focus_group = vim.api.nvim_create_augroup("dap_view_focus", { clear = true })
      vim.api.nvim_create_autocmd("WinEnter", {
        group = focus_group,
        callback = function()
          local win = vim.api.nvim_get_current_win()
          if not is_debug_window(win) then
            last_editor_win = win
          end
        end,
      })
      vim.api.nvim_create_autocmd("BufEnter", {
        group = focus_group,
        callback = function(event)
          if dap.session() then
            map_debug_focus(event.buf)
          end
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = focus_group,
        pattern = { "dap-view", "dap-view-hover", "dap-repl" },
        callback = function(event)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(event.buf) then
              vim.keymap.set("n", "d", focus_editor, {
                buffer = event.buf,
                silent = true,
                nowait = true,
                desc = "Debug: Focus Editor",
              })
            end
          end)
        end,
      })

      local function debug_started()
        require("config.trouble").debug_started()
      end
      dap.listeners.before.attach.trouble = debug_started
      dap.listeners.before.launch.trouble = debug_started
      dap.listeners.after.event_initialized.dap_view_focus = function()
        map_debug_focus(vim.api.nvim_get_current_buf())
        debug_started()
      end
      local function debug_stopped()
        clear_debug_focus()
        require("config.debug_hover").close()
        require("config.trouble").debug_stopped()
      end
      dap.listeners.before.event_terminated.dap_view_focus = debug_stopped
      dap.listeners.before.event_exited.dap_view_focus = debug_stopped
      dap.listeners.before.disconnect.dap_view_focus = debug_stopped
      dap.listeners.after.event_stopped.node_inspect_break = function(session, body)
        if not session
          or not session.config
          or session.config.type ~= "pwa-node"
          or type(session.config.name) ~= "string"
          or not session.config.name:match("^Remote Process")
          or session.__auto_continued_inspect_break
          or not body
          or body.reason ~= "pause"
          or body.description ~= "Paused on debugger statement"
          or not body.threadId then
          return
        end

        session.__auto_continued_inspect_break = true
        session:request("continue", { threadId = body.threadId }, function() end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("dap_view_hover_wrap", { clear = true }),
        pattern = "dap-view-hover",
        callback = function()
          vim.wo.wrap = true
          vim.wo.linebreak = true
          vim.wo.breakindent = true
        end,
      })

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

      local function append_unique(list, item)
        list = list or {}
        if not vim.tbl_contains(list, item) then
          table.insert(list, item)
        end
        return list
      end

      local function get_free_port()
        local server = assert(vim.uv.new_tcp())
        assert(server:bind("127.0.0.1", 0))
        local port = assert(server:getsockname()).port
        server:close()
        return port
      end

      local function force_inspect_break(config)
        local port = get_free_port()
        local runtime_args = vim.tbl_filter(function(arg)
          return type(arg) ~= "string" or not arg:match("^%-%-inspect%-brk")
        end, config.runtimeArgs or {})

        table.insert(runtime_args, 1, ("--inspect-brk=127.0.0.1:%d"):format(port))
        config.runtimeArgs = runtime_args
        config.attachSimplePort = port
      end

      local function add_typescript_loader(config)
        if type(config.program) ~= "string" or not config.program:match("%.tsx?$") then
          return
        end

        local loader = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "node-ts-esm-loader.mjs")
        local register_loader = ('data:text/javascript,import { register } from "node:module"; import { pathToFileURL } from "node:url"; register(%q, pathToFileURL("./"));'):format(loader)
        config.runtimeArgs = append_unique(config.runtimeArgs, "--import")
        config.runtimeArgs = append_unique(config.runtimeArgs, register_loader)
      end

      local function normalize_node_debug_config(config)
        if config.type == "node" then
          config.type = "pwa-node"
        elseif config.type == "chrome" then
          config.type = "pwa-chrome"
        elseif config.type == "msedge" then
          config.type = "pwa-msedge"
        end

        if not vim.tbl_contains({ "pwa-node", "node-terminal" }, config.type) then
          return
        end

        config.sourceMaps = config.sourceMaps ~= false
        config.skipFiles = append_unique(config.skipFiles, "<node_internals>/**")
        config.skipFiles = append_unique(config.skipFiles, "node_modules/**")

        if config.request == "launch" then
          config.runtimeExecutable = config.runtimeExecutable or "node"
          config.runtimeArgs = append_unique(config.runtimeArgs, "--enable-source-maps")
          add_typescript_loader(config)
          if config.stopOnEntry == nil then
            config.stopOnEntry = true
          end
          if config.type == "pwa-node" then
            force_inspect_break(config)
          end
        end
      end

      local function normalize_codelldb_config(config)
        if config.type == "lldb" then
          config.type = "codelldb"
        end
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
          normalize_node_debug_config(config)
          normalize_codelldb_config(config)
          if config.type == "go"
            and config.request == "launch"
            and (config.program == "${file}" or config.program == "${fileDirname}") then
            config.program = go_main_directory
            config.cwd = go_module_directory
          end
          if config.type == "go" and config.mode == "auto" then
            -- vscode-go resolves "auto" before invoking Delve. nvim-dap talks
            -- to Delve directly, where "auto" is not a supported mode.
            config.mode = nil
          end
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

      -- Pretty signs
      vim.fn.sign_define("DapBreakpoint",          { text = "●",  texthl = "DiagnosticSignError", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆",  texthl = "DiagnosticSignWarn",  linehl = "", numhl = "" })
      vim.fn.sign_define("DapLogPoint",            { text = "◆",  texthl = "DiagnosticSignInfo",  linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped",             { text = "▶",  texthl = "DiagnosticSignWarn",  linehl = "Visual", numhl = "DiagnosticSignWarn" })
      vim.fn.sign_define("DapBreakpointRejected",  { text = "✗",  texthl = "DiagnosticSignHint",  linehl = "", numhl = "" })

      require("config.dap_breakpoints").setup()

      -- ===== Adapters =====
      local mason_path = vim.fn.stdpath("data") .. "/mason"

      -- C / C++ / Rust / Zig via codelldb
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

      local function current_file_directory()
        local file = vim.api.nvim_buf_get_name(0)
        return file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
      end

      zig_project_directory = function()
        local directory = current_file_directory()
        local build_zig = vim.fs.find("build.zig", { path = directory, upward = true })[1]
        return build_zig and vim.fs.dirname(build_zig) or directory
      end

      local function executable_files(directory)
        local files = {}
        local scan = vim.uv.fs_scandir(directory)
        if not scan then
          return files
        end

        while true do
          local name, kind = vim.uv.fs_scandir_next(scan)
          if not name then
            break
          end
          local path = vim.fs.joinpath(directory, name)
          if kind == "file" and vim.fn.executable(path) == 1 then
            files[#files + 1] = path
          end
        end
        table.sort(files)
        return files
      end

      local function run_zig_build(args, cwd)
        local result = vim.system(args, { cwd = cwd, text = true }):wait()
        if result.code == 0 then
          return true
        end

        local output = vim.trim(table.concat({ result.stderr or "", result.stdout or "" }, "\n"))
        vim.notify(output ~= "" and output or "zig build failed", vim.log.levels.ERROR, {
          title = "DAP",
        })
        return false
      end

      local function zig_project_executable()
        local root = zig_project_directory()
        if vim.uv.fs_stat(vim.fs.joinpath(root, "build.zig")) then
          if not run_zig_build({ "zig", "build", "-Doptimize=Debug" }, root) then
            return nil
          end
        end

        local bin_directory = vim.fs.joinpath(root, "zig-out", "bin")
        local executables = executable_files(bin_directory)
        if #executables == 1 then
          return executables[1]
        end

        return vim.fn.input("Executable: ", bin_directory .. "/", "file")
      end

      local function zig_file_executable()
        local file = vim.api.nvim_buf_get_name(0)
        if file == "" then
          vim.notify("Save the Zig file before debugging", vim.log.levels.ERROR, { title = "DAP" })
          return nil
        end

        local output_directory = vim.fs.joinpath(vim.fn.stdpath("state"), "zig-debug", vim.fn.sha256(file))
        vim.fn.mkdir(output_directory, "p")
        local output = vim.fs.joinpath(output_directory, vim.fn.fnamemodify(file, ":t:r"))

        if not run_zig_build({
          "zig",
          "build-exe",
          file,
          "-O",
          "Debug",
          "-femit-bin=" .. output,
        }, vim.fs.dirname(file)) then
          return nil
        end
        return output
      end

      dap.configurations.zig = {
        {
          name = "Launch project (zig build)",
          type = "codelldb",
          request = "launch",
          program = zig_project_executable,
          cwd = zig_project_directory,
          stopOnEntry = false,
          args = function()
            local raw = vim.fn.input("Args (space-separated): ")
            return vim.split(raw, " ", { trimempty = true })
          end,
        },
        {
          name = "Launch file (zig build-exe)",
          type = "codelldb",
          request = "launch",
          program = zig_file_executable,
          cwd = current_file_directory,
          stopOnEntry = false,
          args = function()
            local raw = vim.fn.input("Args (space-separated): ")
            return vim.split(raw, " ", { trimempty = true })
          end,
        },
        {
          name = "Launch executable (codelldb)",
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

      local function go_package_directory()
        local file = vim.api.nvim_buf_get_name(0)
        return file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
      end

      go_module_directory = function()
        local directory = go_package_directory()
        local go_mod = vim.fs.find("go.mod", { path = directory, upward = true })[1]
        return go_mod and vim.fs.dirname(go_mod) or directory
      end

      go_main_directory = function()
        local package_directory = go_package_directory()
        local module_directory = go_module_directory()
        local package = vim.system(
          { "go", "list", "-f", "{{.Name}}", "." },
          { cwd = package_directory, text = true }
        ):wait()
        if package.code == 0 and vim.trim(package.stdout or "") == "main" then
          return package_directory
        end

        local result = vim.system(
          { "go", "list", "-f", '{{if eq .Name "main"}}{{.Dir}}{{end}}', "./..." },
          { cwd = module_directory, text = true }
        ):wait()
        local main_packages = vim.tbl_filter(function(path)
          return path ~= ""
        end, vim.split(result.stdout or "", "\n", { trimempty = true }))

        if result.code == 0 and #main_packages > 0 then
          local module_name = vim.fs.basename(module_directory)
          for _, path in ipairs(main_packages) do
            if vim.fs.basename(path) == module_name then
              return path
            end
          end
          return main_packages[1]
        end

        vim.notify("No runnable Go main package found; debugging the current package", vim.log.levels.WARN, {
          title = "DAP",
        })
        return package_directory
      end

      local dap_go_adapter = dap.adapters.go
      dap.adapters.go = function(callback, client_config)
        dap_go_adapter(function(adapter)
          adapter = vim.deepcopy(adapter)
          if adapter.executable then
            adapter.executable.cwd = client_config.cwd or go_module_directory()
          end
          callback(adapter)
        end, client_config)
      end

      -- nvim-dap-go's default "launch" configurations ship without args.
      -- Pull them from the workspace .vscode/launch.json at debug time,
      -- leaving configs that already define args (e.g. the prompt-based
      -- "Debug (Arguments)") untouched.
      for _, config in ipairs(dap.configurations.go or {}) do
        if config.request == "launch" and config.args == nil then
          config.args = go_launch_json_args
        end
        if config.name == "Debug" then
          -- Library files are not launchable. Resolve the module's runnable
          -- main package while still allowing main.go files to debug locally.
          config.program = go_main_directory
          config.cwd = go_module_directory
        end
      end

      local function set_language_debug_keymaps(bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set("n", "1", dap.step_over, vim.tbl_extend("force", opts, { desc = "Debug: Step Over" }))
        vim.keymap.set("n", "2", dap.step_into, vim.tbl_extend("force", opts, { desc = "Debug: Step Into" }))
        vim.keymap.set("n", "3", dap.step_out, vim.tbl_extend("force", opts, { desc = "Debug: Step Out" }))
        vim.keymap.set("n", "4", dap.run_to_cursor, vim.tbl_extend("force", opts, { desc = "Debug: Run to Cursor" }))
        vim.keymap.set("n", "5", dap.continue, vim.tbl_extend("force", opts, { desc = "Debug: Run to Next Breakpoint" }))
        vim.keymap.set("n", "b", dap.toggle_breakpoint, vim.tbl_extend("force", opts, { desc = "Debug: Toggle Breakpoint" }))
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("language_debug_keymaps", { clear = true }),
        pattern = { "go", "zig", "typescript", "javascript", "typescriptreact", "javascriptreact" },
        callback = function(event)
          set_language_debug_keymaps(event.buf)
        end,
      })

      if vim.tbl_contains({ "go", "zig", "typescript", "javascript", "typescriptreact", "javascriptreact" }, vim.bo.filetype) then
        set_language_debug_keymaps(0)
      end

      -- TypeScript / JavaScript via vscode-js-debug
      require("dap-vscode-js").setup({
        debugger_path = mason_path .. "/packages/js-debug-adapter/js-debug",
        adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
      })

      local js_debug_server = mason_path .. "/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
      local function js_debug_adapter()
        return {
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = "node",
            args = { js_debug_server, "${port}", "127.0.0.1" },
          },
        }
      end

      for _, adapter in ipairs({ "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" }) do
        dap.adapters[adapter] = js_debug_adapter()
      end

      local node_attach = {
        type = "pwa-node",
        request = "attach",
        name = "Attach to process",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
        sourceMaps = true,
        skipFiles = { "<node_internals>/**", "node_modules/**" },
      }

      local chrome_launch = {
        type = "pwa-chrome",
        request = "launch",
        name = "Launch Chrome (localhost:3000)",
        url = "http://localhost:3000",
        webRoot = "${workspaceFolder}",
        sourceMaps = true,
      }

      local typescript_configurations = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = { "--enable-source-maps" },
          sourceMaps = true,
          stopOnEntry = true,
          skipFiles = { "<node_internals>/**", "node_modules/**" },
        },
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch via ts-node",
          program = "${file}",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = { "--enable-source-maps", "--loader", "ts-node/esm" },
          sourceMaps = true,
          stopOnEntry = true,
          protocol = "inspector",
          skipFiles = { "<node_internals>/**", "node_modules/**" },
        },
        node_attach,
        chrome_launch,
      }

      local javascript_configurations = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "node",
          runtimeArgs = { "--enable-source-maps" },
          sourceMaps = true,
          skipFiles = { "<node_internals>/**", "node_modules/**" },
        },
        node_attach,
        chrome_launch,
      }

      for _, ft in ipairs({ "typescript", "typescriptreact" }) do
        dap.configurations[ft] = vim.deepcopy(typescript_configurations)
      end
      for _, ft in ipairs({ "javascript", "javascriptreact" }) do
        dap.configurations[ft] = vim.deepcopy(javascript_configurations)
      end
    end,
  },
}
