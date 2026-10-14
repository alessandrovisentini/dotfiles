vim.pack.add {
  'https://github.com/NMAC427/guess-indent.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/projekt0n/github-nvim-theme',
  'https://github.com/nvim-mini/mini.nvim',
}

require('guess-indent').setup {}

require('which-key').setup {
  delay = 500,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
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
    { 'g', group = '[G]oto' },
  },
}

require('github-theme').setup {}
vim.cmd.colorscheme 'github_dark_default'

-- Stands in for nvim-web-devicons so other plugins find it.
require('mini.icons').setup {}
require('mini.icons').mock_nvim_web_devicons()

require('mini.ai').setup {
  -- an/in are the built-in treesitter node selection, aa would hide the argument object.
  mappings = {
    around_next = 'aN',
    inside_next = 'iN',
  },
  n_lines = 500,
}

require('mini.surround').setup()
require('mini.pairs').setup {}

local indentscope = require 'mini.indentscope'
indentscope.setup {
  symbol = '│',
  draw = {
    -- Draw the scope line instantly instead of animating it open.
    animation = indentscope.gen_animation.none(),
  },
}

local statusline = require 'mini.statusline'
statusline.setup { use_icons = vim.g.have_nerd_font }
statusline.section_location = function() return '%2l:%-2v' end
