#!/usr/bin/env python3
"""Patch the installed claude-swap (cswap) for headless macOS.

On a headless Mac (e.g. an SSH session with no GUI login) the login Keychain
is locked/unusable, so Claude Code stores its token in the file
~/.claude/.credentials.json instead. Stock cswap assumes macOS always uses the
Keychain, so it finds nothing and reports "No credentials found for current
account" (and --switch silently writes to the wrong place).

This patches the installed switcher.py to detect that situation at runtime and
route both the active credential and the per-account backups through the file
backend that Claude Code is actually using.

Properties:
  * Idempotent      - re-running is a no-op once patched.
  * Safe on GUI Macs - file mode only activates when the Keychain is unusable,
                       so a normal Mac with a working Keychain is unaffected.
  * Version-tolerant - if the expected code anchors aren't found (upstream
                       refactor), it warns and makes NO changes rather than
                       corrupting the file.
  * cswap --upgrade reverts this; re-run install.sh (or this script) to reapply.

Usage: python3 claude-swap-headless-macos.py [path/to/switcher.py]
"""
from __future__ import annotations

import ast
import os
import subprocess
import sys
import tempfile
from pathlib import Path

MARKER = "_macos_file_mode"  # presence => already patched

NEW_METHOD = '''    def _detect_macos_file_mode(self) -> bool:
        # LOCAL PATCH (headless macOS): when the login Keychain is unusable
        # (e.g. an SSH session with no GUI login) Claude Code falls back to
        # ~/.claude/.credentials.json. Detect that and route through the file
        # backend so cswap reads/writes the same place Claude Code does.
        if self.platform != Platform.MACOS:
            return False
        if not get_credentials_path().exists():
            return False
        try:
            val = macos_keychain.get_password(
                CLAUDE_CODE_KEYCHAIN_SERVICE, os.environ.get("USER", "user")
            )
        except Exception:
            val = None  # locked / denied keychain => unusable
        return not val

'''

# (anchor, replacement) — each anchor must appear exactly `count` times.
EDITS = [
    # 1. compute the flag once in __init__
    (
        "        self.platform = Platform.detect()\n",
        "        self.platform = Platform.detect()\n"
        "        self._macos_file_mode = self._detect_macos_file_mode()\n",
        1,
    ),
    # 2. insert the detector method just before _read_credentials
    (
        "    def _read_credentials(self) -> str | None:\n",
        NEW_METHOD + "    def _read_credentials(self) -> str | None:\n",
        1,
    ),
    # 3. active-credential read/write: skip Keychain when in file mode
    (
        "        if self.platform == Platform.MACOS:\n",
        "        if self.platform == Platform.MACOS and not self._macos_file_mode:\n",
        2,
    ),
    # 4. per-account backups also go to files in file mode
    (
        "        return self.platform in (Platform.LINUX, Platform.WSL, Platform.WINDOWS)\n",
        "        return self.platform in (Platform.LINUX, Platform.WSL, Platform.WINDOWS) or self._macos_file_mode\n",
        1,
    ),
]


def find_switcher() -> Path | None:
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).expanduser()
    bases: list[Path] = []
    try:
        out = subprocess.run(
            ["uv", "tool", "dir"], capture_output=True, text=True, timeout=10
        )
        if out.returncode == 0 and out.stdout.strip():
            bases.append(Path(out.stdout.strip()))
    except Exception:
        pass
    if os.environ.get("XDG_DATA_HOME"):
        bases.append(Path(os.environ["XDG_DATA_HOME"]) / "uv" / "tools")
    bases.append(Path.home() / ".local" / "share" / "uv" / "tools")
    seen = set()
    for base in bases:
        if base in seen:
            continue
        seen.add(base)
        hits = sorted(
            (base / "claude-swap").glob(
                "lib/python*/site-packages/claude_swap/switcher.py"
            )
        )
        if hits:
            return hits[0]
    return None


def main() -> int:
    path = find_switcher()
    if path is None or not path.exists():
        print("cswap headless patch: switcher.py not found; skipping.")
        return 0

    src = path.read_text(encoding="utf-8")

    if MARKER in src:
        print(f"cswap headless patch: already applied ({path}).")
        return 0

    # Verify every anchor is present the expected number of times BEFORE editing.
    for anchor, _repl, count in EDITS:
        found = src.count(anchor)
        if found != count:
            print(
                "cswap headless patch: code shape changed "
                f"(anchor x{found}, expected x{count}); making no changes.\n"
                "  This claude-swap version may not need the patch, or it needs "
                "updating. Report the headless-macOS file-vs-Keychain issue "
                "upstream."
            )
            return 0

    patched = src
    for anchor, repl, _count in EDITS:
        patched = patched.replace(anchor, repl)

    # Don't write anything that doesn't parse.
    try:
        ast.parse(patched)
    except SyntaxError as e:
        print(f"cswap headless patch: result failed to parse ({e}); aborting.")
        return 0

    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        os.write(fd, patched.encode("utf-8"))
        os.close(fd)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

    print(f"cswap headless patch: applied to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
