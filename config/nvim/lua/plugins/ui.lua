vim.pack.add {
  'https://github.com/NMAC427/guess-indent.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/projekt0n/github-nvim-theme',
  'https://github.com/folke/todo-comments.nvim',
  'https://github.com/nvim-mini/mini.nvim',
}

if vim.g.have_nerd_font then vim.pack.add { 'https://github.com/nvim-tree/nvim-web-devicons' } end

require('guess-indent').setup {}

require('which-key').setup {
  delay = 500,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
    { '<leader>b', group = '[B]uffer' },
    { '<leader>c', group = '[C]ode', mode = { 'n', 'x' } },
    { '<leader>d', group = '[D]ebug' },
    { '<leader>g', group = '[G]it' },
    { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    { '<leader>m', group = '[M]arkdown' },
    { '<leader>n', group = '[N]eotest' },
    { '<leader>o', group = '[O]bsidian' },
    { '<leader>r', group = '[R]ename' },
    { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>w', group = '[W]orkspace' },
    { 'g', group = '[G]oto' },
  },
}

require('github-theme').setup {}
vim.cmd.colorscheme 'github_dark_default'

require('todo-comments').setup { signs = false }

require('mini.ai').setup {
  -- Avoid clashing with the built-in treesitter incremental-selection mappings.
  mappings = {
    around_next = 'aa',
    inside_next = 'ii',
  },
  n_lines = 500,
}

require('mini.surround').setup()

local statusline = require 'mini.statusline'
statusline.setup { use_icons = vim.g.have_nerd_font }
statusline.section_location = function() return '%2l:%-2v' end
