-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

local plugins = {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

if vim.g.have_nerd_font then
  table.insert(plugins, 'https://github.com/nvim-tree/nvim-web-devicons') -- not strictly required, but recommended
end

vim.pack.add(plugins)

vim.keymap.set('n', '\\', '<Cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })

-- Focus-toggle between tree and editor. Tree stays open across presses.
--   in tree     -> jump back to the previous window (editor stays as-is)
--   in editor   -> focus the existing tree, or open one if none exists
-- Use <leader>tc to actually close the tree.
vim.keymap.set('n', '<leader>tt', function()
  if vim.bo.filetype == 'neo-tree' then
    vim.cmd 'wincmd p'
    return
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'neo-tree' then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.cmd 'Neotree focus reveal'
end, { desc = '[T]ree focus toggle', silent = true })

vim.keymap.set('n', '<leader>tc', '<Cmd>Neotree close<CR>', { desc = '[T]ree [C]lose', silent = true })

require('neo-tree').setup {
  filesystem = {
    filtered_items = {
      visible = true,
      hide_dotfiles = false,
      hide_gitignored = false,
      hide_hidden = false,
    },
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
}
