-- nvim-dap and dap-ui come from plugins.debug.

vim.pack.add {
  'https://github.com/nvim-flutter/flutter-tools.nvim',
}

require('flutter-tools').setup {}

-- One bottom panel instead of the default dap-ui layout.
require('dapui').setup {
  icons = { expanded = '▾', collapsed = '▸' },
  layouts = {
    {
      elements = {
        { id = 'scopes', size = 0.25 },
        'breakpoints',
        'stacks',
        'watches',
      },
      size = 10,
      position = 'bottom',
    },
  },
}
