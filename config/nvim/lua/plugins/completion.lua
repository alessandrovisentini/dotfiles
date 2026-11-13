vim.pack.add {
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range '1.*' },
}

require('blink.cmp').setup {
  completion = {
    documentation = { auto_show = false },
  },
  sources = {
    default = { 'lsp', 'path' },
  },
  fuzzy = { implementation = 'lua' },
  signature = { enabled = true },
}
