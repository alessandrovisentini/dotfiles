-- Companion chat: an on-demand back-and-forth with Claude in a side panel,
-- backed by one long-lived `claude` streaming session (stdin/stdout JSON).
-- Opened only when you ask for it (:CompanionChat / <leader>tC); the reactive
-- on-save hints live in core.companion. Read-only — it can read the project to
-- answer questions but can't edit files.

local M = {}

local cfg = {
  model = 'claude-sonnet-4-6',
  width = 72,
  input_height = 4,
}

local persona = table.concat({
  'You are a friendly senior developer pair-programming with a teammate inside their editor.',
  'Talk like a colleague: warm, casual, and direct. Keep replies short unless asked for more.',
  'This renders as plain text, so no markdown headers or code fences.',
}, ' ')

-- nvim launched from a GUI (sway) can inherit a stunted PATH that misses the
-- per-user Nix profile where claude lives. Prepend the likely locations.
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

local job -- channel id of the running claude process, or nil
local pending = '' -- incomplete trailing stdout line between chunks
local transcript_buf, transcript_win
local input_buf, input_win

local function append(lines)
  if not (transcript_buf and vim.api.nvim_buf_is_valid(transcript_buf)) then return end
  vim.bo[transcript_buf].modifiable = true
  vim.api.nvim_buf_set_lines(transcript_buf, -1, -1, false, lines)
  vim.bo[transcript_buf].modifiable = false
  if transcript_win and vim.api.nvim_win_is_valid(transcript_win) then
    vim.api.nvim_win_set_cursor(transcript_win, { vim.api.nvim_buf_line_count(transcript_buf), 0 })
  end
end

local function handle_event(ev)
  if ev.type == 'assistant' and ev.message and ev.message.content then
    local parts = {}
    for _, block in ipairs(ev.message.content) do
      if block.type == 'text' and block.text and block.text ~= '' then
        parts[#parts + 1] = block.text
      elseif block.type == 'tool_use' then
        parts[#parts + 1] = '· (looking at ' .. (block.name or 'the code') .. '…)'
      end
    end
    if #parts > 0 then
      local out = vim.split(table.concat(parts, '\n'), '\n', { plain = true })
      out[#out + 1] = ''
      append(out)
    end
  elseif ev.type == 'result' and ev.is_error then
    append { '[companion: ' .. (ev.result or 'error') .. ']', '' }
  end
end

-- stdout arrives in arbitrary chunks; reassemble newline-delimited JSON.
local function on_stdout(_, data)
  if not data then return end
  for i, chunk in ipairs(data) do
    if i == 1 then
      pending = pending .. chunk
    else
      local line = vim.trim(pending)
      if line ~= '' then
        local ok, ev = pcall(vim.json.decode, line)
        if ok and type(ev) == 'table' then vim.schedule(function() handle_event(ev) end) end
      end
      pending = chunk
    end
  end
end

local function on_stderr(_, data)
  for _, line in ipairs(data or {}) do
    line = vim.trim(line)
    if line ~= '' then vim.schedule(function() append { '[!] ' .. line } end) end
  end
end

local function send(text)
  if not job then return end
  append { '❯ ' .. text, '' }
  vim.fn.chansend(job, vim.json.encode { type = 'user', message = { role = 'user', content = text } } .. '\n')
end

local function start_job()
  if job then return true end
  pending = ''
  local cmd = {
    'claude', '--print', '--verbose',
    '--input-format', 'stream-json',
    '--output-format', 'stream-json',
    '--replay-user-messages',
    '--model', cfg.model,
    '--append-system-prompt', persona,
    '--allowed-tools', 'Read', 'Grep', 'Glob',
    '--disallowed-tools', 'Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'Bash',
  }
  job = vim.fn.jobstart(cmd, {
    cwd = vim.fn.getcwd(),
    -- Keep this nested session's Stop/Notification hooks from firing desktop
    -- notifications on every turn.
    env = { CLAUDE_NO_NOTIFY = '1', PATH = tool_path },
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = function(_, code)
      job = nil
      vim.schedule(function() append { '', '[companion session ended (' .. code .. ')]' } end)
    end,
  })
  if job <= 0 then
    job = nil
    vim.notify('Companion chat: failed to start claude (on PATH?)', vim.log.levels.ERROR)
    return false
  end
  return true
end

local function stop_job()
  if job then
    vim.fn.jobstop(job)
    job = nil
  end
end

local function ensure_buffers()
  if not (transcript_buf and vim.api.nvim_buf_is_valid(transcript_buf)) then
    transcript_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[transcript_buf].buftype = 'nofile'
    vim.bo[transcript_buf].bufhidden = 'hide'
    vim.bo[transcript_buf].filetype = 'markdown'
    vim.bo[transcript_buf].modifiable = false
    append { '💬 Companion chat — ask me anything about this project.', 'Type below, Enter to send.', '' }
  end
  if not (input_buf and vim.api.nvim_buf_is_valid(input_buf)) then
    input_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[input_buf].buftype = 'nofile'
    vim.bo[input_buf].bufhidden = 'hide'
    local function submit()
      local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), '\n'))
      if text == '' then return end
      vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { '' })
      if input_win and vim.api.nvim_win_is_valid(input_win) then
        vim.api.nvim_win_set_cursor(input_win, { 1, 0 })
      end
      send(text)
    end
    vim.keymap.set({ 'n', 'i' }, '<CR>', submit, { buffer = input_buf, desc = 'Companion: send message' })
  end
end

local function is_open()
  return transcript_win and vim.api.nvim_win_is_valid(transcript_win)
end

local function open_panel()
  ensure_buffers()
  vim.cmd 'botright vsplit'
  transcript_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(transcript_win, transcript_buf)
  vim.api.nvim_win_set_width(transcript_win, cfg.width)
  vim.wo[transcript_win].number = false
  vim.wo[transcript_win].relativenumber = false
  vim.wo[transcript_win].wrap = true
  vim.wo[transcript_win].winfixwidth = true
  vim.wo[transcript_win].winbar = '💬 Companion'

  vim.cmd 'belowright split'
  input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input_win, input_buf)
  vim.api.nvim_win_set_height(input_win, cfg.input_height)
  vim.wo[input_win].number = false
  vim.wo[input_win].relativenumber = false
  vim.wo[input_win].winfixheight = true
  vim.wo[input_win].winbar = '❯ message — Enter to send'

  vim.api.nvim_set_current_win(input_win)
  vim.cmd 'startinsert'
end

local function close_panel()
  if input_win and vim.api.nvim_win_is_valid(input_win) then vim.api.nvim_win_close(input_win, true) end
  if transcript_win and vim.api.nvim_win_is_valid(transcript_win) then vim.api.nvim_win_close(transcript_win, true) end
  input_win, transcript_win = nil, nil
end

function M.open()
  if not start_job() then return end
  if not is_open() then open_panel() end
end

function M.close()
  close_panel()
end

function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

function M.stop()
  close_panel()
  stop_job()
  vim.notify('Companion chat: session stopped', vim.log.levels.INFO)
end

-- Ask a one-off question without using the input box (also handy for testing).
function M.ask(text)
  if not start_job() then return end
  if not is_open() then open_panel() end
  send(text)
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('companion-chat-exit', { clear = true }),
  callback = stop_job,
})

vim.api.nvim_create_user_command('CompanionChat', M.toggle, { desc = 'Toggle the companion chat panel' })
vim.api.nvim_create_user_command('CompanionChatStop', M.stop, { desc = 'Stop the companion chat session' })
vim.api.nvim_create_user_command('CompanionChatAsk', function(o) M.ask(o.args) end, { nargs = '+', desc = 'Ask the companion chat' })
vim.keymap.set('n', '<leader>tC', M.toggle, { desc = '[T]oggle companion [C]hat' })

return M
