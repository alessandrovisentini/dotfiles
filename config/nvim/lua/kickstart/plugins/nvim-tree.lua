-- A file explorer tree for Neovim.
-- https://github.com/nvim-tree/nvim-tree.lua

local plugins = {
  'https://github.com/nvim-tree/nvim-tree.lua',
}

if vim.g.have_nerd_font then
  table.insert(plugins, 'https://github.com/nvim-tree/nvim-web-devicons') -- not strictly required, but recommended
end

vim.pack.add(plugins)

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

local FIXED_WIDTH = 40
local adaptive_mode = false

local function apply_setup()
  require('nvim-tree').setup {
    on_attach = on_attach,
    disable_netrw = true,
    -- Built-in directory hijack creates a broken/blank buffer under vim.pack's
    -- opt loading on Neovim 0.12; we open the tree ourselves on VimEnter instead.
    hijack_directories = {
      enable = false,
    },
    update_focused_file = {
      enable = true,
      update_root = {
        enable = true,
      },
    },
    view = {
      adaptive_size = adaptive_mode,
      width = FIXED_WIDTH,
    },
    git = {
      ignore = false,
    },
    filters = {
      git_ignored = false,
    },
  }
end

apply_setup()

-- When Neovim is started on a directory (e.g. `nvim .`), set it as the cwd and
-- open the tree on it. Replaces the disabled built-in directory hijack.
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function(data)
    if vim.fn.isdirectory(data.file) ~= 1 then
      return
    end
    vim.cmd.cd(data.file)
    local api = require 'nvim-tree.api'
    vim.schedule(function()
      api.tree.open()
      -- Drop the empty directory buffer (named after the folder) so only the
      -- tree and a blank editor window remain.
      if vim.api.nvim_buf_is_valid(data.buf) then
        pcall(vim.api.nvim_buf_delete, data.buf, { force = true })
      end
    end)
  end,
})

-- Toggle between adaptive and fixed width
local function toggle_adaptive_width()
  adaptive_mode = not adaptive_mode
  local api = require 'nvim-tree.api'
  api.tree.close()
  apply_setup()
  api.tree.open()
  local mode_name = adaptive_mode and 'adaptive' or 'fixed (' .. FIXED_WIDTH .. ')'
  vim.notify('NvimTree width: ' .. mode_name, vim.log.levels.INFO)
end

vim.keymap.set('n', '\\', '<Cmd>NvimTreeFindFile<CR>', { desc = 'NvimTree reveal', silent = true })
-- Toggle the tree: focus it (opening if needed) when in the editor, close it when already inside it.
vim.keymap.set('n', '<leader>tt', function()
  local api = require 'nvim-tree.api'
  if vim.bo.filetype == 'NvimTree' then
    api.tree.close()
  else
    api.tree.find_file { open = true, focus = true }
  end
end, { noremap = true, silent = true, desc = '[T]ree [T]oggle' })
vim.api.nvim_set_keymap('n', '<leader>tc', ':NvimTreeClose<CR>', { noremap = true, silent = true, desc = '[T]ree [C]lose' })
vim.api.nvim_set_keymap('n', '<leader>tb', ':wincmd p<CR>', { noremap = true, silent = true, desc = '[T]ree [B]uffer focus' })
vim.keymap.set('n', '<leader>tw', toggle_adaptive_width, { noremap = true, silent = true, desc = '[T]ree [W]idth toggle' })
