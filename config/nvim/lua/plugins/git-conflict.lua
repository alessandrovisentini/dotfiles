vim.pack.add { 'https://github.com/akinsho/git-conflict.nvim' }

require('git-conflict').setup {
  -- Mappings are wired per-buffer below so they only exist while a file
  -- actually has conflicts, and so they carry our own descriptions.
  default_mappings = false,
  default_commands = true,
  disable_diagnostics = true,
  list_opener = 'copen',
  highlights = {
    incoming = 'DiffAdd',
    current = 'DiffText',
  },
}

-- lhs -> resolution. The choose actions also work on a visual selection.
local conflict_maps = {
  { 'co', '<Plug>(git-conflict-ours)', 'git conflict choose [o]urs (current)', { 'n', 'v' } },
  { 'ct', '<Plug>(git-conflict-theirs)', 'git conflict choose [t]heirs (incoming)', { 'n', 'v' } },
  { 'cb', '<Plug>(git-conflict-both)', 'git conflict choose [b]oth', { 'n', 'v' } },
  { 'c0', '<Plug>(git-conflict-none)', 'git conflict choose n[0]ne', { 'n', 'v' } },
  { ']x', '<Plug>(git-conflict-next-conflict)', 'git conflict ne[x]t', { 'n' } },
  { '[x', '<Plug>(git-conflict-prev-conflict)', 'git conflict pre[x]ious', { 'n' } },
  { '<leader>gx', '<cmd>GitConflictListQf<cr>', 'git conflict list (quickfi[x])', { 'n' } },
}

-- Wire the keymaps up only when a conflict is detected, so co/ct/cb/c0 don't
-- shadow the default change operators (ct{char}, cb, c0) in normal files.
vim.api.nvim_create_autocmd('User', {
  pattern = 'GitConflictDetected',
  callback = function(args)
    for _, m in ipairs(conflict_maps) do
      vim.keymap.set(m[4], m[1], m[2], { buffer = args.buf, desc = m[3] })
    end
  end,
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'GitConflictResolved',
  callback = function(args)
    for _, m in ipairs(conflict_maps) do
      pcall(vim.keymap.del, m[4], m[1], { buffer = args.buf })
    end
  end,
})
