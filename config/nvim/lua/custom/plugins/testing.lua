-- Neotest + Vitest adapter, with DAP launch config for JS/TS.
-- Depends on nvim-dap which is loaded by kickstart.plugins.debug.

vim.pack.add {
  'https://github.com/antoinemadec/FixCursorHold.nvim',
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/marilari88/neotest-vitest',
}

require('neotest').setup {
  adapters = {
    require 'neotest-vitest',
  },
}

local dap = require 'dap'

-- pwa-node adapter (provided by js-debug-adapter via Mason).
if not dap.adapters['pwa-node'] then
  dap.adapters['pwa-node'] = {
    type = 'server',
    host = 'localhost',
    port = '${port}',
    executable = {
      command = 'node',
      args = {
        vim.fn.stdpath 'data' .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js',
        '${port}',
      },
    },
  }
end

for _, lang in ipairs { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact' } do
  if not dap.configurations[lang] then
    dap.configurations[lang] = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}',
      },
      {
        type = 'pwa-node',
        request = 'attach',
        name = 'Attach',
        processId = require('dap.utils').pick_process,
        cwd = '${workspaceFolder}',
      },
    }
  end
end

vim.keymap.set('n', '<leader>nr', function() require('neotest').run.run() end, { desc = '[N]eotest: [R]un test under cursor' })
vim.keymap.set('n', '<leader>nd', function() require('neotest').run.run { strategy = 'dap' } end, { desc = '[N]eotest: [D]ebug test under cursor' })
vim.keymap.set('n', '<leader>nf', function() require('neotest').run.run(vim.fn.expand '%') end, { desc = '[N]eotest: Run all tests in [F]ile' })
vim.keymap.set('n', '<leader>nF', function() require('neotest').run.run { vim.fn.expand '%', strategy = 'dap' } end, { desc = '[N]eotest: Debug all tests in [F]ile' })
vim.keymap.set('n', '<leader>no', function() require('neotest').output.open { enter = true } end, { desc = '[N]eotest: Show test [O]utput' })
vim.keymap.set('n', '<leader>nO', function() require('neotest').output_panel.toggle() end, { desc = '[N]eotest: Toggle [O]utput panel' })
vim.keymap.set('n', '<leader>ns', function() require('neotest').summary.toggle() end, { desc = '[N]eotest: Toggle [S]ummary sidebar' })
vim.keymap.set('n', '<leader>nx', function() require('neotest').run.stop() end, { desc = '[N]eotest: Stop running tests' })
vim.keymap.set('n', '<leader>nw', function() require('neotest').watch.toggle(vim.fn.expand '%') end, { desc = '[N]eotest: Toggle [W]atch mode' })
