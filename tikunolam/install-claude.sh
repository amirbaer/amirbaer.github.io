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

echo "=== Installing Python 3.14 ==="
if ! python3.14 --version &> /dev/null; then
    if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
        sudo dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel xz-devel tk-devel
    elif [ -f /etc/redhat-release ]; then
        sudo dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel xz-devel tk-devel
    elif [ -f /etc/debian_version ]; then
        sudo apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev liblzma-dev tk-dev
    fi
    curl -fsSL https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tgz -o /tmp/Python-3.14.3.tgz
    tar -xzf /tmp/Python-3.14.3.tgz -C /tmp
    cd /tmp/Python-3.14.3
    ./configure --enable-optimizations --prefix=/usr/local
    make -j"$(nproc)"
    sudo make altinstall
    cd -
    rm -rf /tmp/Python-3.14.3 /tmp/Python-3.14.3.tgz
fi

echo "=== Installing dotfiles ==="
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.tmux.conf -o ~/.tmux.conf
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.bash_aliases -o ~/.bash_aliases

echo "=== Installing Claude Code ==="
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"

echo "=== Setting up SSH key ==="
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    echo "Public key:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "SSH key already exists, skipping."
fi

echo "=== Done! Run: claude auth login ==="
