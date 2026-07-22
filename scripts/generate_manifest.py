#!/usr/bin/env python3
"""Generate or verify the repository SHA-256 manifest."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "MANIFEST.sha256"
EXCLUDED_PARTS = {".git", "__pycache__"}
EXCLUDED_FILES = {"MANIFEST.sha256", ".DS_Store"}


def files() -> list[Path]:
    return sorted(
        path for path in ROOT.rglob("*")
        if path.is_file()
        and path.name not in EXCLUDED_FILES
        and not EXCLUDED_PARTS.intersection(path.relative_to(ROOT).parts)
    )


def render() -> str:
    return "\n".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}"
        for path in files()
    ) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = render()
    if args.check:
        if not MANIFEST.exists() or MANIFEST.read_text() != expected:
            print("MANIFEST.sha256 is stale; run scripts/generate_manifest.py")
            return 1
        print(f"manifest ok: {len(files())} files")
        return 0
    MANIFEST.write_text(expected)
    print(f"wrote MANIFEST.sha256: {len(files())} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
