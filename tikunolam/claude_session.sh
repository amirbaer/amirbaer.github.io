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

# procStart from the registry, converted to what this OS reports for the live process: clock ticks
# since boot on Linux (/proc/<pid>/stat field 22), seconds since the epoch on macOS (UTC timestamp).
registry_proc_start() {
    local raw
    raw="$(grep -oE '"procStart" *: *"[^"]*"' "$1" | head -n 1 | sed -E 's/.*: *"([^"]*)"/\1/')"
    case "$raw" in
        "") return 1 ;;
        *[!0-9]*) TZ=UTC date -j -f '%a %b %d %T %Y' "$raw" +%s 2>/dev/null ;;
        *) echo "$raw" ;;
    esac
}

live_proc_start() {
    if [ -r "/proc/$1/stat" ]; then
        awk '{print $22}' "/proc/$1/stat"
    else
        start_epoch "$1"
    fi
}

# Registry files of dead processes linger and pids get reused, so a file must belong to the live
# process. procStart identifies it exactly. startedAt is only a fallback, because Claude Code can
# write it minutes after the process starts (seen: 264 s), which a tight window rejects.
registry_matches_process() {
    local file="$1" pid="$2" recorded live started_ms proc_epoch diff
    if recorded="$(registry_proc_start "$file")" && [ -n "$recorded" ] &&
        live="$(live_proc_start "$pid")" && [ -n "$live" ]; then
        [ "$recorded" = "$live" ]
        return
    fi
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
    # The file nests a second "sessionId" with the same value; one is enough.
    grep -oE '"sessionId" *: *"[0-9a-f-]{36}"' "$file" | grep -oE '[0-9a-f-]{36}' | head -n 1
}

resume_command() {
    local sid
    if sid="$(session_id "$1")" && [ -n "$sid" ]; then
        echo "claude --resume $sid"
    else
        # No usable registry entry (process still starting up, or a Claude Code version without the
        # registry): the newest conversation in the pane's directory is the best guess left.
        echo "claude --continue"
    fi
}

main() {
    local kids pid args

    # A window opened with a command (`tmux new-window 'claude ...'`) runs Claude as the pane's own
    # process, with no shell under it. Its children are then Claude's MCP servers and tool shells,
    # so looking only at children saved those instead, and the session never came back.
    case "$(ps -o args= -p "$PANE_PID")" in
        claude | "claude "*)
            resume_command "$PANE_PID"
            exit 0
            ;;
    esac

    kids="$(children)"
    [ -n "$kids" ] || exit 0

    # The shell may have several children (background jobs); the claude one decides the command.
    while IFS=$'\t' read -r pid args; do
        case "$args" in
            claude | "claude "*)
                resume_command "$pid"
                exit 0
                ;;
        esac
    done <<< "$kids"

    # Not a Claude Code pane: report the children's commands like the stock ps strategy does.
    cut -f2- <<< "$kids"
}
main
