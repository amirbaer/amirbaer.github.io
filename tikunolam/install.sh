#!/bin/bash
set -e

# macOS: Homebrew silently falls back to compiling packages from SOURCE when the
# Command Line Tools are outdated (or the macOS version is unsupported). That
# turns `brew install vim` into a multi-hour LLVM build with almost no output, so
# the script looks frozen/stuck. Detect it up front and stop with a clear
# message instead. Set ALLOW_SOURCE_BUILDS=1 to skip this check and proceed.
check_brew_source_build_risk() {
    [ -n "$ALLOW_SOURCE_BUILDS" ] && return 0
    command -v brew >/dev/null 2>&1 || return 0

    local doctor_out
    doctor_out="$(brew doctor 2>&1 || true)"
    echo "$doctor_out" | grep -qiE "command line tools|do not provide support|pre-release" || return 0

    echo ""
    echo "⚠️  WARNING: Homebrew is likely to build packages from SOURCE on this Mac."
    echo "   Cause: outdated Command Line Tools (or an unsupported macOS version)."
    echo "   Effect: 'brew install vim' compiles LLVM from source — often 1-3 HOURS,"
    echo "           with almost no output, so it looks like the script is stuck."
    echo ""
    echo "   Recommended fix, then re-run this script:"
    echo "     sudo rm -rf /Library/Developer/CommandLineTools"
    echo "     sudo xcode-select --install"
    echo ""
    echo "   (To proceed anyway and accept the slow build: ALLOW_SOURCE_BUILDS=1 $0)"
    echo ""

    local reply=""
    if [ -e /dev/tty ]; then
        read -r -p "   Continue with source builds anyway? [y/N] " reply < /dev/tty || reply=""
    fi
    case "$reply" in
        [yY] | [yY][eE][sS]) echo "   Continuing — this may take a long time..." ;;
        *) echo "   Aborting. Update the Command Line Tools and re-run."; exit 1 ;;
    esac
}

echo "=== Installing tools ==="
if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
    sudo dnf install -y git vim tmux
elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y git vim tmux
elif [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y git vim tmux
elif [[ "$OSTYPE" == "darwin"* ]]; then
    check_brew_source_build_risk
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

# Headless macOS: the login Keychain is unusable over SSH, so Claude Code
# stores its token in ~/.claude/.credentials.json. Stock cswap assumes the
# Keychain and finds nothing. Patch it to use the file backend when the
# Keychain is unusable (no-op on GUI Macs; reverted by `cswap --upgrade`, so
# re-run install.sh after upgrading). See patches/claude-swap-headless-macos.py.
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "=== Patching cswap for headless macOS ==="
    if curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/patches/claude-swap-headless-macos.py -o /tmp/cswap-headless-patch.py; then
        python3 /tmp/cswap-headless-patch.py || echo "WARNING: cswap headless patch could not be applied"
    else
        echo "WARNING: could not download cswap headless patch"
    fi
fi

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
