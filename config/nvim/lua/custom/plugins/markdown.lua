-- Markdown rendering + Obsidian vault integration.

local function setup_render_markdown()
  vim.pack.add {
    'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  }

  -- GitHub Dark palette pinned for heading backgrounds and links.
  local colors = {
    blue = '#58a6ff',
    purple = '#d2a8ff',
    red = '#ff7b72',
    bg_red = '#b62324',
    bg_blue = '#388bfd',
    bg_cyan = '#0d9488',
    bg_green = '#238636',
    bg_purple = '#8957e5',
    bg_orange = '#d29922',
    bg_dark = '#161b22',
  }

  vim.api.nvim_set_hl(0, 'RenderMarkdownH1Bg', { fg = '#ffffff', bg = colors.bg_red, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH2Bg', { fg = '#ffffff', bg = colors.bg_blue, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH3Bg', { fg = '#ffffff', bg = colors.bg_purple, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH4Bg', { fg = '#ffffff', bg = colors.bg_green, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH5Bg', { fg = '#ffffff', bg = colors.bg_orange, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownH6Bg', { fg = '#ffffff', bg = colors.bg_cyan, bold = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownLink', { fg = colors.purple, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = colors.blue, underline = true })
  vim.api.nvim_set_hl(0, '@markup.link', { fg = colors.blue, bold = true, italic = true })
  vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', { fg = colors.red, bg = colors.bg_dark })

  require('render-markdown').setup {
    enabled = true,
    render_modes = { 'n', 'c' },
    anti_conceal = { enabled = false },
    win_options = {
      conceallevel = { default = 0, rendered = 3 },
      concealcursor = { default = '', rendered = 'nc' },
    },
    heading = {
      enabled = true,
      sign = false,
      position = 'inline',
      icons = { '', '', '', '', '', '' },
      width = 'block',
      left_margin = 0,
      left_pad = 1,
      right_pad = 1,
      min_width = 0,
      backgrounds = {
        'RenderMarkdownH1Bg', 'RenderMarkdownH2Bg', 'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg', 'RenderMarkdownH5Bg', 'RenderMarkdownH6Bg',
      },
      foregrounds = {
        'RenderMarkdownH1Bg', 'RenderMarkdownH2Bg', 'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg', 'RenderMarkdownH5Bg', 'RenderMarkdownH6Bg',
      },
    },
    code = {
      enabled = true,
      sign = false,
      style = 'full',
      width = 'block',
      border = 'thin',
      left_pad = 2,
      right_pad = 2,
    },
    bullet = { enabled = true, icons = { '●', '○', '◆', '◇' } },
    checkbox = { enabled = true, unchecked = { icon = '󰄱 ' }, checked = { icon = '󰱒 ' } },
    link = {
      enabled = true,
      image = '󰥶 ',
      hyperlink = '󰌹 ',
      highlight = 'RenderMarkdownLink',
      wiki = { icon = '󰌹 ', highlight = 'RenderMarkdownLink', scope_highlight = 'RenderMarkdownLink' },
    },
  }

  vim.keymap.set('n', '<leader>mm', function() require('render-markdown').toggle() end, { desc = '[M]arkdown: Toggle [M]arkup rendering' })
end

local function load_obsidian_workspaces()
  -- TTRPG_GAMES_CONFIG points at a JSON file like {games:[{name, path}]}.
  -- TTRPG_NOTES_HOME is the vault root that each `$TTRPG_NOTES_HOME/...` path expands against.
  local games_file = os.getenv 'TTRPG_GAMES_CONFIG'
  if not games_file then return {} end

  local file = io.open(games_file, 'r')
  if not file then
    vim.notify('tt.json not found at ' .. games_file, vim.log.levels.WARN)
    return {}
  end
  local content = file:read '*a'
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data.games then
    vim.notify('Failed to parse tt.json', vim.log.levels.WARN)
    return {}
  end

  local ttrpg_root = os.getenv 'TTRPG_NOTES_HOME'
  if not ttrpg_root then
    vim.notify('TTRPG_NOTES_HOME environment variable not set', vim.log.levels.WARN)
    return {}
  end

  local workspaces = {}
  for _, game in ipairs(data.games) do
    local expanded_path = game.path:gsub('%$TTRPG_NOTES_HOME', ttrpg_root)
    table.insert(workspaces, { name = game.name, path = expanded_path })
  end
  return workspaces
end

local function setup_obsidian()
  local workspaces = load_obsidian_workspaces()
  if #workspaces == 0 then return end

  vim.pack.add { 'https://github.com/obsidian-nvim/obsidian.nvim' }

  require('obsidian').setup {
    workspaces = workspaces,
    ui = { enable = false },
    note_id_func = function(title)
      if title then return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower() end
      return tostring(os.time())
    end,
    link = { style = 'wiki' },
    picker = { name = 'telescope.nvim' },
    legacy_commands = false,
  }

  vim.keymap.set('n', '<leader>oo', '<cmd>Obsidian open<CR>', { desc = '[O]bsidian: [O]pen in app' })
  vim.keymap.set('n', '<leader>on', '<cmd>Obsidian new<CR>', { desc = '[O]bsidian: [N]ew note' })
  vim.keymap.set('n', '<leader>os', '<cmd>Obsidian quick_switch<CR>', { desc = '[O]bsidian: Quick [S]witch' })
  vim.keymap.set('n', '<leader>of', '<cmd>Obsidian search<CR>', { desc = '[O]bsidian: Search [F]ind' })
  vim.keymap.set('n', '<leader>ob', '<cmd>Obsidian backlinks<CR>', { desc = '[O]bsidian: [B]acklinks' })
  vim.keymap.set('n', '<leader>ol', '<cmd>Obsidian links<CR>', { desc = '[O]bsidian: [L]inks in note' })
  vim.keymap.set('n', '<leader>ot', '<cmd>Obsidian tags<CR>', { desc = '[O]bsidian: Search [T]ags' })
  vim.keymap.set('n', '<leader>or', '<cmd>Obsidian rename<CR>', { desc = '[O]bsidian: [R]ename note' })

  local function bind_follow_link(buf)
    vim.keymap.set('n', 'gd', '<cmd>Obsidian follow_link<CR>', { buffer = buf, desc = '[G]o to [D]efinition (follow Obsidian link)' })
    vim.keymap.set('n', '<CR>', '<cmd>Obsidian follow_link<CR>', { buffer = buf, desc = 'Follow Obsidian link' })
  end

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    group = vim.api.nvim_create_augroup('custom-obsidian-md', { clear = true }),
    callback = function(args)
      bind_follow_link(args.buf)
      vim.opt_local.spell = false
    end,
  })

  -- obsidian-ls attaches to markdown buffers, which fires the global LspAttach
  -- autocmd that rebinds gd to telescope lsp_definitions. Re-bind after attach.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('custom-obsidian-md-lsp', { clear = true }),
    callback = function(args)
      if vim.bo[args.buf].filetype == 'markdown' then bind_follow_link(args.buf) end
    end,
  })
end

setup_render_markdown()
setup_obsidian()
