return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'marilari88/neotest-vitest',
    },
    keys = {
      {
        '<leader>nr',
        function()
          require('neotest').run.run()
        end,
        desc = '[N]eotest: [R]un test under cursor',
      },
      {
        '<leader>nd',
        function()
          require('neotest').run.run { strategy = 'dap' }
        end,
        desc = '[N]eotest: [D]ebug test under cursor',
      },
      {
        '<leader>nf',
        function()
          require('neotest').run.run(vim.fn.expand '%')
        end,
        desc = '[N]eotest: Run all tests in [F]ile',
      },
      {
        '<leader>nF',
        function()
          require('neotest').run.run { vim.fn.expand '%', strategy = 'dap' }
        end,
        desc = '[N]eotest: Debug all tests in [F]ile',
      },
      {
        '<leader>no',
        function()
          require('neotest').output.open { enter = true }
        end,
        desc = '[N]eotest: Show test [O]utput',
      },
      {
        '<leader>nO',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = '[N]eotest: Toggle [O]utput panel',
      },
      {
        '<leader>ns',
        function()
          require('neotest').summary.toggle()
        end,
        desc = '[N]eotest: Toggle [S]ummary sidebar',
      },
      {
        '<leader>nx',
        function()
          require('neotest').run.stop()
        end,
        desc = '[N]eotest: Stop running tests',
      },
      {
        '<leader>nw',
        function()
          require('neotest').watch.toggle(vim.fn.expand '%')
        end,
        desc = '[N]eotest: Toggle [W]atch mode',
      },
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-vitest',
        },
      }

      -- Configure DAP for JavaScript/TypeScript debugging with pwa-node
      local dap = require 'dap'

      -- pwa-node adapter configuration (provided by js-debug-adapter via Mason)
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

      -- TypeScript/JavaScript debug configurations
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
    end,
  },
}
