---@type (string|vim.pack.Spec)[]
local telescope_plugins = {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/nvim-telescope/telescope.nvim',
  'https://github.com/nvim-telescope/telescope-ui-select.nvim',
}
if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, 'https://github.com/nvim-telescope/telescope-fzf-native.nvim') end

vim.pack.add(telescope_plugins)

local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local previewers = require 'telescope.previewers'
local from_entry = require 'telescope.from_entry'
local conf = require('telescope.config').values

-- Obsidian wiki link substitutions so glow renders them as plain text.
local obsidian_sed_cmd = table.concat({
  's/\\[\\[\\([^]|]*\\)|\\([^]]*\\)\\]\\]/***\\2***/g',
  's/!\\[\\[\\([^]|]*\\)|\\([^]]*\\)\\]\\]/***🔗 \\2***/g',
  's/!\\[\\[\\([^]#^|]*\\)[#^][^]]*\\]\\]/***🔗 \\1***/g',
  's/!\\[\\[\\([^]]*\\)\\]\\]/***🔗 \\1***/g',
  's/\\[\\[\\([^]#^|]*\\)#\\([^]|]*\\)\\]\\]/***\\2***/g',
  's/\\[\\[\\([^]#^|]*\\)\\^\\([^]|]*\\)\\]\\]/***\\2***/g',
  's/\\[\\[\\([^]]*\\)\\]\\]/***\\1***/g',
}, '; ')

local markdown_extensions = { 'md', 'markdown', 'mkd', 'mdx' }
local image_extensions = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'ico' }

local function file_extension(path)
  local ext = path:match '^.+%.(.+)$'
  return ext and ext:lower() or nil
end

-- glow for markdown, treesitter buffer previewer for everything else.
-- Reuses the previewer's pool buffer; recreates it if a previous markdown
-- preview turned it into a terminal buffer.
local custom_file_previewer = function(opts)
  opts = opts or {}
  return previewers.new_buffer_previewer {
    title = 'File Preview',
    define_preview = function(self, entry)
      local p = from_entry.path(entry, true, false)
      if p == nil or p == '' then return end

      if vim.api.nvim_buf_is_valid(self.state.bufnr) and vim.bo[self.state.bufnr].buftype == 'terminal' then
        pcall(vim.api.nvim_buf_delete, self.state.bufnr, { force = true })
        self.state.bufnr = vim.api.nvim_create_buf(false, true)
        pcall(vim.api.nvim_win_set_buf, self.state.winid, self.state.bufnr)
      end

      local ext = file_extension(p)
      if ext and vim.tbl_contains(markdown_extensions, ext) then
        local glow_style = vim.fn.expand '~/.config/glow/github-dark.json'
        local width = vim.api.nvim_win_get_width(self.state.winid)
        local cmd = 'sed "' .. obsidian_sed_cmd .. '" ' .. vim.fn.shellescape(p) .. ' | glow -s ' .. vim.fn.shellescape(glow_style) .. ' -w ' .. width .. ' -'
        vim.api.nvim_buf_call(self.state.bufnr, function() vim.fn.termopen({ 'sh', '-c', cmd }) end)
      else
        conf.buffer_previewer_maker(p, self.state.bufnr, {
          bufname = self.state.bufname,
          winid = self.state.winid,
        })
      end
    end,
  }
end

local view_image_with_imv = function(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  if not entry then return end
  local filepath = entry.path or entry.filename or entry.value
  if not filepath then return end
  local ext = file_extension(filepath)
  if ext and vim.tbl_contains(image_extensions, ext) then
    actions.close(prompt_bufnr)
    vim.fn.jobstart({ 'imv', filepath }, { detach = true })
  end
end

-- delta for tracked git diffs, treesitter buffer previewer for untracked files.
local delta_git_previewer = previewers.new_buffer_previewer {
  title = 'Git Preview',
  define_preview = function(self, entry)
    local file = entry.value
    if not file then return end

    if vim.api.nvim_buf_is_valid(self.state.bufnr) and vim.bo[self.state.bufnr].buftype == 'terminal' then
      pcall(vim.api.nvim_buf_delete, self.state.bufnr, { force = true })
      self.state.bufnr = vim.api.nvim_create_buf(false, true)
      pcall(vim.api.nvim_win_set_buf, self.state.winid, self.state.bufnr)
    end

    local status = entry.status or ''
    if status:sub(1, 1) == '?' then
      local p = from_entry.path(entry, true, false)
      if p and p ~= '' then conf.buffer_previewer_maker(p, self.state.bufnr, { bufname = self.state.bufname, winid = self.state.winid }) end
    else
      local cmd = 'git diff HEAD -- ' .. vim.fn.shellescape(file) .. ' | delta'
      vim.api.nvim_buf_call(self.state.bufnr, function() vim.fn.termopen({ 'sh', '-c', cmd }) end)
    end
  end,
}

require('telescope').setup {
  defaults = {
    file_previewer = custom_file_previewer,
    mappings = {
      i = { ['<C-v>'] = view_image_with_imv },
      n = { ['v'] = view_image_with_imv },
    },
  },
  extensions = {
    ['ui-select'] = { require('telescope.themes').get_dropdown() },
  },
}

pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')

local builtin = require 'telescope.builtin'

-- Ignore heavy build/dependency directories in the "all files" searches.
local heavy_dir_globs = { '!**/node_modules/**', '!{target,build,dist,.next,coverage,.nuxt,vendor,__pycache__,.cache,.temp,.tmp,.git}/**' }
local heavy_dir_patterns = {
  'node_modules/.*', '%.git/.*', 'target/.*', 'build/.*', 'dist/.*', '%.next/.*',
  'coverage/.*', '%.nuxt/.*', 'vendor/.*', '__pycache__/.*', '%.cache/.*', '%.temp/.*', '%.tmp/.*',
}

vim.keymap.set('n', '<leader>gs', function() builtin.git_status { previewer = delta_git_previewer } end, { desc = '[G]it [S]tatus' })
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', function() builtin.find_files { follow = true } end, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sF', function()
  builtin.find_files { hidden = true, no_ignore = true, file_ignore_patterns = heavy_dir_patterns }
end, { desc = '[S]earch in All [F]iles (inc. gitignored)' })
vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>se', function() builtin.find_files { follow = true } end, { desc = '[S]earch [E]xplore files' })
vim.keymap.set('n', '<leader>sg', function()
  builtin.live_grep { additional_args = function() return { '--fixed-strings' } end }
end, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sG', function()
  builtin.live_grep {
    additional_args = function() return { '--fixed-strings', '--no-ignore', '--hidden' } end,
    glob_pattern = heavy_dir_globs,
  }
end, { desc = '[S]earch by [G]rep in all files (inc. gitignored)' })
vim.keymap.set('n', '<leader>sx', builtin.live_grep, { desc = '[S]earch by grep with rege[X]' })
vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
vim.keymap.set('n', '<leader>sdf', function()
  local dir = vim.fn.input('Directory: ', '', 'dir')
  if dir ~= '' then builtin.find_files { follow = true, cwd = dir } end
end, { desc = '[S]earch [D]irectory [F]iles' })
vim.keymap.set('n', '<leader>sdg', function()
  local dir = vim.fn.input('Directory: ', '', 'dir')
  if dir ~= '' then
    builtin.live_grep {
      additional_args = function() return { '--fixed-strings' } end,
      search_dirs = { dir },
    }
  end
end, { desc = '[S]earch [D]irectory [G]rep' })
vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

-- Drop the nvim 0.11+ global gr* defaults so plain `gr` fires without a timeoutlen wait.
for _, lhs in ipairs { 'grr', 'gri', 'grn', 'gra' } do
  pcall(vim.keymap.del, 'n', lhs)
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
  callback = function(event)
    local buf = event.buf
    vim.keymap.set('n', 'gr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
    vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
    vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
  end,
})

vim.keymap.set('n', '<leader>/', function()
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })

vim.keymap.set('n', '<leader>s/', function()
  builtin.live_grep {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }
end, { desc = '[S]earch [/] in Open Files' })

vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
