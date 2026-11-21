-- Markdown rendering.

vim.pack.add {
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
}

-- GitHub Dark colorscheme
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

-- Keep the link colors above instead of markdown-oxide's
vim.api.nvim_set_hl(0, '@lsp.type.decorator.markdown', {})
vim.api.nvim_set_hl(0, '@lsp.type.comment.markdown', {})

-- Links to missing notes in red, markdown-oxide tags them as comments.
-- High priority to win over render-markdown's link color.
vim.api.nvim_set_hl(0, 'MarkdownUnresolvedLink', { fg = colors.red })
vim.api.nvim_create_autocmd('LspTokenUpdate', {
  callback = function(args)
    local token = args.data.token
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if token.type == 'comment' and client and client.name == 'markdown_oxide' then
      vim.lsp.semantic_tokens.highlight_token(token, args.buf, client.id, 'MarkdownUnresolvedLink', { priority = 5000 })
    end
  end,
})

require('render-markdown').setup {
  render_modes = { 'n', 'c' },
  anti_conceal = { enabled = false },
  win_options = {
    conceallevel = { default = 0, rendered = 3 },
    concealcursor = { default = '', rendered = 'nc' },
  },
  heading = {
    sign = false,
    position = 'inline',
    icons = { '', '', '', '', '', '' },
    width = 'block',
    left_pad = 1,
    right_pad = 1,
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
    sign = false,
    width = 'block',
    border = 'thin',
    left_pad = 2,
    right_pad = 2,
  },
  link = {
    wiki = { icon = '󰌹 ', highlight = 'RenderMarkdownLink', scope_highlight = 'RenderMarkdownLink' },
  },
}

vim.keymap.set('n', '<leader>mm', function() require('render-markdown').toggle() end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })
