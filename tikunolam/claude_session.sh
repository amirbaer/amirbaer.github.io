#!/usr/bin/env bash
# tmux-resurrect save-command strategy that records which Claude Code session a pane runs.
#
# Stock resurrect saves a pane's foreground command as typed ("claude", "claude --resume",
# "claude <prompt>"), which does not identify the session, so restoring it starts a new one.
# Every running Claude Code process registers itself in ~/.claude/sessions/<pid>.json with its
# sessionId. This strategy looks the pane's claude child up there while it is still alive and
# prints "claude --resume <sessionId>", which resurrect replays verbatim on restore when
# @resurrect-processes lists "claude". Panes running anything else get the same output as the
# stock ps strategy, so their saved command is unchanged.
#
# Installed by install.sh as ~/.tmux/plugins/tmux-resurrect/save_command_strategies/claude_session.sh
# and selected in .tmux.conf with: set -g @resurrect-save-command-strategy 'claude_session'

PANE_PID="$1"
REGISTRY="$HOME/.claude/sessions"

[ -n "$PANE_PID" ] || exit 0

# Direct children of the pane's shell as "pid<TAB>args" lines. ps rather than pgrep, because macOS
# pgrep silently drops its own ancestors (a save triggered from inside a claude pane would miss that
# pane's claude). The ppid is compared exactly, because the stock ps strategy matches it as a
# prefix, so pane pid 6328 also picks up the children of pid 63281.
children() {
    ps -axo pid=,ppid=,args= |
        awk -v ppid="$PANE_PID" '$2 == ppid { pid = $1; sub(/^ *[0-9]+ +[0-9]+ +/, ""); print pid "\t" $0 }'
}

# Process start time as seconds since the epoch. macOS date parses with -j -f, GNU date with -d.
start_epoch() {
    local lstart
    lstart="$(ps -o lstart= -p "$1" | tr -s ' ' | sed 's/^ //; s/ $//')"
    [ -n "$lstart" ] || return 1
    date -j -f '%a %b %d %T %Y' "$lstart" +%s 2>/dev/null || date -d "$lstart" +%s 2>/dev/null
}

# Registry files of dead processes linger and pids get reused, so a file counts only when the
# process it names started within a minute of the file's startedAt (milliseconds since the epoch).
registry_matches_process() {
    local file="$1" pid="$2" started_ms proc_epoch diff
    started_ms="$(grep -oE '"startedAt" *: *[0-9]+' "$file" | grep -oE '[0-9]+$')"
    proc_epoch="$(start_epoch "$pid")"
    [ -n "$started_ms" ] && [ -n "$proc_epoch" ] || return 1
    diff=$(( started_ms / 1000 - proc_epoch ))
    [ "${diff#-}" -le 60 ]
}

session_id() {
    local pid="$1" file="$REGISTRY/$1.json"
    [ -f "$file" ] || return 1
    registry_matches_process "$file" "$pid" || return 1
    grep -oE '"sessionId" *: *"[0-9a-f-]{36}"' "$file" | grep -oE '[0-9a-f-]{36}'
}

main() {
    local kids pid args sid
    kids="$(children)"
    [ -n "$kids" ] || exit 0

    # The shell may have several children (background jobs); the claude one decides the command.
    while IFS=$'\t' read -r pid args; do
        case "$args" in
            claude | "claude "*)
                if sid="$(session_id "$pid")" && [ -n "$sid" ]; then
                    echo "claude --resume $sid"
                else
                    # No usable registry entry (process still starting up, or a Claude Code version
                    # without the registry): the newest conversation in the pane's directory is the
                    # best guess left.
                    echo "claude --continue"
                fi
                exit 0
                ;;
        esac
    done <<< "$kids"

    # Not a Claude Code pane: report the children's commands like the stock ps strategy does.
    cut -f2- <<< "$kids"
}
main
