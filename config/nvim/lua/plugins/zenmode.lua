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
  on_open = function(win)
    -- Keep the zen float below the tabline by repositioning anything floating to row 1.
    local function reposition_zen_windows()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(w)
        if config.relative ~= '' then
          local buf = vim.api.nvim_win_get_buf(w)
          local ft = vim.bo[buf].filetype
          if ft == 'zenmode-bg' or w == win then
            local ui = vim.api.nvim_list_uis()[1]
            if ui then
              config.row = 1
              config.height = ui.height - 2
              vim.api.nvim_win_set_config(w, config)
            end
          end
        end
      end
    end

    vim.schedule(reposition_zen_windows)

    vim.api.nvim_create_augroup('ZenModeBufferSwitch', { clear = true })

    vim.api.nvim_create_autocmd('VimResized', {
      group = 'ZenModeBufferSwitch',
      callback = function() vim.schedule(reposition_zen_windows) end,
    })

    -- Force zen-friendly options on any buffer entered while zen mode is on.
    vim.api.nvim_create_autocmd('BufEnter', {
      group = 'ZenModeBufferSwitch',
      callback = function()
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = 'no'
        vim.opt_local.cursorline = false
        vim.opt_local.foldcolumn = '0'
      end,
    })
  end,
  on_close = function()
    pcall(vim.api.nvim_del_augroup_by_name, 'ZenModeBufferSwitch')
  end,
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
