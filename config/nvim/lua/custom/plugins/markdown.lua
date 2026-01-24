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
      enabled = false, -- Start disabled, toggle manually with <leader>mm
      render_modes = { 'n', 'c', 'v' }, -- Only render in normal, command, visual modes (not insert)
      anti_conceal = { enabled = false },
      -- Headings with GitHub Dark colors (matching glow preview)
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
      -- GitHub Dark color palette (matching glow preview style)
      local colors = {
        blue = '#58a6ff',
        green = '#7ee787',
        purple = '#d2a8ff',
        orange = '#ffa657',
        red = '#ff7b72',
        gray = '#8b949e',
        bg_blue = '#388bfd',
        bg_dark = '#161b22',
      }

      -- Heading highlights (matching glow github-dark.json)
      vim.api.nvim_set_hl(0, 'RenderMarkdownH1Bg', { fg = '#ffffff', bg = colors.bg_blue, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH2Bg', { fg = colors.blue, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH3Bg', { fg = colors.green, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH4Bg', { fg = colors.purple, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH5Bg', { fg = colors.orange, bold = true })
      vim.api.nvim_set_hl(0, 'RenderMarkdownH6Bg', { fg = colors.gray })

      -- Link highlights (blue)
      vim.api.nvim_set_hl(0, 'RenderMarkdownLink', { fg = colors.blue, bold = true, italic = true })

      -- Wiki links (blue like regular links)
      vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = colors.blue, underline = true })
      vim.api.nvim_set_hl(0, '@markup.link', { fg = colors.blue, bold = true, italic = true })

      -- Code highlights
      vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = colors.bg_dark })
      vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { fg = colors.red, bg = colors.bg_dark })

      require('render-markdown').setup(opts)

      -- Manual toggle keybinding only - no automatic switching
      vim.keymap.set('n', '<leader>mm', function()
        require('render-markdown').toggle()
      end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })

      -- Disable spellcheck for vault folder (markdownlint disabled via .markdownlint.jsonc in vault)
      local vault_path = vim.fn.expand '~/Development/repos/ttrpg-notes'
      local vault_group = vim.api.nvim_create_augroup('VaultSettings', { clear = true })

      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
        group = vault_group,
        pattern = '*.md',
        callback = function()
          local filepath = vim.fn.expand '%:p'
          if filepath:find(vault_path, 1, true) then
            vim.opt_local.spell = false
          end
        end,
      })
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
        vim.fn.jobstart { 'xdg-open', url }
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
      { 'gd', '<cmd>ObsidianFollowLink<CR>', desc = '[G]o to [D]efinition link' },
    },
  },

}
