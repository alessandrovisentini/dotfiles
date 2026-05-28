-- Flutter / Dart tooling. dap UI and nvim-dap are loaded by kickstart.plugins.debug.

vim.pack.add {
  'https://github.com/stevearc/dressing.nvim',
  'https://github.com/nvim-flutter/flutter-tools.nvim',
}

-- flutter-tools self-initialises and discovers Flutter via PATH; explicit setup keeps it predictable.
require('flutter-tools').setup {}

-- Override the dap-ui layout that kickstart.plugins.debug applied with a bottom-row panel,
-- matching the layout used in the previous nvim config.
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
