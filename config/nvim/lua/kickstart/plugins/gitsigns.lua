-- Adds git related signs to the gutter, as well as utilities for managing changes
-- NOTE: gitsigns is already included in init.lua but contains only the base
-- config. This will add also the recommended keymaps.

vim.pack.add { 'https://github.com/lewis6991/gitsigns.nvim' }

require('gitsigns').setup {
  current_line_blame = true,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol',
    delay = 1000,
    ignore_whitespace = false,
    virt_text_priority = 100,
    use_focus = true,
  },
  on_attach = function(bufnr)
    local gitsigns = require 'gitsigns'

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    local function get_repo_url()
      local remote = vim.fn.system({ 'git', 'remote', 'get-url', 'origin' }):gsub('%s+$', '')
      remote = remote:gsub('ssh://git@([^/]+)/', 'https://%1/')
      remote = remote:gsub('^git@([^:]+):', 'https://%1/')
      remote = remote:gsub('%.git$', '')
      return remote
    end

    local function get_blame_sha()
      local file = vim.fn.expand '%'
      local line = vim.fn.line '.'
      local sha = vim.fn.system({ 'git', 'blame', '-l', '-L', line .. ',' .. line, '--', file }):match '^(%x+)'
      if not sha or sha:match '^0+$' then
        vim.notify('No commit found for this line', vim.log.levels.WARN)
        return nil
      end
      return sha
    end

    -- Open the current line's commit on the origin host (GitHub-style URL rewrite).
    map('n', '<leader>gb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line' })
    map('n', '<leader>gc', function()
      local sha = get_blame_sha()
      if not sha then return end
      vim.ui.open(get_repo_url() .. '/commit/' .. sha)
    end, { desc = 'git open [c]ommit in browser' })
    map('n', '<leader>gd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
    map('n', '<leader>gD', function() gitsigns.diffthis '@' end, { desc = 'git [D]iff against last commit' })

    -- Navigation
    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        gitsigns.nav_hunk 'next'
      end
    end, { desc = 'Jump to next git [c]hange' })

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        gitsigns.nav_hunk 'prev'
      end
    end, { desc = 'Jump to previous git [c]hange' })

    -- Actions
    -- visual mode
    map('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk' })
    map('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk' })
    -- normal mode
    map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
    map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
    map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
    map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
    map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
    map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline' })
    map('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line' })
    map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
    map('n', '<leader>hD', function() gitsigns.diffthis '@' end, { desc = 'git [D]iff against last commit' })
    map('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, { desc = 'git hunk [Q]uickfix list (all files in repo)' })
    map('n', '<leader>hq', gitsigns.setqflist, { desc = 'git hunk [q]uickfix list (all changes in this file)' })
    -- Toggles
    map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })

    -- Text object
    map({ 'o', 'x' }, 'ih', gitsigns.select_hunk)
  end,
}
