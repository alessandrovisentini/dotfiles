vim.pack.add { 'https://github.com/jake-stewart/multicursor.nvim' }

local mc = require 'multicursor-nvim'
mc.setup()

local set = vim.keymap.set

-- Next or previous match of the word or selection
set({ 'n', 'x' }, '<C-n>', function() mc.matchAddCursor(1) end, { desc = 'Multicursor: add at [n]ext match' })
set({ 'n', 'x' }, '<C-p>', function() mc.matchAddCursor(-1) end, { desc = 'Multicursor: add at [p]rev match' })

set({ 'n', 'x' }, '<C-Down>', function() mc.lineAddCursor(1) end, { desc = 'Multicursor: add cursor below' })
set({ 'n', 'x' }, '<C-Up>', function() mc.lineAddCursor(-1) end, { desc = 'Multicursor: add cursor above' })

set({ 'n', 'x' }, '<leader>A', function() mc.matchAllAddCursors() end, { desc = 'Multicursor: add to [A]ll matches' })

set('n', '<C-LeftMouse>', mc.handleMouse, { desc = 'Multicursor: toggle cursor at click' })
set('n', '<C-LeftDrag>', mc.handleMouseDrag)
set('n', '<C-LeftRelease>', mc.handleMouseRelease)

set({ 'n', 'x' }, '<C-q>', mc.toggleCursor, { desc = 'Multicursor: toggle this cursor' })

mc.addKeymapLayer(function(layer)
  -- Skip the current match without leaving a cursor on it, then add the next
  layer({ 'n', 'x' }, 's', function() mc.matchSkipCursor(1) end, { desc = 'Multicursor: [s]kip to next match' })
  layer({ 'n', 'x' }, 'S', function() mc.matchSkipCursor(-1) end, { desc = 'Multicursor: [S]kip to prev match' })

  -- Move which cursor is the "main" one.
  layer({ 'n', 'x' }, '<left>', mc.prevCursor, { desc = 'Multicursor: previous cursor' })
  layer({ 'n', 'x' }, '<right>', mc.nextCursor, { desc = 'Multicursor: next cursor' })

  layer({ 'n', 'x' }, '<leader>x', mc.deleteCursor, { desc = 'Multicursor: delete main cursor' })

  -- First esc re-enables frozen cursors, then a second one removes all cursors
  layer('n', '<esc>', function()
    if not mc.cursorsEnabled() then
      mc.enableCursors()
    else
      mc.clearCursors()
    end
  end)
end)

-- Extra cursors look like the normal cursor
vim.api.nvim_set_hl(0, 'MultiCursorCursor', { link = 'Cursor' })
