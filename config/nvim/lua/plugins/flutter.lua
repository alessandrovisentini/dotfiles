-- Only where the Flutter SDK is installed
if vim.fn.executable 'flutter' == 0 then return end

vim.pack.add {
  'https://github.com/nvim-flutter/flutter-tools.nvim',
}

require('flutter-tools').setup {
  debugger = { enabled = true },
}
