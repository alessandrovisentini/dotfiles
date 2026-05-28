-- Buffer tab line.

vim.pack.add {
  'https://github.com/akinsho/bufferline.nvim',
  'https://github.com/famiu/bufdelete.nvim',
}

require('bufferline').setup {
  options = {
    mode = 'buffers',
    themable = true,
    numbers = 'ordinal',
    close_command = 'Bdelete! %d',
    right_mouse_command = 'Bdelete! %d',
    left_mouse_command = 'buffer %d',
    middle_mouse_command = 'Bdelete! %d',
    indicator = { icon = '▎', style = 'icon' },
    buffer_close_icon = '󰅖',
    modified_icon = '●',
    close_icon = '',
    left_trunc_marker = '',
    right_trunc_marker = '',
    diagnostics = 'nvim_lsp',
    diagnostics_update_in_insert = false,
    diagnostics_indicator = function(count, level, _, _)
      local icon = level:match 'error' and ' ' or ' '
      return ' ' .. icon .. count
    end,
    offsets = {
      { filetype = 'NvimTree', text = 'File Explorer', text_align = 'center', separator = true },
      { filetype = 'neo-tree', text = 'File Explorer', text_align = 'center', separator = true },
    },
    color_icons = true,
    show_buffer_icons = true,
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
    show_duplicate_prefix = true,
    persist_buffer_sort = true,
    separator_style = 'thin',
    enforce_regular_tabs = false,
    always_show_bufferline = true,
    hover = { enabled = true, delay = 200, reveal = { 'close' } },
    sort_by = 'insert_at_end',
  },
}

-- Navigation
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Prev Buffer' })
vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next Buffer' })
vim.keymap.set('n', '[b', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Prev Buffer' })
vim.keymap.set('n', ']b', '<cmd>BufferLineCycleNext<cr>', { desc = 'Next Buffer' })
vim.keymap.set('n', '<leader>bn', '<cmd>BufferLineCycleNext<cr>', { desc = '[B]uffer [N]ext' })
vim.keymap.set('n', '<leader>bN', '<cmd>BufferLineCyclePrev<cr>', { desc = '[B]uffer [N]ext (prev)' })

-- Move buffers
vim.keymap.set('n', '<A-h>', '<cmd>BufferLineMovePrev<cr>', { desc = 'Move Buffer Left' })
vim.keymap.set('n', '<A-l>', '<cmd>BufferLineMoveNext<cr>', { desc = 'Move Buffer Right' })

-- Actions
vim.keymap.set('n', '<leader>bp', '<cmd>BufferLineTogglePin<cr>', { desc = '[B]uffer [P]in' })
vim.keymap.set('n', '<leader>bc', '<cmd>Bdelete<cr>', { desc = '[B]uffer [C]lose' })
vim.keymap.set('n', '<leader>bC', '<cmd>BufferLineCloseOthers<cr>', { desc = '[B]uffer [C]lose Others' })
vim.keymap.set('n', '<leader>bb', '<cmd>BufferLinePick<cr>', { desc = '[B]uffer Pick' })
vim.keymap.set('n', '<leader>bx', '<cmd>BufferLinePickClose<cr>', { desc = '[B]uffer Pick Close' })

-- Jump by absolute position; works even when tabs are truncated.
for i = 1, 9 do
  vim.keymap.set('n', '<leader>' .. i, function() require('bufferline').go_to(i, true) end, { desc = 'Buffer ' .. i })
end
