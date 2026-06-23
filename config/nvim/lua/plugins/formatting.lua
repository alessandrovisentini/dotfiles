vim.pack.add { 'https://github.com/stevearc/conform.nvim' }

require('conform').setup {
  notify_on_error = false,
  format_on_save = function(bufnr)
    -- Skip languages without a canonical style.
    local disable_filetypes = { c = true, cpp = true }
    local lsp_format_opt = disable_filetypes[vim.bo[bufnr].filetype] and 'never' or 'fallback'
    return { timeout_ms = 500, lsp_format = lsp_format_opt }
  end,
  default_format_opts = {
    lsp_format = 'fallback',
  },
  formatters = {
    biome = { require_cwd = true },
    prettier = { require_cwd = true },
  },
  formatters_by_ft = {
    lua = { 'stylua' },
    javascript = { 'biome', 'prettier', stop_after_first = true },
    typescript = { 'biome', 'prettier', stop_after_first = true },
    javascriptreact = { 'biome', 'prettier', stop_after_first = true },
    typescriptreact = { 'biome', 'prettier', stop_after_first = true },
    nix = { 'alejandra' },
    dart = { 'dart_format' },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
