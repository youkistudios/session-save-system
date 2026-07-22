#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/session-save-tests.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

pass=0
assert_file() { [ -f "$1" ] || { echo "FAIL missing file: $1"; exit 1; }; }
assert_absent() { [ ! -e "$1" ] || { echo "FAIL expected absent: $1"; exit 1; }; }
assert_contains() { grep -F "$2" "$1" >/dev/null || { echo "FAIL '$2' not found in $1"; exit 1; }; }

case_fresh=$TEST_ROOT/fresh
mkdir -p "$case_fresh/home" "$case_fresh/config"
HOME="$case_fresh/home" CLAUDE_CONFIG_DIR="$case_fresh/config" SAVE_SYSTEM_HOME="$case_fresh/logs" "$ROOT/install.sh" >/dev/null
assert_file "$case_fresh/config/session-save-system.manifest"
assert_file "$case_fresh/config/skills/session-tag/SKILL.md"
assert_file "$case_fresh/config/commands/st.md"
assert_file "$case_fresh/logs/_INDEX.md"
[ "$(wc -l < "$case_fresh/config/session-save-system.manifest" | tr -d ' ')" = 13 ] || { echo "FAIL manifest entry count"; exit 1; }
pass=$((pass + 1)); echo "ok $pass - fresh install creates exact ownership manifest"

case_collision=$TEST_ROOT/collision
mkdir -p "$case_collision/home" "$case_collision/config/commands"
printf '%s\n' 'unrelated command' > "$case_collision/config/commands/st.md"
HOME="$case_collision/home" CLAUDE_CONFIG_DIR="$case_collision/config" SAVE_SYSTEM_HOME="$case_collision/logs" "$ROOT/install.sh" >/dev/null
assert_contains "$case_collision/config/commands/st.md" "unrelated command"
if awk -F '\t' '$2 == "commands/st.md" { found=1 } END { exit found ? 0 : 1 }' "$case_collision/config/session-save-system.manifest"; then
  echo "FAIL unrelated collision was claimed in manifest"; exit 1
fi
pass=$((pass + 1)); echo "ok $pass - unrelated collision is skipped and unclaimed"

case_backup=$TEST_ROOT/backup
mkdir -p "$case_backup/home" "$case_backup/config"
HOME="$case_backup/home" CLAUDE_CONFIG_DIR="$case_backup/config" SAVE_SYSTEM_HOME="$case_backup/logs" "$ROOT/install.sh" >/dev/null
printf '%s\n' 'local managed edit' > "$case_backup/config/commands/ss.md"
HOME="$case_backup/home" CLAUDE_CONFIG_DIR="$case_backup/config" SAVE_SYSTEM_HOME="$case_backup/logs" "$ROOT/install.sh" >/dev/null
cmp -s "$ROOT/commands/ss.md" "$case_backup/config/commands/ss.md" || { echo "FAIL managed file not refreshed"; exit 1; }
backup=$(find "$case_backup/config/session-save-system-backups" -path '*/commands/ss.md' -type f | head -1)
assert_file "$backup"
assert_contains "$backup" "local managed edit"
pass=$((pass + 1)); echo "ok $pass - managed replacement is backed up"

case_remove=$TEST_ROOT/remove
mkdir -p "$case_remove/home" "$case_remove/config"
HOME="$case_remove/home" CLAUDE_CONFIG_DIR="$case_remove/config" SAVE_SYSTEM_HOME="$case_remove/logs" "$ROOT/install.sh" >/dev/null
printf '%s\n' 'preserve this local edit' > "$case_remove/config/commands/st.md"
printf '%s\n' 'user log data' > "$case_remove/logs/keep.md"
HOME="$case_remove/home" CLAUDE_CONFIG_DIR="$case_remove/config" "$ROOT/uninstall.sh" >/dev/null
assert_file "$case_remove/config/commands/st.md"
assert_contains "$case_remove/config/commands/st.md" "preserve this local edit"
assert_absent "$case_remove/config/commands/ss.md"
assert_file "$case_remove/logs/keep.md"
assert_contains "$case_remove/config/session-save-system.manifest" "commands/st.md"
pass=$((pass + 1)); echo "ok $pass - uninstall removes exact files and preserves edits and logs"

case_legacy=$TEST_ROOT/legacy
mkdir -p "$case_legacy/home" "$case_legacy/config/commands"
printf '%s\n' 'legacy file' > "$case_legacy/config/commands/st.md"
HOME="$case_legacy/home" CLAUDE_CONFIG_DIR="$case_legacy/config" "$ROOT/uninstall.sh" >/dev/null
assert_file "$case_legacy/config/commands/st.md"
pass=$((pass + 1)); echo "ok $pass - no manifest means no deletion"

case_symlink=$TEST_ROOT/symlink
mkdir -p "$case_symlink/home" "$case_symlink/config/commands"
printf '%s\n' 'outside target' > "$case_symlink/outside.md"
ln -s "$case_symlink/outside.md" "$case_symlink/config/commands/st.md"
HOME="$case_symlink/home" CLAUDE_CONFIG_DIR="$case_symlink/config" SAVE_SYSTEM_HOME="$case_symlink/logs" "$ROOT/install.sh" >/dev/null
[ -L "$case_symlink/config/commands/st.md" ] || { echo "FAIL symlink was replaced"; exit 1; }
assert_contains "$case_symlink/outside.md" "outside target"
if awk -F '\t' '$2 == "commands/st.md" { found=1 } END { exit found ? 0 : 1 }' "$case_symlink/config/session-save-system.manifest"; then
  echo "FAIL symlink was claimed in manifest"; exit 1
fi
pass=$((pass + 1)); echo "ok $pass - symlink target is skipped and unclaimed"

assert_contains "$ROOT/GUIDE.md" "🟡 provisional row"
assert_contains "$ROOT/skills/session-save/SKILL.md" "Checkpoint saved; run /st to tag this session."
pass=$((pass + 1)); echo "ok $pass - first-checkpoint index rule is explicit and aligned"

echo "all $pass tests passed"
