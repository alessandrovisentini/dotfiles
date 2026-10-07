vim.pack.add { 'https://github.com/nvim-tree/nvim-tree.lua' }

local function on_attach(bufnr)
  local api = require 'nvim-tree.api'

  local function opts(desc)
    return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  api.config.mappings.default_on_attach(bufnr)

  vim.keymap.set('n', 'v', function()
    local node = api.tree.get_node_under_cursor()
    if node and node.type == 'file' then
      local extension = node.name:match '^.+%.(.+)$'
      if extension and vim.tbl_contains({ 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'ico' }, extension:lower()) then
        vim.fn.jobstart({ 'imv', node.absolute_path }, { detach = true })
      end
    end
  end, opts 'View image with imv')

  vim.keymap.set('n', '<C-o>', function()
    local node = api.tree.get_node_under_cursor()
    if not node then return end
    if vim.fn.has 'mac' == 1 then
      -- Finder selects the item itself when given -R
      vim.fn.jobstart({ 'open', '-R', node.absolute_path }, { detach = true })
      return
    end
    local dir = node.type == 'directory' and node.absolute_path or vim.fn.fnamemodify(node.absolute_path, ':h')
    vim.fn.jobstart({ 'xdg-open', dir }, { detach = true })
  end, opts 'Reveal in system file manager')
end

local FIXED_WIDTH = 40
local adaptive_mode = false

local function apply_setup()
  require('nvim-tree').setup {
    on_attach = on_attach,
    disable_netrw = true,
    -- The built-in directory hijack creates a blank buffer under vim.pack's opt
    -- loading on Neovim 0.12; we open the tree ourselves on VimEnter instead.
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

-- When Neovim opens on a directory (e.g. `nvim .`), set it as cwd and open the tree.
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function(data)
    if vim.fn.isdirectory(data.file) ~= 1 then return end
    vim.cmd.cd(data.file)
    local api = require 'nvim-tree.api'
    vim.schedule(function()
      api.tree.open()
      if vim.api.nvim_buf_is_valid(data.buf) then
        pcall(vim.api.nvim_buf_delete, data.buf, { force = true })
      end
    end)
  end,
})

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
-- Focus the tree (opening if needed) from the editor, close it when already inside it.
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
