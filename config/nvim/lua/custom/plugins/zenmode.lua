return {
  'folke/zen-mode.nvim',
  opts = {
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
      options = {
        enabled = true,
        ruler = false,
        showcmd = false,
        laststatus = 0,
        showtabline = 2,
      },
      gitsigns = { enabled = false },
      tmux = { enabled = false },
    },
    on_open = function(win)
      -- Reposition zen window and backdrop to leave space for tabline
      vim.schedule(function()
        -- Find and reposition all zen-mode floating windows
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local config = vim.api.nvim_win_get_config(w)
          if config.relative ~= '' then -- It's a floating window
            local buf = vim.api.nvim_win_get_buf(w)
            local ft = vim.bo[buf].filetype
            -- Reposition zen windows (main window or backdrop)
            if ft == 'zenmode-bg' or w == win then
              config.row = (config.row or 0) + 1
              config.height = config.height - 1
              vim.api.nvim_win_set_config(w, config)
            end
          end
        end
      end)

      -- Apply zen settings to any buffer opened while in zen mode
      vim.api.nvim_create_augroup('ZenModeBufferSwitch', { clear = true })
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
      -- Remove the autocmd when exiting zen mode
      vim.api.nvim_del_augroup_by_name('ZenModeBufferSwitch')
    end,
  },
  keys = {
    {
      '<leader>z',
      function()
        local zen = require('zen-mode')
        local view = zen.view
        -- If zen mode is open, close it and stay on current buffer
        if view and view.win and vim.api.nvim_win_is_valid(view.win) then
          local current_buf = vim.api.nvim_get_current_buf()
          zen.close()
          vim.schedule(function()
            vim.api.nvim_set_current_buf(current_buf)
          end)
        else
          zen.open()
        end
      end,
      desc = '[Z]en mode toggle',
    },
  },
}
