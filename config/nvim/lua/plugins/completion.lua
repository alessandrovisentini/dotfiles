vim.pack.add {
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range '1.*' },
}

require('blink.cmp').setup {
  completion = {
    documentation = { auto_show = false },
    trigger = {
      -- Keep the menu open on space in markdown, note names have spaces
      show_on_blocked_trigger_characters = function()
        if vim.bo.filetype == 'markdown' then return { '\n', '\t' } end
        return { ' ', '\n', '\t' }
      end,
    },
  },
  sources = {
    default = { 'lsp', 'path' },
    providers = {
      lsp = {
        -- Like Obsidian, [[ lists notes and aliases, headings only after a #
        transform_items = function(ctx, items)
          if vim.bo[ctx.bufnr].filetype ~= 'markdown' then return items end
          local link = ctx.line:sub(1, ctx.cursor[2]):match '%[%[([^%]]*)$'
          if not link or link:find('#', 1, true) then return items end
          return vim.tbl_filter(function(item)
            local text = item.textEdit and item.textEdit.newText or item.insertText or ''
            -- Skip aliases equal to the note name, they'd insert [[Name|Name]]
            return not item.label:find('#', 1, true) and not vim.startswith(text, item.label .. '|')
          end, items)
        end,
      },
    },
  },
  fuzzy = { implementation = 'lua' },
  signature = { enabled = true },
}
