#!/bin/sh
# Session Save System v2 installer — Claude Code + Codex, one shared home.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPLICIT_HOME=0
if [ -n "${SESSION_SAVE_HOME:-}" ]; then
  REQUESTED_HOME=$SESSION_SAVE_HOME
  EXPLICIT_HOME=1
elif [ -n "${SAVE_SYSTEM_HOME:-}" ]; then
  REQUESTED_HOME=$SAVE_SYSTEM_HOME
  EXPLICIT_HOME=1
elif [ -f "$HOME/.claude/save-system-home" ] && [ ! -L "$HOME/.claude/save-system-home" ]; then
  REQUESTED_HOME=$(head -n 1 "$HOME/.claude/save-system-home")
else
  REQUESTED_HOME="$HOME/Desktop/session-logs"
fi
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
AGENTS_DIR=${AGENTS_CONFIG_DIR:-"$HOME/.agents"}
CLIENTS=${SESSION_SAVE_CLIENTS:-"claude,codex"}
CONFIG_FILE=${SESSION_SAVE_CONFIG:-"$HOME/.config/session-save/config.json"}
STAMP=$(date +%Y%m%d-%H%M%S)
STATE_BACKUP=${SESSION_SAVE_STATE_DIR:-"$HOME/.local/state/session-save"}/backups/$STAMP
TEMP_FILES=

cleanup() {
  [ -n "$TEMP_FILES" ] && rm -f $TEMP_FILES 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

command -v python3 >/dev/null 2>&1 || {
  echo "Python 3 is required for safe multi-client persistence." >&2
  exit 1
}

has_symlink_component() {
  python3 - "$1" "$2" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
current = root
if current.is_symlink():
    raise SystemExit(0)
for part in pathlib.PurePosixPath(sys.argv[2]).parts[:-1]:
    current = current / part
    if current.is_symlink():
        raise SystemExit(0)
raise SystemExit(1)
PY
}

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

contains_client() {
  case ",$CLIENTS," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

case ",$CLIENTS," in
  *,claude,*|*,codex,*) ;;
  *) echo "SESSION_SAVE_CLIENTS must include claude and/or codex" >&2; exit 1 ;;
esac
case "$CLIENTS" in
  claude|codex|claude,codex|codex,claude) ;;
  *) echo "Unsupported client list: $CLIENTS (supported: claude,codex)" >&2; exit 1 ;;
esac

if [ -L "$CONFIG_FILE" ] || { [ -e "$CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; }; then
  echo "Cannot use config path because it is not a regular file: $CONFIG_FILE" >&2
  exit 1
fi
mkdir -p "$(dirname "$CONFIG_FILE")"
if [ -f "$CONFIG_FILE" ]; then
  HOME_DIR=$(python3 - "$CONFIG_FILE" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
try:
    value = json.loads(path.read_text()).get("home")
except Exception as exc:
    raise SystemExit(f"invalid Session Save config {path}: {exc}")
if not value:
    raise SystemExit(f"Session Save config has no home: {path}")
print(pathlib.Path(value).expanduser().resolve())
PY
)
  REQUESTED_RESOLVED=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve())' "$REQUESTED_HOME")
  if [ "$REQUESTED_RESOLVED" != "$HOME_DIR" ]; then
    if [ "$EXPLICIT_HOME" = 1 ]; then
      echo "Explicit home conflicts with existing config: $CONFIG_FILE" >&2
      echo "  configured: $HOME_DIR" >&2
      echo "  requested:  $REQUESTED_RESOLVED" >&2
      echo "Update or remove the config deliberately before reinstalling." >&2
      exit 1
    fi
    echo "  existing shared-home config wins: $HOME_DIR"
  fi
else
  HOME_DIR=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve())' "$REQUESTED_HOME")
  CONFIG_TMP=$(mktemp "$(dirname "$CONFIG_FILE")/.config.json.XXXXXX")
  TEMP_FILES="$TEMP_FILES $CONFIG_TMP"
  python3 - "$CONFIG_TMP" "$HOME_DIR" <<'PY'
import json, os, pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({"schema_version": "2.0", "home": sys.argv[2]}, indent=2) + "\n")
os.chmod(path, 0o600)
PY
  mv "$CONFIG_TMP" "$CONFIG_FILE"
  TEMP_FILES=
fi

install_client() {
  client=$1
  target_root=$2
  manifest=$target_root/session-save-system.manifest
  backup_base=$target_root/session-save-system-backups/$STAMP
  backup_root=$backup_base
  if [ -L "$target_root" ] || { [ -e "$target_root" ] && [ ! -d "$target_root" ]; }; then
    echo "Cannot use client root because it is not a real directory: $target_root" >&2
    exit 1
  fi
  suffix=0
  while [ -e "$backup_root" ]; do
    suffix=$((suffix + 1))
    backup_root=$backup_base-$suffix
  done
  mkdir -p "$target_root"

  if [ -L "$manifest" ] || { [ -e "$manifest" ] && [ ! -f "$manifest" ]; }; then
    echo "Cannot use ownership manifest: $manifest" >&2
    exit 1
  fi

  tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/session-save-$client-manifest.XXXXXX")
  next_manifest=$(mktemp "$target_root/.session-save-system.manifest.XXXXXX")
  TEMP_FILES="$TEMP_FILES $tmp_manifest $next_manifest"

  previous_hash() {
    [ -f "$manifest" ] || return 0
    awk -F '\t' -v wanted="$1" '$2 == wanted { print $1; exit }' "$manifest"
  }

  install_managed() {
    source_file=$1
    relative=$2
    label=$3
    target=$target_root/$relative
    prior=$(previous_hash "$relative")
    if has_symlink_component "$target_root" "$relative"; then
      echo "  skipped $client $label — a parent path is a symlink: $target"
      return
    fi
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
      echo "  skipped $client $label — non-regular target: $target"
      return
    fi
    if [ -f "$target" ] && cmp -s "$source_file" "$target"; then
      echo "  verified $client $label"
    elif [ -f "$target" ] && [ -z "$prior" ]; then
      echo "  skipped $client $label — unrelated file exists: $target"
      return
    else
      if [ -f "$target" ]; then
        mkdir -p "$backup_root/$(dirname "$relative")"
        cp -p "$target" "$backup_root/$relative"
        echo "  backed up $client $relative"
      fi
      cp "$source_file" "$target"
      echo "  installed $client $label"
    fi
    printf '%s\t%s\n' "$(hash_file "$target")" "$relative" >> "$tmp_manifest"
  }

  for skill in session-tag session-save session-summary session-audit; do
    install_managed "$REPO_DIR/skills/$skill/SKILL.md" "skills/$skill/SKILL.md" "skill $skill"
    install_managed "$REPO_DIR/adapters/$client/CLIENT.md" "skills/$skill/CLIENT.md" "$skill adapter"
    install_managed "$REPO_DIR/scripts/session_save.py" "skills/$skill/scripts/session_save.py" "$skill kernel"
  done

  if [ "$client" = "claude" ]; then
    for command in session-tag session-save session-summary session-audit st ss ssum sa; do
      install_managed "$REPO_DIR/commands/$command.md" "commands/$command.md" "command /$command"
    done
    pointer=$(mktemp "${TMPDIR:-/tmp}/session-save-home.XXXXXX")
    TEMP_FILES="$TEMP_FILES $pointer"
    printf '%s\n' "$HOME_DIR" > "$pointer"
    install_managed "$pointer" "save-system-home" "legacy-compatible home pointer"
  fi

  if [ -s "$tmp_manifest" ]; then
    sort -t "$(printf '\t')" -k2,2 "$tmp_manifest" > "$next_manifest"
    mv "$next_manifest" "$manifest"
    echo "  $client ownership manifest: $manifest"
  else
    rm -f "$next_manifest"
    echo "  no $client files installed; manifest unchanged"
  fi
  rm -f "$tmp_manifest"
  TEMP_FILES=
}

echo "Session Save System v2 installer"
echo "  shared home: $HOME_DIR"
echo "  clients: $CLIENTS"

contains_client claude && install_client claude "$CLAUDE_DIR"
contains_client codex && install_client codex "$AGENTS_DIR"

# The shared home is user data and never enters an ownership manifest.
python3 "$REPO_DIR/scripts/session_save.py" --home "$HOME_DIR" home --init >/dev/null
if [ -f "$HOME_DIR/GUIDE.md" ] && ! cmp -s "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"; then
  mkdir -p "$STATE_BACKUP/log-home"
  cp -p "$HOME_DIR/GUIDE.md" "$STATE_BACKUP/log-home/GUIDE.md"
  echo "  backed up customized GUIDE.md -> $STATE_BACKUP/log-home/GUIDE.md"
fi
cp "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"
cp "$REPO_DIR/VERSION" "$HOME_DIR/.version" 2>/dev/null || true

migration=$(python3 "$REPO_DIR/scripts/session_save.py" --home "$HOME_DIR" migrate-v1 --client claude --dry-run)
count=$(printf '%s' "$migration" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')

echo ""
if [ "$count" -gt 0 ]; then
  echo "Installed, but $count legacy record(s) require copy-first migration before use."
  echo "Review: python3 \"$REPO_DIR/scripts/session_save.py\" --home \"$HOME_DIR\" migrate-v1 --client claude --dry-run"
  echo "Apply after review: python3 \"$REPO_DIR/scripts/session_save.py\" --home \"$HOME_DIR\" migrate-v1 --client claude --apply"
else
  echo "Done. Claude Code and Codex now share: $HOME_DIR"
fi
echo "Claude Code: /session-tag (or /st)"
echo "Codex: mention \$session-tag or select it through /skills"
echo "Uninstall removes only hash-proven adapter files; records and backups are never removed."
