return {
  'nvim-tree/nvim-tree.lua',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local function on_attach(bufnr)
      local api = require 'nvim-tree.api'

      local function opts(desc)
        return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      -- Default mappings
      api.config.mappings.default_on_attach(bufnr)

      -- Custom mapping: 'v' to view images with imv
      vim.keymap.set('n', 'v', function()
        local node = api.tree.get_node_under_cursor()
        if node and node.type == 'file' then
          local extension = node.name:match '^.+%.(.+)$'
          if extension and vim.tbl_contains({ 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'ico' }, extension:lower()) then
            -- View image with imv
            vim.fn.jobstart({ 'imv', node.absolute_path }, { detach = true })
          end
        end
      end, opts 'View image with imv')
    end

    require('nvim-tree').setup {
      on_attach = on_attach,
      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = {},
      },
      view = { adaptive_size = true },
      git = {
        ignore = false,
      },
      filters = {
        git_ignored = false,
      },
    }

    vim.api.nvim_set_keymap('n', '<leader>tt', ':NvimTreeToggle<CR>:NvimTreeFocus<CR>', { noremap = true, silent = true, desc = '[T]ree [T]oggle' })
    vim.api.nvim_set_keymap('n', '<leader>tc', ':NvimTreeClose<CR>', { noremap = true, silent = true, desc = '[T]ree [C]lose' })
    vim.api.nvim_set_keymap('n', '<leader>tb', ':wincmd p<CR>', { noremap = true, silent = true, desc = '[T]ree [B]uffer focus' })
  end,
}
