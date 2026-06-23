vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open float diagnostic' })

-- Spell checking
vim.keymap.set('n', '<leader>ts', function() vim.o.spell = not vim.o.spell end, { desc = '[T]oggle [S]pell checking' })
vim.keymap.set('n', 'zn', ']s', { desc = 'Next misspelled word' })
vim.keymap.set('n', 'zp', '[s', { desc = 'Previous misspelled word' })
vim.keymap.set('n', 'za', 'zg', { desc = 'Add word to dictionary' })
vim.keymap.set('n', 'zr', 'zw', { desc = 'Remove word from dictionary' })
vim.keymap.set('n', 'zs', 'z=', { desc = 'Suggest spelling corrections' })

vim.keymap.set('n', '<leader>tn', function()
  vim.o.relativenumber = not vim.o.relativenumber
  vim.o.number = true
end, { desc = '[T]oggle line [N]umbers (relative/absolute)' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Window navigation with CTRL+hjkl
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
