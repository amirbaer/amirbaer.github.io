#!/bin/bash
set -e

echo "=== Installing tools ==="
if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
    sudo dnf install -y git vim tmux
elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y git vim tmux
elif [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y git vim tmux
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install git vim tmux
fi

echo "=== Installing Node.js ==="
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs npm
    elif [ -f /etc/redhat-release ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    elif [ -f /etc/debian_version ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
        sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    fi
    hash -r
fi

echo "=== Installing dotfiles ==="
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.tmux.conf -o ~/.tmux.conf

echo "=== Installing Claude Code ==="
sudo /usr/bin/env npm install -g @anthropic-ai/claude-code

echo "=== Setting up SSH key ==="
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    echo "Public key:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "SSH key already exists, skipping."
fi

echo "=== Done! Run: claude auth login ==="
