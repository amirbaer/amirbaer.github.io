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

# Restore the last saved tmux sessions (tmux-resurrect) when no server is running,
# then print what is there. The boot unit installed by install.sh already does the
# restore after a reboot, so this is now mostly a status command.
#
# Bare `tmux-start` never attaches: it used to drop you into whichever session came
# first, which read as "it opened a random session". Pass a name to attach.
tmux-start() {
    local restore="$HOME/.local/bin/tmux-restore"
    if [ ! -x "$restore" ]; then
        echo "tmux-start: $restore is missing - run install.sh" >&2
        return 1
    fi
    if [ $# -gt 0 ]; then
        "$restore" >/dev/null || return 1
        tmux attach -t "$1"
        return
    fi
    "$restore" || return 1
    echo
    tmux-status
}

