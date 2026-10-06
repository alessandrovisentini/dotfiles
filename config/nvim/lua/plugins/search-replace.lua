vim.pack.add { 'https://github.com/MagicDuck/grug-far.nvim' }

local grug = require 'grug-far'
grug.setup {}

vim.keymap.set('n', '<leader>sR', function() grug.open() end, { desc = '[S]earch and [R]eplace' })
vim.keymap.set('n', '<leader>sW', function()
  grug.open { prefills = { search = vim.fn.expand '<cword>' } }
end, { desc = '[S]earch and replace current [W]ord' })
vim.keymap.set('x', '<leader>sW', function() grug.with_visual_selection() end, { desc = '[S]earch and replace selection' })
vim.keymap.set('n', '<leader>sB', function()
  grug.open { prefills = { paths = vim.fn.expand '%' } }
end, { desc = '[S]earch and replace in current [B]uffer' })
