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

echo "=== Installing Python ==="
if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
    sudo dnf install -y python3.12 python3.12-pip
elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y python3.12 python3.12-pip
elif [ -f /etc/debian_version ]; then
    sudo apt-get install -y python3 python3-pip
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install python@3.12
fi

echo "=== Installing Node.js ==="
if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
    sudo dnf install -y nodejs npm
elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y nodejs npm
elif [ -f /etc/debian_version ]; then
    sudo apt-get install -y nodejs npm
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install node
fi

echo "=== Installing dotfiles ==="
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.tmux.conf -o ~/.tmux.conf
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.bash_aliases -o ~/.bash_aliases
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.zsh_aliases -o ~/.zsh_aliases
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.inputrc -o ~/.inputrc

echo "=== Wiring up shell startup ==="
# The aliases files (incl. the prompt) are inert unless the shell's startup
# file sources them. Detect the login shell and wire up the matching one.
case "$(basename "${SHELL:-bash}")" in
    zsh)
        RC="$HOME/.zshrc"
        LINE='[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases'
        ;;
    *)
        RC="$HOME/.bashrc"
        LINE='[ -f ~/.bash_aliases ] && source ~/.bash_aliases'
        # Login shells (e.g. SSH) read ~/.bash_profile, not ~/.bashrc — chain them.
        PROFILE="$HOME/.bash_profile"
        touch "$PROFILE"
        grep -qF '.bashrc' "$PROFILE" 2>/dev/null \
            || echo '[ -f ~/.bashrc ] && source ~/.bashrc' >> "$PROFILE"
        ;;
esac
touch "$RC"
grep -qF "$LINE" "$RC" 2>/dev/null || echo "$LINE" >> "$RC"
echo "Wired aliases into $RC (restart your shell or: source $RC)"

echo "=== Installing Claude Code ==="
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"

echo "=== Installing Codex ==="
npm install -g @openai/codex --prefix "$HOME/.local"

echo "=== Installing cswap (claude-swap) ==="
# Multi-account switcher for Claude Code; on PyPI, installed via uv.
if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
uv tool install claude-swap

echo "=== Setting up Claude Code hooks ==="
mkdir -p ~/.claude
if [ -f ~/.claude/settings.json ]; then
    # Merge hooks into existing settings using python
    python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f: s = json.load(f)
s.setdefault('hooks', {})['Notification'] = [{'matcher': 'idle_prompt', 'hooks': [{'type': 'command', 'command': \"printf '\\\\a'\"}]}]
with open(path, 'w') as f: json.dump(s, f, indent=2)
print('Updated', path)
" ~/.claude/settings.json
else
    cat > ~/.claude/settings.json << 'SETTINGS'
{
  "hooks": {
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "printf '\\a'"
          }
        ]
      }
    ]
  }
}
SETTINGS
    echo "Created ~/.claude/settings.json"
fi

echo "=== Installing /babysit-pr skill ==="
mkdir -p ~/.claude/skills/babysit-pr
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/skills/babysit-pr/SKILL.md -o ~/.claude/skills/babysit-pr/SKILL.md

echo "=== Setting up SSH key ==="
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    echo "Public key:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "SSH key already exists, skipping."
fi

echo "=== Done! Run: claude auth login && codex login ==="
