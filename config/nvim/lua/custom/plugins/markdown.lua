return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    ft = { 'markdown' },
    opts = {
      enabled = true,
      render_modes = { 'n', 'c' },
      anti_conceal = { enabled = false },
      heading = {
        enabled = true,
        sign = true,
        position = 'overlay',
        width = 'full',
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
        backgrounds = {
          'RenderMarkdownH1Bg',
          'RenderMarkdownH2Bg',
          'RenderMarkdownH3Bg',
          'RenderMarkdownH4Bg',
          'RenderMarkdownH5Bg',
          'RenderMarkdownH6Bg',
        },
        foregrounds = {
          'RenderMarkdownH1Bg',
          'RenderMarkdownH2Bg',
          'RenderMarkdownH3Bg',
          'RenderMarkdownH4Bg',
          'RenderMarkdownH5Bg',
          'RenderMarkdownH6Bg',
        },
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
      -- GitHub Dark color palette
      local colors = {
        blue = '#58a6ff',
        green = '#7ee787',
        purple = '#d2a8ff',
        orange = '#ffa657',
        red = '#ff7b72',
        gray = '#8b949e',
        bg_blue = '#388bfd',
        bg_green = '#238636',
        bg_purple = '#8957e5',
        bg_orange = '#d29922',
        bg_gray = '#484f58',
        bg_dark = '#161b22',
      }

      vim.api.nvim_set_hl(0, 'RenderMarkdownH1Bg', { fg = '#ffffff', bg = colors.bg_blue, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH2Bg', { fg = '#ffffff', bg = colors.bg_blue, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH3Bg', { fg = '#ffffff', bg = colors.bg_green, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH4Bg', { fg = '#ffffff', bg = colors.bg_purple, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH5Bg', { fg = '#ffffff', bg = colors.bg_orange, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH6Bg', { fg = '#ffffff', bg = colors.bg_gray, bold = true })

      vim.api.nvim_set_hl(0, 'RenderMarkdownLink', { fg = colors.blue, bold = true, italic = true })
      vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link', { fg = colors.blue, bold = true, italic = true })

      vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = colors.bg_dark })
      vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { fg = colors.red, bg = colors.bg_dark })

      require('render-markdown').setup(opts)

      vim.keymap.set('n', '<leader>mm', function()
        require('render-markdown').toggle()
      end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })
    end,
  },

  -- Obsidian.nvim for TTRPG vault management
  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local function load_workspaces()
        local games_file = os.getenv 'TTRPG_GAMES_CONFIG'
        if not games_file then
          return {}
        end

        local file = io.open(games_file, 'r')
        if not file then
          vim.notify('games.json not found at ' .. games_file, vim.log.levels.WARN)
          return {}
        end

        local content = file:read '*a'
        file:close()

        local ok, data = pcall(vim.json.decode, content)
        if not ok or not data.games then
          vim.notify('Failed to parse games.json', vim.log.levels.WARN)
          return {}
        end

        local ttrpg_root = os.getenv 'TTRPG_NOTES_HOME'
        if not ttrpg_root then
          vim.notify('TTRPG_NOTES_HOME environment variable not set', vim.log.levels.WARN)
          return {}
        end

        local workspaces = {}
        for _, game in ipairs(data.games) do
          local expanded_path = game.path:gsub('%$TTRPG_NOTES_HOME', ttrpg_root)
          table.insert(workspaces, {
            name = game.name,
            path = expanded_path,
          })
        end
        return workspaces
      end

      local workspaces = load_workspaces()
      if #workspaces == 0 then
        return
      end

      require('obsidian').setup {
        workspaces = workspaces,
        ui = { enable = false },
        note_id_func = function(title)
          if title then
            return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower()
          end
          return tostring(os.time())
        end,
        preferred_link_style = 'wiki',
        follow_url_func = function(url)
          vim.fn.jobstart { 'xdg-open', url }
        end,
        picker = { name = 'telescope.nvim' },
      }

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function()
          vim.keymap.set('n', 'gd', '<cmd>ObsidianFollowLink<CR>', { buffer = true, desc = '[G]o to [D]efinition' })
        end,
      })
    end,
    keys = {
      { '<CR>', '<cmd>ObsidianFollowLink<CR>', desc = 'Follow Obsidian link', ft = 'markdown' },
      { '<leader>oo', '<cmd>ObsidianOpen<CR>', desc = '[O]bsidian: [O]pen in app' },
      { '<leader>on', '<cmd>ObsidianNew<CR>', desc = '[O]bsidian: [N]ew note' },
      { '<leader>os', '<cmd>ObsidianQuickSwitch<CR>', desc = '[O]bsidian: Quick [S]witch' },
      { '<leader>of', '<cmd>ObsidianSearch<CR>', desc = '[O]bsidian: Search [F]ind' },
      { '<leader>ob', '<cmd>ObsidianBacklinks<CR>', desc = '[O]bsidian: [B]acklinks' },
      { '<leader>ol', '<cmd>ObsidianLinks<CR>', desc = '[O]bsidian: [L]inks in note' },
      { '<leader>ot', '<cmd>ObsidianTags<CR>', desc = '[O]bsidian: Search [T]ags' },
      { '<leader>or', '<cmd>ObsidianRename<CR>', desc = '[O]bsidian: [R]ename note' },
    },
  },
}
