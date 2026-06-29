#!/usr/bin/env bash

# Code companion. Two modes, picked from the argument:
#   - a FILE  → judge that file's latest change (used on save)
#   - a DIR   → quick look at the project's current uncommitted work (used when
#               the companion is switched on)
# It hands Claude a git diff (plus, for a file, the file's content) and asks for
# a short hint in a single pass — no project exploration, to stay fast. Prints
# the hint(s) to stdout, or nothing when there's nothing worth flagging, so the
# caller decides how to surface it. Best-effort and quiet on failure, so it
# never gets in the way of editing.

TARGET="${1:-}"
[ -z "$TARGET" ] && exit 0

if [ -f "$TARGET" ]; then
    MODE=file
    DIR=$(dirname -- "$TARGET")
elif [ -d "$TARGET" ]; then
    MODE=project
    DIR="$TARGET"
else
    exit 0
fi

MODEL="claude-sonnet-4-6"
MAX_DIFF_LINES=400
MAX_FILE_LINES=600

# Fail loudly when the CLI is missing (e.g. nvim launched without it on PATH)
# instead of silently producing no hint.
command -v claude >/dev/null 2>&1 || { echo "code-companion: 'claude' not found in PATH" >&2; exit 3; }

ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$ROOT" ] && exit 0
cd "$ROOT" 2>/dev/null || exit 0

if [ "$MODE" = file ]; then
    REL=${TARGET#"$ROOT"/}

    # Latest manual change = unstaged diff; fall back to staged, then to the
    # whole file when it isn't tracked yet. Nothing changed → nothing to say.
    DIFF=$(git diff -- "$REL" 2>/dev/null)
    [ -z "$DIFF" ] && DIFF=$(git diff --staged -- "$REL" 2>/dev/null)
    if [ -z "$DIFF" ] && ! git ls-files --error-unmatch -- "$REL" >/dev/null 2>&1; then
        DIFF=$(git diff --no-index -- /dev/null "$REL" 2>/dev/null)
    fi
    [ -z "$DIFF" ] && exit 0
    DIFF=$(printf '%s\n' "$DIFF" | head -n "$MAX_DIFF_LINES")
    CONTENT=$(head -n "$MAX_FILE_LINES" "$TARGET" 2>/dev/null)

    PROMPT="You're a friendly senior developer glancing over a teammate's
shoulder as they edit. Below is the file and the change they just made. If
something jumps out — a likely bug, a typo, a risky bit, or an easy win — say it
in ONE short, casual sentence, like a quick note to a teammate (aim for under
100 characters). Just the one-liner — no second sentence, no explanation dump.
If nothing's worth interrupting them for, reply with exactly: NONE
Answer only from what's provided here; don't use any tools. Plain text only —
no markdown, code fences, backticks, greetings, sign-offs, or praise filler.

File: $REL
--- content ---
$CONTENT
--- diff ---
$DIFF"
else
    # All uncommitted work vs HEAD (staged + unstaged), plus new file names.
    DIFF=$(git diff HEAD 2>/dev/null)
    [ -z "$DIFF" ] && DIFF=$(git diff 2>/dev/null)
    DIFF=$(printf '%s\n' "$DIFF" | head -n "$MAX_DIFF_LINES")
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -n 50)
    [ -z "$DIFF" ] && DIFF="(no uncommitted changes)"
    [ -z "$UNTRACKED" ] && UNTRACKED="(none)"

    PROMPT="You're a friendly senior developer a teammate just pulled in to
glance at their work in progress. Below are their current uncommitted changes
and any new files. If anything stands out — likely bugs, risky bits, or easy
wins — give up to 3 ultra-short notes, one per line, each like a quick Slack
message (aim under 90 characters each). If nothing's worth flagging, reply with
exactly: NONE
Answer only from what's provided here; don't use any tools. Plain text only —
no markdown, code fences, backticks, greetings, sign-offs, or praise filler.

Uncommitted diff:
$DIFF

Untracked files:
$UNTRACKED"
fi

# Single pass keeps it fast; tools are disallowed so it can't explore or modify
# the project. CLAUDE_NO_NOTIFY stops this nested run's own hooks from firing a
# notification; timeout bounds a slow call.
RUN=(claude --print --model "$MODEL"
    --disallowed-tools Read Grep Glob Edit Write MultiEdit NotebookEdit Bash
    -p "$PROMPT")
if command -v timeout >/dev/null 2>&1; then
    HINT=$(CLAUDE_NO_NOTIFY=1 timeout 60 "${RUN[@]}" 2>/dev/null)
else
    HINT=$(CLAUDE_NO_NOTIFY=1 "${RUN[@]}" 2>/dev/null)
fi

# Trim each line and drop blanks; suppress when the model has nothing useful.
HINT=$(printf '%s\n' "$HINT" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d')
[ -z "$HINT" ] && exit 0
case "$(printf '%s\n' "$HINT" | head -n1 | tr '[:lower:]' '[:upper:]')" in
    NONE*) exit 0 ;;
esac

printf '%s\n' "$HINT"
