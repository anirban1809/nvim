return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    cmd = "Telescope",
    keys = {
      {
        "<Space>",
        function()
          local buffer_path = vim.api.nvim_buf_get_name(0)
          local directory = buffer_path ~= "" and vim.fs.dirname(buffer_path) or vim.fn.getcwd()
          require("telescope").extensions.file_browser.file_browser({
            path = directory,
            cwd = directory,
            select_buffer = true,
          })
        end,
        mode = "n",
        desc = "File Browser",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-ui-select.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local fb_actions = require("telescope._extensions.file_browser.actions")
      local sorters = require("telescope.sorters")

      local function contiguous_sorter()
        return sorters.Sorter:new({
          scoring_function = function(_, prompt, line)
            if prompt == "" then
              return 1
            end
            if vim.fn.strchars(prompt) < 2 then
              return -1
            end

            local match_start = line:lower():find(prompt:lower(), 1, true)
            if not match_start then
              return -1
            end
            return match_start + (#line / 1000)
          end,
          highlighter = function(_, prompt, display)
            if vim.fn.strchars(prompt) < 2 then
              return {}
            end

            local match_start, match_end = display:lower():find(prompt:lower(), 1, true)
            if not match_start then
              return {}
            end
            return { { start = match_start, finish = match_end } }
          end,
        })
      end

      local function create_and_open_file(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        local finder = picker.finder
        local directory = finder.path or finder.cwd
        if type(directory) == "table" and directory.absolute then
          directory = directory:absolute()
        end
        directory = tostring(directory)

        vim.ui.input({
          prompt = "Create file: ",
          default = directory .. "/",
          completion = "file",
        }, function(input)
          if not input or input == "" then
            return
          end

          local path = vim.fs.normalize(vim.fn.expand(input))
          if vim.uv.fs_stat(path) then
            vim.notify("File already exists: " .. path, vim.log.levels.WARN)
            return
          end

          vim.fn.mkdir(vim.fs.dirname(path), "p")
          local file, err = vim.uv.fs_open(path, "wx", 420)
          if not file then
            vim.notify("Could not create file: " .. err, vim.log.levels.ERROR)
            return
          end
          vim.uv.fs_close(file)

          actions.close(prompt_bufnr)
          vim.schedule(function()
            vim.cmd.edit(vim.fn.fnameescape(path))
          end)
        end)
      end

      telescope.setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "  ",
          entry_prefix = "  ",
          file_sorter = contiguous_sorter,
          generic_sorter = contiguous_sorter,
          path_display = { "truncate" },
          -- Markdown's treesitter injections (code fences, inline, frontmatter)
          -- parse asynchronously and race with Telescope's rapid preview-buffer
          -- churn, crashing with "attempt to call method 'range' (a nil value)".
          -- Use regex/vim-syntax highlighting for markdown previews instead.
          preview = {
            treesitter = { disable = { "markdown" } },
          },
          file_ignore_patterns = {
            "node_modules", ".git/", "target/", "dist/", "build/", ".next/", "%.lock",
          },
          mappings = {
            i = {
              ["<Down>"] = actions.move_selection_next,
              ["<Up>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = false,
            override_file_sorter    = false,
            case_mode = "smart_case",
          },
          ["ui-select"] = { require("telescope.themes").get_dropdown({}) },
          file_browser = {
            grouped = true,
            hijack_netrw = false,
            mappings = {
              i = {
                ["\\"] = create_and_open_file,
                ["<Del>"] = fb_actions.remove,
              },
              n = {
                ["\\"] = create_and_open_file,
                ["<Del>"] = fb_actions.remove,
              },
            },
          },
        },
      })
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
      telescope.load_extension("file_browser")
    end,
  },
}
