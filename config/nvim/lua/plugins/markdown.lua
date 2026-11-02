-- Markdown rendering.

local function setup_render_markdown()
  vim.pack.add {
    'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  }

  -- GitHub Dark palette
  local colors = {
    blue = '#58a6ff',
    purple = '#d2a8ff',
    red = '#ff7b72',
    bg_red = '#b62324',
    bg_blue = '#388bfd',
    bg_cyan = '#0d9488',
    bg_green = '#238636',
    bg_purple = '#8957e5',
    bg_orange = '#d29922',
    bg_dark = '#161b22',
  }

  vim.api.nvim_set_hl(0, 'RenderMarkdownH1Bg', { fg = '#ffffff', bg = colors.bg_red, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH2Bg', { fg = '#ffffff', bg = colors.bg_blue, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH3Bg', { fg = '#ffffff', bg = colors.bg_purple, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH4Bg', { fg = '#ffffff', bg = colors.bg_green, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH5Bg', { fg = '#ffffff', bg = colors.bg_orange, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH6Bg', { fg = '#ffffff', bg = colors.bg_cyan, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownLink', { fg = colors.purple, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link', { fg = colors.blue, bold = true, italic = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { fg = colors.red, bg = colors.bg_dark })

  require('render-markdown').setup {
    enabled = true,
    render_modes = { 'n', 'c' },
    anti_conceal = { enabled = false },
    win_options = {
      conceallevel = { default = 0, rendered = 3 },
      concealcursor = { default = '', rendered = 'nc' },
    },
    heading = {
      enabled = true,
      sign = false,
      position = 'inline',
      icons = { '', '', '', '', '', '' },
      width = 'block',
      left_margin = 0,
      left_pad = 1,
      right_pad = 1,
      min_width = 0,
      backgrounds = {
        'RenderMarkdownH1Bg', 'RenderMarkdownH2Bg', 'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg', 'RenderMarkdownH5Bg', 'RenderMarkdownH6Bg',
      },
      foregrounds = {
        'RenderMarkdownH1Bg', 'RenderMarkdownH2Bg', 'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg', 'RenderMarkdownH5Bg', 'RenderMarkdownH6Bg',
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
    bullet = { enabled = true, icons = { '●', '○', '◆', '◇' } },
    checkbox = { enabled = true, unchecked = { icon = '󰄱 ' }, checked = { icon = '󰱒 ' } },
    link = {
      enabled = true,
      image = '󰥶 ',
      hyperlink = '󰌹 ',
      highlight = 'RenderMarkdownLink',
      wiki = { icon = '󰌹 ', highlight = 'RenderMarkdownLink', scope_highlight = 'RenderMarkdownLink' },
    },
  }

  vim.keymap.set('n', '<leader>mm', function() require('render-markdown').toggle() end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })
end

setup_render_markdown()
