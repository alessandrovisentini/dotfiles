return {
  'nvim-tree/nvim-tree.lua',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    require('nvim-tree').setup {
      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = {},
      },
      view = { adaptive_size = true },
      git = {
        ignore = false,
      },
      filters = {
        git_ignored = false,
      },
    }

    vim.api.nvim_set_keymap('n', '<leader>tt', ':NvimTreeToggle<CR>:NvimTreeFocus<CR>', { noremap = true, silent = true, desc = '[T]ree [T]oggle' })
    vim.api.nvim_set_keymap('n', '<leader>tc', ':NvimTreeClose<CR>', { noremap = true, silent = true, desc = '[T]ree [C]lose' })
    vim.api.nvim_set_keymap('n', '<leader>tb', ':wincmd p<CR>', { noremap = true, silent = true, desc = '[T]ree [B]uffer focus' })
  end,
}
