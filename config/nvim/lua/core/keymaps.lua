vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open float diagnostic' })

-- Spell checking
vim.keymap.set('n', '<leader>St', function()
  vim.o.spell = not vim.o.spell
  vim.notify('Spell check: ' .. (vim.o.spell and 'on' or 'off'))
end, { desc = '[S]pelling: [T]oggle check' })
vim.keymap.set('n', '<leader>Sl', function()
  if vim.o.spelllang == 'en_us' then
    vim.o.spelllang = 'it'
  else
    vim.o.spelllang = 'en_us'
  end
  vim.notify('Spell language: ' .. vim.o.spelllang)
end, { desc = '[S]pelling: switch [L]anguage (en/it)' })
vim.keymap.set('n', '<leader>Sn', ']s', { desc = '[S]pelling: [N]ext misspelled word' })
vim.keymap.set('n', '<leader>Sp', '[s', { desc = '[S]pelling: [P]revious misspelled word' })
vim.keymap.set('n', '<leader>Sa', 'zg', { desc = '[S]pelling: [A]dd word to dictionary' })
vim.keymap.set('n', '<leader>Sr', 'zug', { desc = '[S]pelling: [R]emove word from dictionary' })
vim.keymap.set('n', '<leader>Sw', 'zw', { desc = '[S]pelling: mark word as [W]rong' })

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
