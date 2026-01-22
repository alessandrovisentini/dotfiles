return {
  -- Render Markdown with Treesitter (Reader Mode)
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    ft = { 'markdown' },
    opts = {
      -- Use most defaults, they look good
      enabled = true,
      render_modes = { 'n', 'c' },
      anti_conceal = { enabled = false },
      -- Headings with background highlight and icons
      heading = {
        enabled = true,
        sign = true,
        position = 'overlay',
        width = 'full',
        -- Default nerd font icons
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
      },
      code = {
        enabled = true,
        sign = false,
        style = 'full',
        width = 'block',
        border = 'thin',
        left_pad = 2,
        right_pad = 2,
      },
      bullet = {
        enabled = true,
        icons = { '●', '○', '◆', '◇' },
      },
      checkbox = {
        enabled = true,
        unchecked = { icon = '󰄱 ' },
        checked = { icon = '󰱒 ' },
      },
      link = {
        enabled = true,
        image = '󰥶 ',
        hyperlink = '󰌹 ',
        highlight = 'RenderMarkdownLink',
        wiki = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
      },
    },
    config = function(_, opts)
      -- Set custom highlight for links (cyan/blue color for visibility)
      vim.api.nvim_set_hl(0, 'RenderMarkdownLink', { fg = '#58a6ff', underline = true })

      -- Also set Treesitter highlights for link text to be colored and underlined
      vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = '#58a6ff', underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = '#58a6ff', underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = '#58a6ff', underline = true })
      -- Wiki links for obsidian
      vim.api.nvim_set_hl(0, '@markup.link', { fg = '#58a6ff', underline = true })

      require('render-markdown').setup(opts)

      -- Manual toggle keybinding only - no automatic switching
      vim.keymap.set('n', '<leader>mm', function()
        require('render-markdown').toggle()
      end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })

      -- Disable spellcheck for vault folder (markdownlint disabled via .markdownlint.jsonc in vault)
      local vault_path = vim.fn.expand('~/Development/repos/ttrpg-notes')
      local vault_group = vim.api.nvim_create_augroup('VaultSettings', { clear = true })

      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
        group = vault_group,
        pattern = '*.md',
        callback = function()
          local filepath = vim.fn.expand('%:p')
          if filepath:find(vault_path, 1, true) then
            vim.opt_local.spell = false
          end
        end,
      })
    end,
  },

  -- Zen mode for distraction-free reading with margins
  {
    'folke/zen-mode.nvim',
    ft = { 'markdown' },
    opts = {
      window = {
        backdrop = 1,
        width = 120, -- Width of the centered text area (wider for tables)
        height = 1, -- Full height
        options = {
          signcolumn = 'no',
          number = false,
          relativenumber = false,
          cursorline = false,
          foldcolumn = '0',
          wrap = true,
          linebreak = true, -- Wrap at word boundaries, not mid-word
        },
      },
      plugins = {
        options = {
          enabled = true,
          ruler = false,
          showcmd = false,
          laststatus = 0,
        },
        gitsigns = { enabled = false },
        tmux = { enabled = false },
      },
    },
    keys = {
      { '<leader>mz', '<cmd>ZenMode<CR>', desc = '[M]arkdown: [Z]en mode toggle' },
    },
    config = function(_, opts)
      require('zen-mode').setup(opts)
      -- Use <leader>mz to manually toggle zen mode, no auto-open
    end,
  },

  -- Obsidian.nvim for vault management (wiki links, backlinks)
  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      workspaces = {
        { name = 'ttrpg-notes', path = '~/Development/repos/ttrpg-notes' },
      },
      ui = { enable = false }, -- Use render-markdown.nvim instead
      note_id_func = function(title)
        if title then
          return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower()
        end
        return tostring(os.time())
      end,
      preferred_link_style = 'wiki',
      follow_url_func = function(url)
        vim.fn.jobstart({ 'xdg-open', url })
      end,
      picker = { name = 'telescope.nvim' },
    },
    keys = {
      { '<CR>', '<cmd>ObsidianFollowLink<CR>', desc = 'Follow Obsidian link', ft = 'markdown' },
      { '<leader>mo', '<cmd>ObsidianOpen<CR>', desc = '[M]arkdown: [O]pen in Obsidian' },
      { '<leader>mn', '<cmd>ObsidianNew<CR>', desc = '[M]arkdown: [N]ew note' },
      { '<leader>ms', '<cmd>ObsidianQuickSwitch<CR>', desc = '[M]arkdown: Quick [S]witch' },
      { '<leader>mf', '<cmd>ObsidianSearch<CR>', desc = '[M]arkdown: Search [F]ind' },
      { '<leader>mb', '<cmd>ObsidianBacklinks<CR>', desc = '[M]arkdown: [B]acklinks' },
      { '<leader>ml', '<cmd>ObsidianLinks<CR>', desc = '[M]arkdown: [L]inks in note' },
      { '<leader>mt', '<cmd>ObsidianTags<CR>', desc = '[M]arkdown: Search [T]ags' },
      { '<leader>mr', '<cmd>ObsidianRename<CR>', desc = '[M]arkdown: [R]ename note' },
      { '<leader>mk', '<cmd>ObsidianFollowLink<CR>', desc = '[M]arkdown: Follow lin[K]' },
    },
  },

  -- Vault-specific Telescope searches with glow preview
  -- Using keys instead of config to avoid overriding main Telescope setup
  {
    'nvim-telescope/telescope.nvim',
    optional = true,
    keys = {
      {
        '<leader>mF',
        function()
          local previewers = require('telescope.previewers')
          local Job = require('plenary.job')

          local glow_previewer = previewers.new_buffer_previewer({
            title = 'Markdown Preview (Glow)',
            define_preview = function(self, entry, status)
              local filepath = entry.path or entry.filename
              if not filepath then
                return
              end

              local ext = filepath:match('%.([^%.]+)$')
              if ext and (ext == 'md' or ext == 'markdown') then
                local width = vim.api.nvim_win_get_width(status.preview_win)
                Job:new({
                  command = 'glow',
                  args = { '-s', 'dark', '-w', tostring(width), filepath },
                  on_exit = function(j, return_val)
                    if return_val == 0 then
                      vim.schedule(function()
                        if self.state and self.state.bufnr and vim.api.nvim_buf_is_valid(self.state.bufnr) then
                          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, j:result())
                        end
                      end)
                    end
                  end,
                }):start()
              else
                previewers.buffer_previewer_maker(filepath, self.state.bufnr, {
                  bufname = self.state.bufname,
                  winid = self.state.winid,
                })
              end
            end,
          })

          require('telescope.builtin').find_files({
            cwd = vim.fn.expand('~/Development/repos/ttrpg-notes'),
            prompt_title = 'Find Notes (Vault)',
            previewer = glow_previewer,
          })
        end,
        desc = '[M]arkdown: [F]ind files in vault',
      },
      {
        '<leader>mG',
        function()
          require('telescope.builtin').live_grep({
            cwd = vim.fn.expand('~/Development/repos/ttrpg-notes'),
            prompt_title = 'Grep Notes (Vault)',
            additional_args = function()
              return { '--type', 'md' }
            end,
          })
        end,
        desc = '[M]arkdown: [G]rep in vault',
      },
    },
  },
}
