vim.pack.add { 'https://github.com/jake-stewart/multicursor.nvim' }

local mc = require 'multicursor-nvim'
mc.setup()

local set = vim.keymap.set

-- Add a cursor at the next/previous occurrence of the word under the cursor
-- (normal mode) or the current selection (visual mode). This is the everyday
-- "select next match" action, like Ctrl-D in other editors.
set({ 'n', 'x' }, '<C-n>', function() mc.matchAddCursor(1) end, { desc = 'Multicursor: add at [n]ext match' })
set({ 'n', 'x' }, '<C-p>', function() mc.matchAddCursor(-1) end, { desc = 'Multicursor: add at [p]rev match' })

-- Add a cursor straight up or down, keeping the same column.
set({ 'n', 'x' }, '<C-Down>', function() mc.lineAddCursor(1) end, { desc = 'Multicursor: add cursor below' })
set({ 'n', 'x' }, '<C-Up>', function() mc.lineAddCursor(-1) end, { desc = 'Multicursor: add cursor above' })

-- Drop a cursor on every match in the buffer at once.
set({ 'n', 'x' }, '<leader>A', function() mc.matchAllAddCursors() end, { desc = 'Multicursor: add to [A]ll matches' })

-- Ctrl + left click to add or remove a cursor anywhere.
set('n', '<C-LeftMouse>', mc.handleMouse, { desc = 'Multicursor: toggle cursor at click' })
set('n', '<C-LeftDrag>', mc.handleMouseDrag)
set('n', '<C-LeftRelease>', mc.handleMouseRelease)

-- Freeze/unfreeze the cursor under the main one. Lets you park a cursor while
-- you keep adding others, then bring it back.
set({ 'n', 'x' }, '<C-q>', mc.toggleCursor, { desc = 'Multicursor: toggle this cursor' })

-- These mappings only exist while multiple cursors are active, so they can
-- safely shadow normal-mode keys like s/<esc> without affecting normal editing.
mc.addKeymapLayer(function(layer)
  -- Skip the current match without leaving a cursor on it, then add the next.
  layer({ 'n', 'x' }, 's', function() mc.matchSkipCursor(1) end, { desc = 'Multicursor: [s]kip to next match' })
  layer({ 'n', 'x' }, 'S', function() mc.matchSkipCursor(-1) end, { desc = 'Multicursor: [S]kip to prev match' })

  -- Move which cursor is the "main" one.
  layer({ 'n', 'x' }, '<left>', mc.prevCursor, { desc = 'Multicursor: previous cursor' })
  layer({ 'n', 'x' }, '<right>', mc.nextCursor, { desc = 'Multicursor: next cursor' })

  -- Remove just the main cursor from the set.
  layer({ 'n', 'x' }, '<leader>x', mc.deleteCursor, { desc = 'Multicursor: delete main cursor' })

  -- First <esc> re-enables frozen cursors; a second one clears all cursors.
  layer('n', '<esc>', function()
    if not mc.cursorsEnabled() then
      mc.enableCursors()
    else
      mc.clearCursors()
    end
  end)
end)

-- Reuse the colorscheme's own search/visual colors so extra cursors stay legible.
local hl = vim.api.nvim_set_hl
hl(0, 'MultiCursorCursor', { link = 'Cursor' })
hl(0, 'MultiCursorVisual', { link = 'Visual' })
hl(0, 'MultiCursorSign', { link = 'SignColumn' })
hl(0, 'MultiCursorMatchPreview', { link = 'Search' })
hl(0, 'MultiCursorDisabledCursor', { reverse = true })
hl(0, 'MultiCursorDisabledVisual', { link = 'Visual' })
hl(0, 'MultiCursorDisabledSign', { link = 'SignColumn' })
