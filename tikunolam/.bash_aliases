export PAGER="less -R"
export EDITOR="vim"
  
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL="ignoredups"
shopt -s histappend

export CLICOLOR=1
export LSCOLORS="Exgxcxdxcxegedabagacad"

alias less="less -R"

alias jq="jq -C"
function jctl () { cat $1 | jq | less ; }
function mem() { ps -eo rss,pid,euser,args:100 --sort %mem | grep -v grep | grep -i $@ | awk '{printf $1/1024 "MB"; $1=""; print }'; }

