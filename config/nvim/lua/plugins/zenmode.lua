vim.pack.add { 'https://github.com/folke/zen-mode.nvim' }

require('zen-mode').setup {
  window = {
    backdrop = 1,
    width = 120,
    height = 1,
    options = {
      signcolumn = 'no',
      number = false,
      relativenumber = false,
      cursorline = false,
      foldcolumn = '0',
      wrap = true,
      linebreak = true,
    },
  },
  plugins = {
    options = { enabled = true, ruler = false, showcmd = false, laststatus = 0, showtabline = 2 },
    gitsigns = { enabled = false },
    tmux = { enabled = false },
  },
}

vim.keymap.set('n', '<leader>z', function()
  local zen = require 'zen-mode'
  local view = zen.view
  if view and view.win and vim.api.nvim_win_is_valid(view.win) then
    local current_buf = vim.api.nvim_get_current_buf()
    zen.close()
    vim.schedule(function() vim.api.nvim_set_current_buf(current_buf) end)
  else
    zen.open()
  end
end, { desc = '[Z]en mode toggle' })
