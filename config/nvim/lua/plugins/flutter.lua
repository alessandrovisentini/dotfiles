vim.pack.add {
  'https://github.com/nvim-flutter/flutter-tools.nvim',
}

require('flutter-tools').setup {
  debugger = { enabled = true },
}
