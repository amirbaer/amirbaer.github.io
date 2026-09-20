#!/bin/bash
set -e

# This script is idempotent: every component is checked and skipped when it is
# already present. Components that are meant to track upstream (dotfiles,
# Claude Code, Codex, cswap) are refreshed/upgraded in place instead of skipped.

# Tools installed here land in ~/.local/bin — put it on PATH up front so the
# "already installed?" checks can see binaries from a previous run.
export PATH="$HOME/.local/bin:$PATH"

have() { command -v "$1" >/dev/null 2>&1; }

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

# Detect the package manager once (Amazon Linux and RHEL both use dnf).
if [ -f /etc/system-release ] && grep -qi "amazon" /etc/system-release; then
    PLATFORM=dnf
elif [ -f /etc/redhat-release ]; then
    PLATFORM=dnf
elif [ -f /etc/debian_version ]; then
    PLATFORM=apt
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM=brew
else
    PLATFORM=""
fi

# pkg_install <pkg>... — install via the platform's package manager. The apt
# index refresh and the brew source-build check each run at most once, and only
# when something actually needs installing.
APT_UPDATED=""
BREW_CHECKED=""
pkg_install() {
    case "$PLATFORM" in
        dnf)
            sudo dnf install -y "$@"
            ;;
        apt)
            if [ -z "$APT_UPDATED" ]; then
                sudo apt-get update
                APT_UPDATED=1
            fi
            sudo apt-get install -y "$@"
            ;;
        brew)
            if [ -z "$BREW_CHECKED" ]; then
                check_brew_source_build_risk
                BREW_CHECKED=1
            fi
            brew install "$@"
            ;;
    esac
}

echo "=== Installing tools ==="
missing=()
for tool in git vim tmux; do
    have "$tool" || missing+=("$tool")
done
if [ ${#missing[@]} -eq 0 ]; then
    echo "git, vim, tmux already installed — skipping"
else
    pkg_install "${missing[@]}"
fi

echo "=== Installing Python ==="
case "$PLATFORM" in
    dnf)
        if have python3.12; then
            echo "python3.12 already installed — skipping"
        else
            pkg_install python3.12 python3.12-pip
        fi
        ;;
    apt)
        if have python3 && have pip3; then
            echo "python3 + pip3 already installed — skipping"
        else
            pkg_install python3 python3-pip
        fi
        ;;
    brew)
        if have python3; then
            echo "python3 already installed — skipping"
        else
            pkg_install python@3.12
        fi
        ;;
esac

echo "=== Installing Node.js ==="
if have node && have npm; then
    echo "node + npm already installed — skipping"
elif [ "$PLATFORM" = brew ]; then
    pkg_install node
else
    pkg_install nodejs npm
fi

echo "=== Installing dotfiles ==="
# Always re-downloaded: overwriting with the latest copy IS the update path,
# and re-running converges on the same state.
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.tmux.conf -o ~/.tmux.conf
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.bash_aliases -o ~/.bash_aliases
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.zsh_aliases -o ~/.zsh_aliases
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/.inputrc -o ~/.inputrc

echo "=== Installing tmux session persistence (tpm + resurrect + continuum) ==="
# tmux sessions do not survive a reboot on their own. resurrect saves/restores
# them; continuum's auto-restore is off in .tmux.conf because `tmux-start` in
# the aliases runs the restore itself after a reboot (config lives in .tmux.conf
# as @plugin lines, loaded by TPM at tmux startup). Cloned directly rather than
# via TPM's installer so this works with no tmux server running (e.g. a fresh
# box); re-running updates each plugin in place.
for repo in tmux-plugins/tpm tmux-plugins/tmux-resurrect tmux-plugins/tmux-continuum; do
    dest="$HOME/.tmux/plugins/$(basename "$repo")"
    if [ -d "$dest/.git" ]; then
        # Discard local edits (like the `set -x` silencing below) so the pull
        # can't fail on a dirty tree — plugins are meant to track upstream.
        git -C "$dest" checkout --quiet -- . 2>/dev/null || true
        git -C "$dest" pull --ff-only --quiet || echo "  (could not update $repo — leaving as-is)"
    else
        mkdir -p "$(dirname "$dest")"
        git clone --depth 1 --quiet "https://github.com/$repo.git" "$dest"
    fi
done

# Upstream tmux-continuum ships a stray `set -x` in continuum.tmux (debug
# leftover committed to their master) that spews shell trace to stderr every
# time the plugin loads. Comment it out; the checkout above undoes this before
# each pull, so it is reapplied here on every run.
CONTINUUM="$HOME/.tmux/plugins/tmux-continuum/continuum.tmux"
if grep -q '^set -x$' "$CONTINUUM" 2>/dev/null; then
    sed 's/^set -x$/# set -x  # silenced by tikunolam install.sh/' "$CONTINUUM" > "$CONTINUUM.tmp" \
        && mv "$CONTINUUM.tmp" "$CONTINUUM"
fi
# The mv above replaces the file with a non-executable temp copy. TPM executes
# it, so without +x TPM exits 126 and continuum never loads: no auto-restore on
# the next server start, and the status-bar auto-save silently gone too.
chmod +x "$CONTINUUM"

# continuum's auto-save is a decoy for detached servers: it rides on status-bar
# redraws, which only happen while a client is attached, so a server nobody is
# attached to is NEVER auto-saved (and continuum stamps a fake "last save"
# timestamp on first load, hiding the gap). tmux-autosave is a save loop that
# .tmux.conf starts with the server; it saves via tmux-resurrect on a timer
# regardless of attached clients. Always re-downloaded (tracks upstream).
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/tmux-autosave -o ~/.local/bin/tmux-autosave
chmod +x ~/.local/bin/tmux-autosave

# Stock resurrect saves a pane's foreground command as typed, so a Claude Code
# pane comes back as a fresh "claude" instead of the session it was running.
# claude_session.sh is a resurrect save-command strategy that records
# "claude --resume <sessionId>" instead (selected in .tmux.conf). resurrect looks
# strategies up by name inside its plugin directory only; the file is untracked
# there, so the pull above leaves it alone, but a fresh box needs it downloaded.
STRATEGIES="$HOME/.tmux/plugins/tmux-resurrect/save_command_strategies"
mkdir -p "$STRATEGIES"
curl -fsSL https://raw.githubusercontent.com/amirbaer/amirbaer.github.io/master/tikunolam/claude_session.sh \
    -o "$STRATEGIES/claude_session.sh"
chmod +x "$STRATEGIES/claude_session.sh"

# Retrofit a server that is already running (it loaded the old config, so it
# has no autosave loop): reload the config so the snapshot below uses the current
# plugin options, start the loop in it and snapshot the sessions now.
# No-ops when no server is running; the loop itself guards against duplicates.
if tmux has-session 2>/dev/null; then
    tmux source-file ~/.tmux.conf 2>/dev/null || true
    tmux run-shell -b "$HOME/.local/bin/tmux-autosave" 2>/dev/null || true
    if "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" quiet >/dev/null 2>&1; then
        echo "Saved a snapshot of the currently running tmux sessions"
    fi
fi

echo "=== Installing pichefkes tools (claude-sessions, workls) ==="
# Both live in the separate public repo amirbaer/pichefkes, not this one.
# Always re-downloaded so re-running the script picks up upstream changes.
mkdir -p ~/.local/bin ~/.local/share
# claude-sessions: standalone stdlib-only Python CLI to list/resume sessions.
curl -fsSL https://raw.githubusercontent.com/amirbaer/pichefkes/master/claude/claude-sessions.py -o ~/.local/bin/claude-sessions
chmod +x ~/.local/bin/claude-sessions
# workclone.sh: shell functions (workls/workcd/workclone). It must run inside
# the interactive shell (it cd's), so it is sourced from the rc below rather
# than placed on PATH. The .zsh_aliases/.bash_aliases put ~/.local/bin on PATH.
curl -fsSL https://raw.githubusercontent.com/amirbaer/pichefkes/master/workclone/workclone.sh -o ~/.local/share/workclone.sh

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
if grep -qF "$LINE" "$RC" 2>/dev/null; then
    echo "Aliases already wired into $RC"
else
    echo "$LINE" >> "$RC"
    echo "Wired aliases into $RC (restart your shell or: source $RC)"
fi

# workclone.sh refuses to load unless WORKCLONE_ORG and WORKCLONE_DIR are set,
# so those exports are written into the rc before the source line. The org has
# no sensible default, so prompt for it (honoring a pre-set $WORKCLONE_ORG and
# skipping when there's no terminal); the clones dir defaults to ~/work.
WORKCLONE_SRC='source ~/.local/share/workclone.sh'
if grep -qF "$WORKCLONE_SRC" "$RC" 2>/dev/null; then
    echo "workclone already wired into $RC"
else
    WC_ORG="${WORKCLONE_ORG:-}"
    if [ -z "$WC_ORG" ] && [ -e /dev/tty ]; then
        read -r -p "workclone: default GitHub org for 'workclone <repo>' (blank to skip): " WC_ORG < /dev/tty || WC_ORG=""
    fi
    if [ -n "$WC_ORG" ]; then
        {
            echo "export WORKCLONE_ORG=\"\${WORKCLONE_ORG:-$WC_ORG}\""
            echo 'export WORKCLONE_DIR="${WORKCLONE_DIR:-$HOME/work}"'
            echo '[ -f ~/.local/share/workclone.sh ] && source ~/.local/share/workclone.sh'
        } >> "$RC"
        echo "Wired workclone (workls) into $RC (org: $WC_ORG, dir: \$HOME/work)"
    else
        echo "workclone: no org given — skipped rc wiring. Set WORKCLONE_ORG and"
        echo "WORKCLONE_DIR, then source ~/.local/share/workclone.sh manually."
    fi
fi

echo "=== Installing Claude Code ==="
if have claude; then
    echo "Claude Code already installed ($(claude --version 2>/dev/null || echo "version unknown")) — checking for updates"
    # `claude update` is a fast no-op when current; fall back to the installer
    # if it fails (e.g. for installs the updater doesn't manage).
    claude update || curl -fsSL https://claude.ai/install.sh | bash
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo "=== Installing Codex ==="
# Skip the (slow) npm install when the installed version already matches the
# latest on the registry; otherwise install/update to latest.
codex_installed="$(npm ls -g --prefix "$HOME/.local" @openai/codex --depth=0 2>/dev/null | sed -n 's/.*@openai\/codex@//p' | head -1 || true)"
codex_latest="$(npm view @openai/codex version 2>/dev/null || true)"
if [ -z "$codex_installed" ] && have codex; then
    # Installed by some other means (different npm prefix, brew, ...) — not
    # managed by this script, so leave it alone rather than double-install.
    echo "Codex already installed outside ~/.local ($(codex --version 2>/dev/null || echo "version unknown")) — skipping"
elif [ -n "$codex_installed" ] && [ "$codex_installed" = "$codex_latest" ]; then
    echo "Codex $codex_installed already up to date — skipping"
else
    if [ -n "$codex_installed" ]; then
        echo "Updating Codex $codex_installed -> ${codex_latest:-latest}"
    fi
    npm install -g @openai/codex --prefix "$HOME/.local"
fi

echo "=== Installing cswap (claude-swap) ==="
# Multi-account switcher for Claude Code; on PyPI, installed via uv.
if ! have uv; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
if uv tool list 2>/dev/null | grep -q '^claude-swap '; then
    # `uv tool upgrade` is a fast no-op when already at the latest version.
    uv tool upgrade claude-swap
else
    uv tool install claude-swap
fi

# Headless macOS: the login Keychain is unusable over SSH, so Claude Code
# stores its token in ~/.claude/.credentials.json. Stock cswap assumes the
# Keychain and finds nothing. Patch it to use the file backend when the
# Keychain is unusable (no-op on GUI Macs; reverted by `cswap --upgrade` and
# by the `uv tool upgrade` above, so it is reapplied on every run). See
# patches/claude-swap-headless-macos.py.
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
    # Merge the hook into existing settings, but only if it isn't already
    # there — don't clobber a Notification list the user has customized.
    python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f: s = json.load(f)
notifs = s.setdefault('hooks', {}).setdefault('Notification', [])
if any(isinstance(h, dict) and h.get('matcher') == 'idle_prompt' for h in notifs):
    print('idle_prompt hook already present in', path, '- skipping')
else:
    notifs.append({'matcher': 'idle_prompt', 'hooks': [{'type': 'command', 'command': \"printf '\\\\a'\"}]})
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
# Always re-downloaded so re-running the script picks up skill updates.
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
