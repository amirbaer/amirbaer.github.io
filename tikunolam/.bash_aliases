export PAGER="less -R"
export EDITOR="vim"

# Tools (claude, codex, cswap, uv) install into ~/.local/bin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL="ignoredups"
shopt -s histappend

export CLICOLOR=1
export LSCOLORS="Exgxcxdxcxegedabagacad"

__git_branch() { git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'; }
export PS1='\[\033[32m\][\[\033[00m\] \u@\h:\[\033[34m\]\w\[\033[33m\]$(__git_branch) \[\033[32m\]]\[\033[00m\] '

alias less="less -R"

alias jq="jq -C"
function jctl () { cat $1 | jq | less ; }
function jctlip () { local tmp=$(mktemp) && sed 's/\x1b\[[0-9;]*m//g' "$1" | command jq . > "$tmp" && mv "$tmp" "$1"; }
function mem() { ps -eo rss,pid,euser,args:100 --sort %mem | grep -v grep | grep -i $@ | awk '{printf $1/1024 "MB"; $1=""; print }'; }

# Start tmux and restore the last saved sessions (tmux-resurrect) if the server
# isn't already running -- e.g. after a reboot. Attaches when done.
tmux-start() {
    if tmux has-session 2>/dev/null; then
        tmux attach "$@"
        return
    fi
    local restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
    if [ ! -x "$restore" ]; then
        tmux new-session "$@"
        return
    fi
    tmux new-session -d -s _boot            # holder keeps the server alive during restore
    # run-shell, not a direct call: restore.sh derives the socket from $TMUX, which is
    # empty outside tmux, so calling it directly creates NO sessions (one "error
    # creating  (No such file or directory)" per session, then a cascade of "can't
    # find window" for every pane) and only the holder survives. run-shell runs it
    # inside the server with $TMUX set and blocks until it finishes; this is how
    # resurrect's own prefix + C-r binding invokes it.
    tmux run-shell "$restore"
    # drop the holder if real sessions came back
    if tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -qv '^_boot$'; then
        tmux kill-session -t _boot 2>/dev/null
    else
        echo "tmux-start: restore brought back no sessions; snapshots are intact in ~/.local/share/tmux/resurrect" >&2
    fi
    tmux attach "$@"
}

