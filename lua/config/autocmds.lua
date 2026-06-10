local function augroup(name)
  return vim.api.nvim_create_augroup("nvim_" .. name, { clear = true })
end

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function() vim.hl.on_yank({ timeout = 200 }) end,
})

-- Trim trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("trim_whitespace"),
  callback = function(event)
    if not vim.bo[event.buf].modifiable or vim.bo[event.buf].buftype ~= "" then
      return
    end
    local save = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Filetype-specific indents
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("indent_2sp"),
  pattern = { "lua", "typescript", "typescriptreact", "javascript", "javascriptreact", "json", "yaml", "html", "css" },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("indent_go"),
  pattern = "go",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

-- Auto-create parent dirs on write
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_mkdir"),
  callback = function(event)
    if event.match == "" or event.match:match("^%w+://") then
      return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(event.match, ":p:h"), "p")
  end,
})

-- Close some filetypes with q or <Esc>
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "qf", "help", "man", "lspinfo", "checkhealth", "dap-float" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    local opts = { buffer = event.buf, silent = true }
    vim.keymap.set("n", "q", "<cmd>close<CR>", opts)
    -- Buffer-local <Esc> shadows the global nohlsearch map so these read-only
    -- views (e.g. the LSP references quickfix list) close instead of erroring
    -- with E21 when stray edit keys hit a non-modifiable buffer.
    vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", opts)

    if vim.bo[event.buf].filetype == "qf" then
      vim.keymap.set("n", "<CR>", function()
        local index = vim.api.nvim_win_get_cursor(0)[1]
        local items = vim.fn.getqflist({ items = 0 }).items
        if not items[index] or items[index].valid ~= 1 then
          return
        end

        vim.fn.setqflist({}, "a", { idx = index })
        vim.cmd.close()
        vim.cmd.cc()
      end, vim.tbl_extend("force", opts, {
        desc = "Quickfix: Open Selection",
      }))
    end
  end,
})
