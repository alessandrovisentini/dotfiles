vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>db', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle [B]reakpoint' })
vim.keymap.set(
  'n',
  '<leader>dB',
  function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
  { desc = 'Debug: Conditional [B]reakpoint' }
)
vim.keymap.set('n', '<leader>dc', function() require('dap').clear_breakpoints() end, { desc = 'Debug: [C]lear all breakpoints' })
vim.keymap.set('n', '<leader>du', function() require('dap').up() end, { desc = 'Debug: Go [U]p in call stack' })
vim.keymap.set('n', '<leader>dd', function() require('dap').down() end, { desc = 'Debug: Go [D]own in call stack' })
vim.keymap.set({ 'n', 'v' }, '<leader>k', function() require('dapui').eval() end, { desc = 'Debug: Inspect variable under cursor' })
vim.keymap.set('n', '<F7>', function() require('dapui').toggle() end, { desc = 'Debug: See last session result.' })

local dap = require 'dap'
local dapui = require 'dapui'

require('mason-nvim-dap').setup {
  automatic_installation = true,
  handlers = {},
  ensure_installed = {
    'js-debug-adapter',
  },
}

---@diagnostic disable-next-line: missing-fields
dapui.setup {
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  -- bottom panel instead of the side one
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
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#2e4d2e' })

vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DapBreak' })
vim.fn.sign_define('DapBreakpointCondition', { text = '⊜', texthl = 'DapBreak' })
vim.fn.sign_define('DapBreakpointRejected', { text = '⊘', texthl = 'DapBreak' })
vim.fn.sign_define('DapLogPoint', { text = '◆', texthl = 'DapBreak' })
vim.fn.sign_define('DapStopped', { text = '→', texthl = 'DapStop', linehl = 'DapStoppedLine' })

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
