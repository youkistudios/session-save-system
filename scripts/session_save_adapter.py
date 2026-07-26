#!/usr/bin/env python3
"""Thin installed launcher for the one canonical Session Save kernel."""
from __future__ import annotations

import os
import sys
from pathlib import Path


def kernel_path() -> Path:
    override = os.environ.get("SESSION_SAVE_KERNEL")
    if override:
        return Path(override).expanduser()
    library = os.environ.get("SESSION_SAVE_LIB_DIR")
    root = Path(library).expanduser() if library else Path.home() / ".local" / "share" / "session-save"
    return root / "session_save.py"


def main() -> int:
    kernel = kernel_path()
    if kernel.is_symlink() or not kernel.is_file():
        print(
            f"Session Save canonical kernel is missing or unsafe: {kernel}\n"
            "Re-run the Session Save installer or set SESSION_SAVE_KERNEL explicitly.",
            file=sys.stderr,
        )
        return 2
    os.execv(sys.executable, [sys.executable, str(kernel), *sys.argv[1:]])
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
