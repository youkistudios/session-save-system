#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
KERNEL=$ROOT/scripts/session_save.py
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/session-save-tests.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

pass=0
assert_file() { [ -f "$1" ] || { echo "FAIL missing file: $1"; exit 1; }; }
assert_dir() { [ -d "$1" ] || { echo "FAIL missing directory: $1"; exit 1; }; }
assert_absent() { [ ! -e "$1" ] || { echo "FAIL expected absent: $1"; exit 1; }; }
assert_contains() { grep -F "$2" "$1" >/dev/null || { echo "FAIL '$2' not found in $1"; exit 1; }; }
ok() { pass=$((pass + 1)); echo "ok $pass - $1"; }

install_case() {
  base=$1
  mkdir -p "$base/home" "$base/claude" "$base/agents" "$base/config"
  HOME="$base/home" CLAUDE_CONFIG_DIR="$base/claude" AGENTS_CONFIG_DIR="$base/agents" \
    SESSION_SAVE_CONFIG="$base/config/config.json" SESSION_SAVE_HOME="$base/logs" \
    "$ROOT/install.sh" >/dev/null
}

case_fresh=$TEST_ROOT/fresh
install_case "$case_fresh"
assert_file "$case_fresh/claude/session-save-system.manifest"
assert_file "$case_fresh/agents/session-save-system.manifest"
assert_file "$case_fresh/claude/skills/session-tag/CLIENT.md"
assert_file "$case_fresh/agents/skills/session-tag/CLIENT.md"
assert_file "$case_fresh/claude/skills/session-save/scripts/session_save.py"
assert_file "$case_fresh/agents/skills/session-save/scripts/session_save.py"
assert_file "$case_fresh/claude/commands/st.md"
assert_absent "$case_fresh/agents/commands/st.md"
assert_contains "$case_fresh/claude/skills/session-tag/CLIENT.md" '`client_id`: `claude`'
assert_contains "$case_fresh/agents/skills/session-tag/CLIENT.md" '`client_id`: `codex`'
[ "$(wc -l < "$case_fresh/claude/session-save-system.manifest" | tr -d ' ')" = 21 ] || { echo "FAIL Claude manifest count"; exit 1; }
[ "$(wc -l < "$case_fresh/agents/session-save-system.manifest" | tr -d ' ')" = 12 ] || { echo "FAIL Codex manifest count"; exit 1; }
ok "fresh install creates exact Claude and Codex adapters"

assert_file "$case_fresh/config/config.json"
python3 - "$case_fresh/config/config.json" "$case_fresh/logs" <<'PY'
import json, pathlib, sys
actual = pathlib.Path(json.loads(pathlib.Path(sys.argv[1]).read_text())["home"]).resolve()
expected = pathlib.Path(sys.argv[2]).resolve()
raise SystemExit(0 if actual == expected else 1)
PY
assert_file "$case_fresh/logs/GUIDE.md"
assert_dir "$case_fresh/logs/audits/global"
ok "both adapters resolve one shared user-owned home"

if HOME="$case_fresh/home" CLAUDE_CONFIG_DIR="$case_fresh/claude" AGENTS_CONFIG_DIR="$case_fresh/agents" SESSION_SAVE_CONFIG="$case_fresh/config/config.json" SESSION_SAVE_HOME="$case_fresh/other-logs" "$ROOT/install.sh" >/dev/null 2>&1; then
  echo "FAIL conflicting explicit home was silently ignored"; exit 1
fi
assert_absent "$case_fresh/other-logs"
ok "reinstall fails clearly when an explicit home conflicts with config"

case_collision=$TEST_ROOT/collision
mkdir -p "$case_collision/home" "$case_collision/claude" "$case_collision/agents/skills/session-tag" "$case_collision/config"
printf '%s\n' 'unrelated skill' > "$case_collision/agents/skills/session-tag/SKILL.md"
HOME="$case_collision/home" CLAUDE_CONFIG_DIR="$case_collision/claude" AGENTS_CONFIG_DIR="$case_collision/agents" \
  SESSION_SAVE_CONFIG="$case_collision/config/config.json" SESSION_SAVE_HOME="$case_collision/logs" \
  "$ROOT/install.sh" >/dev/null
assert_contains "$case_collision/agents/skills/session-tag/SKILL.md" "unrelated skill"
if awk -F '\t' '$2 == "skills/session-tag/SKILL.md" { found=1 } END { exit found ? 0 : 1 }' "$case_collision/agents/session-save-system.manifest"; then
  echo "FAIL unrelated Codex collision was claimed"; exit 1
fi
ok "unrelated client files are skipped and unclaimed"

case_backup=$TEST_ROOT/backup
install_case "$case_backup"
printf '%s\n' 'local managed edit' > "$case_backup/agents/skills/session-save/CLIENT.md"
HOME="$case_backup/home" CLAUDE_CONFIG_DIR="$case_backup/claude" AGENTS_CONFIG_DIR="$case_backup/agents" \
  SESSION_SAVE_CONFIG="$case_backup/config/config.json" SESSION_SAVE_HOME="$case_backup/logs" \
  "$ROOT/install.sh" >/dev/null
backup=$(find "$case_backup/agents/session-save-system-backups" -path '*/skills/session-save/CLIENT.md' -type f | head -1)
assert_file "$backup"
assert_contains "$backup" "local managed edit"
assert_contains "$case_backup/agents/skills/session-save/CLIENT.md" '`client_id`: `codex`'
ok "managed adapter replacement is recoverable"

case_records=$TEST_ROOT/records
mkdir -p "$case_records/home"
python3 "$KERNEL" --home "$case_records/logs" begin --client claude --project "Shared Project" --name "Shared Project Research" --status open --gist "Claude research" > "$case_records/claude.json"
python3 "$KERNEL" --home "$case_records/logs" begin --client codex --project "Shared Project" --name "Shared Project Build" --status provisional --gist "Codex build" > "$case_records/codex.json"
claude_record=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["path"])' "$case_records/claude.json")
codex_record=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["path"])' "$case_records/codex.json")
assert_file "$claude_record/record.json"
assert_file "$codex_record/record.json"
case "$claude_record" in */shared-project/claude/*) ;; *) echo "FAIL Claude namespace"; exit 1 ;; esac
case "$codex_record" in */shared-project/codex/*) ;; *) echo "FAIL Codex namespace"; exit 1 ;; esac
assert_contains "$case_records/logs/_INDEX.md" '`claude`'
assert_contains "$case_records/logs/_INDEX.md" '`codex`'
ok "Claude and Codex records remain separated under one project"

checkpoint=$(python3 "$KERNEL" --home "$case_records/logs" checkpoint-path --client codex --record "$codex_record" | python3 -c 'import json,sys; print(json.load(sys.stdin)["path"])')
printf '%s\n' '### 12:00 — codex' '' '- **Now:** testing' > "$checkpoint"
python3 "$KERNEL" --home "$case_records/logs" sync --client codex --record "$codex_record" --operation checkpoint-written >/dev/null
assert_file "$checkpoint"
[ "$(find "$codex_record/checkpoints" -type f | wc -l | tr -d ' ')" = 1 ] || { echo "FAIL immutable checkpoint"; exit 1; }
ok "checkpoints use immutable event files"

if python3 "$KERNEL" --home "$case_records/logs" checkpoint-path --client claude --record "$codex_record" >/dev/null 2>&1; then
  echo "FAIL Claude allocated a Codex checkpoint"; exit 1
fi
if python3 "$KERNEL" --home "$case_records/logs" sync --client claude --record "$codex_record" --status closed >/dev/null 2>&1; then
  echo "FAIL Claude mutated a Codex record"; exit 1
fi
assert_contains "$codex_record/record.json" '"client_id": "codex"'
assert_contains "$codex_record/record.json" '"status": "provisional"'
ok "kernel enforces client ownership on source-record mutations"

case_concurrent=$TEST_ROOT/concurrent
mkdir -p "$case_concurrent"
i=1
while [ "$i" -le 24 ]; do
  client=claude; [ $((i % 2)) -eq 0 ] && client=codex
  python3 "$KERNEL" --home "$case_concurrent/logs" begin --client "$client" --project "Concurrency" --name "Concurrency Run $i" --session-id "$client-$i" --status open >/dev/null &
  i=$((i + 1))
done
wait
[ "$(find "$case_concurrent/logs/sessions" -name record.json -type f | wc -l | tr -d ' ')" = 24 ] || { echo "FAIL concurrent record count"; exit 1; }
[ "$(find "$case_concurrent/logs/events" -name '*.json' -type f | wc -l | tr -d ' ')" = 24 ] || { echo "FAIL concurrent event count"; exit 1; }
[ "$(grep -c '^| 🟢 open ' "$case_concurrent/logs/_INDEX.md")" = 24 ] || { echo "FAIL concurrent index count"; exit 1; }
python3 -c 'import json, pathlib, sys; [json.loads(p.read_text()) for p in pathlib.Path(sys.argv[1]).rglob("*.json")]' "$case_concurrent/logs"
ok "24 simultaneous cross-client writes preserve records, events, and index"

case_migrate=$TEST_ROOT/migrate
legacy=$case_migrate/logs/sessions/Legacy-Project/2026-07-01_legacy-work
mkdir -p "$legacy"
printf '%s\n' '---' 'session_slug: legacy-work' 'project: Legacy Project' 'name: "Legacy Project Work"' 'status: closed' '---' '# Legacy Project Work — session tag' > "$legacy/tag.md"
printf '%s\n' '# Human summary' > "$legacy/human.md"
dry=$(python3 "$KERNEL" --home "$case_migrate/logs" migrate-v1 --client claude --dry-run)
[ "$(printf '%s' "$dry" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')" = 1 ] || { echo "FAIL migration dry run"; exit 1; }
blocked=$(python3 "$KERNEL" --home "$case_migrate/logs" doctor --client codex)
[ "$(printf '%s' "$blocked" | python3 -c 'import json,sys; print(json.load(sys.stdin)["migration_required"])')" = 1 ] || { echo "FAIL doctor did not block legacy home"; exit 1; }
python3 "$KERNEL" --home "$case_migrate/logs" migrate-v1 --client claude --apply > "$case_migrate/receipt.json"
assert_file "$legacy/tag.md"
assert_file "$case_migrate/logs/sessions/legacy-project/claude/2026-07-01_legacy-work/record.json"
assert_contains "$case_migrate/receipt.json" '"source_records_preserved": true'
[ "$(python3 "$KERNEL" --home "$case_migrate/logs" doctor --client codex | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["ok"]).lower())')" = true ] || { echo "FAIL doctor after migration"; exit 1; }
ok "legacy migration is dry-run first, copy-only, and receipted"

case_migrate_link=$TEST_ROOT/migrate-symlink
legacy_link=$case_migrate_link/logs/sessions/Linked/2026-07-01_linked
mkdir -p "$legacy_link" "$case_migrate_link/outside"
printf '%s\n' 'outside content' > "$case_migrate_link/outside/tag.md"
ln -s "$case_migrate_link/outside/tag.md" "$legacy_link/tag.md"
linked_dry=$(python3 "$KERNEL" --home "$case_migrate_link/logs" migrate-v1 --client claude --dry-run)
[ "$(printf '%s' "$linked_dry" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["candidates"][0]["symlinks"]))')" = 1 ] || { echo "FAIL migration dry run hid symlink"; exit 1; }
python3 "$KERNEL" --home "$case_migrate_link/logs" migrate-v1 --client claude --apply > "$case_migrate_link/result.json"
assert_contains "$case_migrate_link/result.json" 'legacy record contains symlinks'
assert_absent "$case_migrate_link/logs/sessions/linked/claude/2026-07-01_linked/record.json"
assert_contains "$case_migrate_link/outside/tag.md" 'outside content'
ok "migration reports and refuses legacy records containing symlinks"

case_migration_help=$TEST_ROOT/migration-help
mkdir -p "$case_migration_help/home" "$case_migration_help/claude" "$case_migration_help/agents" "$case_migration_help/config" "$case_migration_help/logs/sessions/Old/2026-07-01_old"
printf '%s\n' '# Old' > "$case_migration_help/logs/sessions/Old/2026-07-01_old/tag.md"
(cd /tmp && HOME="$case_migration_help/home" CLAUDE_CONFIG_DIR="$case_migration_help/claude" AGENTS_CONFIG_DIR="$case_migration_help/agents" SESSION_SAVE_CONFIG="$case_migration_help/config/config.json" SESSION_SAVE_HOME="$case_migration_help/logs" "$ROOT/install.sh") > "$case_migration_help/output.txt"
assert_contains "$case_migration_help/output.txt" "python3 \"$ROOT/scripts/session_save.py\""
ok "migration instructions use an absolute runnable kernel path"

case_audit=$TEST_ROOT/audit
cp -R "$case_records/logs" "$case_audit"
sources=$(python3 "$KERNEL" --home "$case_audit" audit-sources --days 7)
[ "$(printf '%s' "$sources" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')" = 2 ] || { echo "FAIL audit sources"; exit 1; }
printf '%s\n' '# Weekly audit' '' '- [Claude] Research.' '- [Codex] Build.' > "$case_audit/draft.md"
python3 "$KERNEL" --home "$case_audit" write-audit --week 2026-W30 --input "$case_audit/draft.md" >/dev/null
assert_contains "$case_audit/audits/global/2026-W30_audit.md" '[Claude]'
assert_contains "$case_audit/audits/global/2026-W30_audit.md" '[Codex]'
ok "global audits can aggregate source-attributed client records"

case_remove=$TEST_ROOT/remove
install_case "$case_remove"
printf '%s\n' 'preserve local edit' > "$case_remove/claude/commands/st.md"
printf '%s\n' 'user record' > "$case_remove/logs/keep.md"
HOME="$case_remove/home" CLAUDE_CONFIG_DIR="$case_remove/claude" AGENTS_CONFIG_DIR="$case_remove/agents" SESSION_SAVE_CONFIG="$case_remove/config/config.json" "$ROOT/uninstall.sh" >/dev/null
assert_file "$case_remove/claude/commands/st.md"
assert_contains "$case_remove/claude/commands/st.md" 'preserve local edit'
assert_absent "$case_remove/claude/skills/session-save/SKILL.md"
assert_absent "$case_remove/agents/skills/session-save/SKILL.md"
assert_file "$case_remove/logs/keep.md"
assert_file "$case_remove/config/config.json"
ok "uninstall removes exact adapters and preserves edits, config, and records"

case_legacy=$TEST_ROOT/no-manifest
mkdir -p "$case_legacy/home" "$case_legacy/claude/commands" "$case_legacy/agents"
printf '%s\n' 'legacy file' > "$case_legacy/claude/commands/st.md"
HOME="$case_legacy/home" CLAUDE_CONFIG_DIR="$case_legacy/claude" AGENTS_CONFIG_DIR="$case_legacy/agents" "$ROOT/uninstall.sh" >/dev/null
assert_file "$case_legacy/claude/commands/st.md"
ok "no ownership manifest means no deletion"

case_symlink=$TEST_ROOT/symlink
mkdir -p "$case_symlink/home" "$case_symlink/claude" "$case_symlink/agents/skills/session-tag" "$case_symlink/config"
printf '%s\n' 'outside target' > "$case_symlink/outside.md"
ln -s "$case_symlink/outside.md" "$case_symlink/agents/skills/session-tag/SKILL.md"
HOME="$case_symlink/home" CLAUDE_CONFIG_DIR="$case_symlink/claude" AGENTS_CONFIG_DIR="$case_symlink/agents" SESSION_SAVE_CONFIG="$case_symlink/config/config.json" SESSION_SAVE_HOME="$case_symlink/logs" "$ROOT/install.sh" >/dev/null
[ -L "$case_symlink/agents/skills/session-tag/SKILL.md" ] || { echo "FAIL symlink replaced"; exit 1; }
assert_contains "$case_symlink/outside.md" 'outside target'
ok "installer never follows or claims a skill symlink"

case_parent_link=$TEST_ROOT/parent-symlink
mkdir -p "$case_parent_link/home" "$case_parent_link/claude" "$case_parent_link/agents/skills" "$case_parent_link/config" "$case_parent_link/outside/session-tag"
printf '%s\n' 'outside skill' > "$case_parent_link/outside/session-tag/SKILL.md"
ln -s "$case_parent_link/outside/session-tag" "$case_parent_link/agents/skills/session-tag"
HOME="$case_parent_link/home" CLAUDE_CONFIG_DIR="$case_parent_link/claude" AGENTS_CONFIG_DIR="$case_parent_link/agents" SESSION_SAVE_CONFIG="$case_parent_link/config/config.json" SESSION_SAVE_HOME="$case_parent_link/logs" "$ROOT/install.sh" >/dev/null
assert_contains "$case_parent_link/outside/session-tag/SKILL.md" 'outside skill'
assert_absent "$case_parent_link/outside/session-tag/CLIENT.md"
assert_absent "$case_parent_link/outside/session-tag/scripts/session_save.py"
if awk -F '\t' '$2 ~ /^skills\/session-tag\// { found=1 } END { exit found ? 0 : 1 }' "$case_parent_link/agents/session-save-system.manifest"; then
  echo "FAIL symlinked parent contents were claimed"; exit 1
fi
ok "installer never traverses a symlinked skill directory"

if python3 "$KERNEL" --home "$TEST_ROOT/reject" begin --client '../codex' --project X --name Y >/dev/null 2>&1; then
  echo "FAIL traversal client accepted"; exit 1
fi
if python3 "$KERNEL" --home "$TEST_ROOT/reject" begin --client claude --project '../X' --name Y >/dev/null 2>&1; then
  echo "FAIL traversal project accepted"; exit 1
fi
if python3 "$KERNEL" --home "$TEST_ROOT/reject" begin --client claude --project X --name Y --date '../../../events/x' >/dev/null 2>&1; then
  echo "FAIL traversal date accepted"; exit 1
fi
ok "kernel rejects client, project, and date path traversal"

case_kernel_link=$TEST_ROOT/kernel-symlink
mkdir -p "$case_kernel_link/logs/sessions" "$case_kernel_link/outside"
ln -s "$case_kernel_link/outside" "$case_kernel_link/logs/sessions/linked-project"
if python3 "$KERNEL" --home "$case_kernel_link/logs" begin --client codex --project 'Linked Project' --name 'Linked Project Escape' >/dev/null 2>&1; then
  echo "FAIL kernel traversed a symlinked project directory"; exit 1
fi
[ "$(find "$case_kernel_link/outside" -type f | wc -l | tr -d ' ')" = 0 ] || { echo "FAIL kernel wrote outside home"; exit 1; }
ok "kernel refuses existing symlinks below the shared home"

assert_contains "$ROOT/GUIDE.md" "One record per client session"
assert_contains "$ROOT/skills/session-save/SKILL.md" "single provisional record"
assert_contains "$ROOT/skills/session-audit/SKILL.md" "every installed client"
ok "portable skills align on identity, provisional state, and global audit"

echo "all $pass tests passed"
