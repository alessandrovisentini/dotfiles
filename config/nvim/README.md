# nvim

Personal Neovim config. Plugins are managed with the built-in `vim.pack`;
versions are pinned in `nvim-pack-lock.json`.

## Layout

```
init.lua            entry point, requires core then each plugin module
lua/core/
  options.lua       globals, vim.o options, diagnostics config
  keymaps.lua       non-plugin keymaps
  autocmds.lua      yank highlight, vim.pack build hooks
lua/plugins/        one file per plugin (or tightly related group)
```

`init.lua` loads the plugin modules in an explicit order. `debug.lua` must come
before `testing.lua` and `flutter.lua`, which build on its dap/dap-ui setup.

## Maintenance

- Update plugins: `:lua vim.pack.update()`
- Inspect pending updates offline: `:lua vim.pack.update(nil, { offline = true })`
- LSP/DAP/formatter tools: `:Mason`
