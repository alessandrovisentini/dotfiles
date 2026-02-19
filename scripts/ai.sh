#!/usr/bin/env bash

AI_CMD="claude"
MULTI=false

while getopts "m" opt; do
    case $opt in
        m) MULTI=true ;;
    esac
done
shift $((OPTIND - 1))

if [ "$MULTI" = false ]; then
    $AI_CMD "$@"
    exit $?
fi

BASE_PATH="$REPOS_HOME"

if [ -z "$BASE_PATH" ]; then
    echo "Error: REPOS_HOME is not set."
    exit 1
fi

# Detect if we're inside a repo
CURRENT_REPO=""
if [[ "$PWD" == "$BASE_PATH"/* ]]; then
    CURRENT_REPO=$(echo "$PWD" | sed "s|^$BASE_PATH/||" | cut -d'/' -f1)
fi

REPOS=$(ls "$BASE_PATH")

FZF_OPTS=(--multi --reverse --no-sort
    --header="Select repositories (SPACE to toggle, ENTER to confirm)"
    --bind "space:toggle"
)

if [ -n "$CURRENT_REPO" ]; then
    REPOS=$(printf '%s\n' "$CURRENT_REPO"; echo "$REPOS" | grep -vx "$CURRENT_REPO")
    SELECTED=$(echo "$REPOS" | fzf "${FZF_OPTS[@]}" --bind "start:select+down")
else
    SELECTED=$(echo "$REPOS" | fzf "${FZF_OPTS[@]}")
fi

if [ -z "$SELECTED" ]; then
    echo "No repositories selected."
    exit 1
fi

DIRS=()
while IFS= read -r repo; do
    DIRS+=("$BASE_PATH/$repo")
done <<< "$SELECTED"

# If inside a repo, use current directory as working dir
# Otherwise use the first selected repo
if [ -n "$CURRENT_REPO" ]; then
    WORK_DIR="$PWD"
    ADD_DIRS=()
    for dir in "${DIRS[@]}"; do
        if [ "$dir" != "$BASE_PATH/$CURRENT_REPO" ]; then
            ADD_DIRS+=(--add-dir "$dir")
        fi
    done
else
    WORK_DIR="${DIRS[0]}"
    ADD_DIRS=()
    for dir in "${DIRS[@]:1}"; do
        ADD_DIRS+=(--add-dir "$dir")
    done
fi

cd "$WORK_DIR" && $AI_CMD "${ADD_DIRS[@]}" "$@"
