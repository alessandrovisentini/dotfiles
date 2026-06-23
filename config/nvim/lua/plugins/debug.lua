vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>db', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle [B]reakpoint' })
vim.keymap.set('n', '<leader>dB', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Conditional [B]reakpoint' })
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

local dap_icons = vim.g.have_nerd_font
    and { breakpoint = '', condition = '', rejected = '', logpoint = '', stopped = '' }
  or { breakpoint = '●', condition = '⊜', rejected = '⊘', logpoint = '◆', stopped = '→' }

local function define_dap_signs()
  vim.fn.sign_define('DapBreakpoint', { text = dap_icons.breakpoint, texthl = 'DapBreak', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointCondition', { text = dap_icons.condition, texthl = 'DapBreak', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointRejected', { text = dap_icons.rejected, texthl = 'DapBreak', linehl = '', numhl = '' })
  vim.fn.sign_define('DapLogPoint', { text = dap_icons.logpoint, texthl = 'DapBreak', linehl = '', numhl = '' })
  vim.fn.sign_define('DapStopped', { text = dap_icons.stopped, texthl = 'DapStop', linehl = 'DapStoppedLine', numhl = '' })
end

define_dap_signs()
-- Redefine when a session starts in case something overwrites them.
dap.listeners.after.event_initialized['dap_signs'] = define_dap_signs

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
