-- Code companion: a short hint about what just changed (on save) or about the
-- current uncommitted work (when switched on). Hints show in a small
-- auto-dismissing float; opt-in (off by default) and debounced per buffer.
-- For a back-and-forth chat instead, see core.companion_chat.

local enabled = false
local debounce_ms = 8000
local last_run = {}
local in_flight = {}

local repos = vim.env.REPOS_HOME or vim.fn.expand '~/Development/repos'
local script = repos .. '/dotfiles/scripts/ai/code-companion.sh'

-- nvim launched from a GUI (sway) can inherit a stunted PATH that misses the
-- per-user Nix profile where claude lives, so spawned scripts can't find it.
-- Prepend the likely locations so the script always resolves claude + git.
local function build_path()
  local dirs = {}
  local claude = vim.fn.exepath 'claude'
  if claude ~= '' then dirs[#dirs + 1] = vim.fn.fnamemodify(claude, ':h') end
  for _, d in ipairs {
    vim.fn.expand '~/.nix-profile/bin',
    '/etc/profiles/per-user/' .. (vim.env.USER or '') .. '/bin',
    '/run/current-system/sw/bin',
  } do
    if vim.fn.isdirectory(d) == 1 then dirs[#dirs + 1] = d end
  end
  dirs[#dirs + 1] = vim.env.PATH or ''
  return table.concat(dirs, ':')
end
local tool_path = build_path()

local function now()
  return (vim.uv or vim.loop).now()
end

-- Small auto-dismissing float in the bottom-right corner — a tidier home for
-- hints than the message line.
local function notify_float(text, title)
  local lines = vim.split(text, '\n', { plain = true, trimempty = true })
  if #lines == 0 then return end

  title = ' 💡 ' .. title .. ' '
  local width = vim.fn.strdisplaywidth(title)
  for i, line in ipairs(lines) do
    lines[i] = '  ' .. line
    width = math.max(width, vim.fn.strdisplaywidth(lines[i]) + 1)
  end
  width = math.min(math.max(width, 28), 64)

  local height = 0
  for _, line in ipairs(lines) do
    height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    anchor = 'SE',
    row = vim.o.lines - vim.o.cmdheight - 1,
    col = vim.o.columns,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
    focusable = false,
    noautocmd = true,
  })
  vim.wo[win].wrap = true
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:DiagnosticInfo,FloatTitle:DiagnosticInfo'

  -- Give longer notes more reading time; cap so it never overstays.
  local dismiss_ms = math.min(14000 + height * 3500, 32000)
  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(dismiss_ms, 0, vim.schedule_wrap(function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    timer:close()
  end))
end

-- Run the companion script on a target (a file on save, or a directory for the
-- project scan). key guards against overlapping runs; title labels the notice.
-- verbose makes it report completion even when there's no hint — used for the
-- explicit project scan so it never looks stuck.
local function run(key, target, title, verbose)
  if in_flight[key] then return end
  in_flight[key] = true
  local ok, err = pcall(vim.system, { script, target }, { text = true, env = { PATH = tool_path } }, function(res)
    in_flight[key] = false
    vim.schedule(function()
      local hint = vim.trim(res.stdout or '')
      if hint ~= '' then
        notify_float(hint, title)
      elseif verbose then
        if res.code ~= 0 then
          local detail = vim.trim(res.stderr or '')
          if detail == '' then detail = 'exit ' .. tostring(res.code) end
          vim.notify('Companion: scan failed — ' .. detail, vim.log.levels.WARN)
        else
          vim.notify('Companion: nothing to flag', vim.log.levels.INFO)
        end
      end
    end)
  end)
  if not ok then
    in_flight[key] = false
    vim.notify('Companion: could not start — ' .. tostring(err), vim.log.levels.ERROR)
  end
end

local function on_save(ev)
  if not enabled then return end
  -- Only real, on-disk buffers.
  if vim.bo[ev.buf].buftype ~= '' then return end
  local file = vim.api.nvim_buf_get_name(ev.buf)
  if file == '' then return end

  local prev = last_run[ev.buf]
  local t = now()
  if prev and (t - prev) < debounce_ms then return end
  last_run[ev.buf] = t

  run('buf:' .. ev.buf, file, 'Companion')
end

-- One-shot look at the project's current uncommitted work, fired on enable.
local function scan_project()
  vim.notify('Code companion: scanning project…', vim.log.levels.INFO)
  run('project', vim.fn.getcwd(), 'Companion · project', true)
end

vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('code-companion', { clear = true }),
  callback = on_save,
})

local function toggle()
  enabled = not enabled
  vim.notify('AI companion ' .. (enabled and 'enabled' or 'disabled'), vim.log.levels.INFO)
  if enabled then scan_project() end
end

vim.api.nvim_create_user_command('CompanionToggle', toggle, { desc = 'Toggle the code companion hints' })
vim.keymap.set('n', '<leader>ta', toggle, { desc = '[T]oggle [A]I companion' })
