return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'famiu/bufdelete.nvim',
  },
  event = 'VeryLazy',
  keys = {
    -- Navigate buffers
    { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
    { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
    { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
    { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
    -- Move buffers
    { '<A-h>', '<cmd>BufferLineMovePrev<cr>', desc = 'Move Buffer Left' },
    { '<A-l>', '<cmd>BufferLineMoveNext<cr>', desc = 'Move Buffer Right' },
    -- Buffer actions
    { '<leader>bp', '<cmd>BufferLineTogglePin<cr>', desc = '[B]uffer [P]in' },
    { '<leader>bc', '<cmd>Bdelete<cr>', desc = '[B]uffer [C]lose' },
    { '<leader>bC', '<cmd>BufferLineCloseOthers<cr>', desc = '[B]uffer [C]lose Others' },
    { '<leader>bb', '<cmd>BufferLinePick<cr>', desc = '[B]uffer Pick' },
    { '<leader>bx', '<cmd>BufferLinePickClose<cr>', desc = '[B]uffer Pick Close' },
    -- Jump to buffer by number
    { '<leader>1', '<cmd>BufferLineGoToBuffer 1<cr>', desc = 'Buffer 1' },
    { '<leader>2', '<cmd>BufferLineGoToBuffer 2<cr>', desc = 'Buffer 2' },
    { '<leader>3', '<cmd>BufferLineGoToBuffer 3<cr>', desc = 'Buffer 3' },
    { '<leader>4', '<cmd>BufferLineGoToBuffer 4<cr>', desc = 'Buffer 4' },
    { '<leader>5', '<cmd>BufferLineGoToBuffer 5<cr>', desc = 'Buffer 5' },
    { '<leader>6', '<cmd>BufferLineGoToBuffer 6<cr>', desc = 'Buffer 6' },
    { '<leader>7', '<cmd>BufferLineGoToBuffer 7<cr>', desc = 'Buffer 7' },
    { '<leader>8', '<cmd>BufferLineGoToBuffer 8<cr>', desc = 'Buffer 8' },
    { '<leader>9', '<cmd>BufferLineGoToBuffer 9<cr>', desc = 'Buffer 9' },
  },
  config = function()
    require('bufferline').setup {
      options = {
        mode = 'buffers',
        themable = true,
        numbers = 'ordinal',
        close_command = 'Bdelete! %d',
        right_mouse_command = 'Bdelete! %d',
        left_mouse_command = 'buffer %d',
        middle_mouse_command = 'Bdelete! %d',
        indicator = {
          icon = '▎',
          style = 'icon',
        },
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
          {
            filetype = 'NvimTree',
            text = 'File Explorer',
            text_align = 'center',
            separator = true,
          },
          {
            filetype = 'neo-tree',
            text = 'File Explorer',
            text_align = 'center',
            separator = true,
          },
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
        hover = {
          enabled = true,
          delay = 200,
          reveal = { 'close' },
        },
        sort_by = 'insert_after_current',
      },
    }
  end,
}
