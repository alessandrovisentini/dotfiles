vim.pack.add { 'https://github.com/mfussenegger/nvim-lint' }

local lint = require 'lint'
lint.linters_by_ft = {}
if vim.fn.executable 'markdownlint' == 1 then
  lint.linters_by_ft['markdown'] = { 'markdownlint' }
end

local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = lint_augroup,
  callback = function()
    -- Skip non-modifiable buffers (e.g. LSP hover popups rendered as markdown).
    if vim.bo.modifiable then lint.try_lint() end
  end,
})
