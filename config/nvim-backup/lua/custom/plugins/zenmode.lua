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
      -- Function to reposition zen windows for tabline space
      local function reposition_zen_windows()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local config = vim.api.nvim_win_get_config(w)
          if config.relative ~= '' then
            local buf = vim.api.nvim_win_get_buf(w)
            local ft = vim.bo[buf].filetype
            if ft == 'zenmode-bg' or w == win then
              -- Calculate proper position: row 1 (after tabline), full remaining height
              local ui = vim.api.nvim_list_uis()[1]
              if ui then
                config.row = 1
                config.height = ui.height - 2 -- Leave space for tabline
                vim.api.nvim_win_set_config(w, config)
              end
            end
          end
        end
      end

      -- Initial reposition
      vim.schedule(reposition_zen_windows)

      -- Create autocmd group
      vim.api.nvim_create_augroup('ZenModeBufferSwitch', { clear = true })

      -- Reposition on resize
      vim.api.nvim_create_autocmd('VimResized', {
        group = 'ZenModeBufferSwitch',
        callback = function()
          vim.schedule(reposition_zen_windows)
        end,
      })

      -- Apply zen settings to any buffer opened while in zen mode
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

      -- Override buffer navigation to work in zen mode floating window
      for i = 1, 9 do
        vim.keymap.set('n', '<leader>' .. i, function()
          local buffers = vim.fn.getbufinfo({ buflisted = 1 })
          if buffers[i] and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_set_buf(win, buffers[i].bufnr)
          end
        end, { desc = 'Buffer ' .. i })
      end
    end,
    on_close = function()
      -- Remove the autocmd group
      vim.api.nvim_del_augroup_by_name('ZenModeBufferSwitch')

      -- Restore original buffer navigation keymaps
      for i = 1, 9 do
        vim.keymap.set('n', '<leader>' .. i, '<cmd>BufferLineGoToBuffer ' .. i .. '<cr>', { desc = 'Buffer ' .. i })
      end
    end,
  },
  keys = {
    {
      '<leader>z',
      function()
        local zen = require('zen-mode')
        local view = zen.view
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
