-- Depends on plenary.nvim, already added by plugins.telescope (loaded earlier).
vim.pack.add { 'https://github.com/sindrets/diffview.nvim' }

require('diffview').setup {
  enhanced_diff_hl = true,
  view = {
    -- VSCode-like 3-way merge: OURS and THEIRS on top, merged result below.
    merge_tool = {
      layout = 'diff3_mixed',
      disable_diagnostics = true,
    },
  },
}

local map = vim.keymap.set
map('n', '<leader>gm', '<cmd>DiffviewOpen<cr>', { desc = 'git [m]erge/diff view (Diffview)' })
map('n', '<leader>gM', '<cmd>DiffviewClose<cr>', { desc = 'git close Diffview' })
map('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = 'git file [h]istory (current file)' })
map('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>', { desc = 'git file [H]istory (repo)' })
