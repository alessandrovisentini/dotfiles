-- Flutter / Dart tooling. nvim-dap and dap-ui are loaded by plugins.debug.

vim.pack.add {
  'https://github.com/nvim-flutter/flutter-tools.nvim',
}

require('flutter-tools').setup {}

-- Re-apply the dap-ui layout with a single bottom panel.
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
