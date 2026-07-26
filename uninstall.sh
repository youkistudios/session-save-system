#!/bin/sh
# Session Save System v2 uninstaller — adapters only, never shared records.
set -eu

CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
AGENTS_DIR=${AGENTS_CONFIG_DIR:-"$HOME/.agents"}
CLIENTS=${SESSION_SAVE_CLIENTS:-"claude,codex"}
LIB_DIR=${SESSION_SAVE_LIB_DIR:-"$HOME/.local/share/session-save"}
SHARED_MANIFEST=$LIB_DIR/install.manifest
TEMP_FILES=
trap '[ -n "$TEMP_FILES" ] && rm -f $TEMP_FILES 2>/dev/null || true' EXIT HUP INT TERM

has_symlink_component() {
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$1" "$2" <<'PY'
import pathlib, sys
current = pathlib.Path(sys.argv[1])
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
  case ",$CLIENTS," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

is_allowed_path() {
  case "$1" in
    skills/session-tag/SKILL.md|skills/session-tag/CLIENT.md|skills/session-tag/scripts/session_save.py|skills/session-save/SKILL.md|skills/session-save/CLIENT.md|skills/session-save/scripts/session_save.py|skills/session-summary/SKILL.md|skills/session-summary/CLIENT.md|skills/session-summary/scripts/session_save.py|skills/session-audit/SKILL.md|skills/session-audit/CLIENT.md|skills/session-audit/scripts/session_save.py|commands/session-tag.md|commands/session-save.md|commands/session-summary.md|commands/session-audit.md|commands/st.md|commands/ss.md|commands/ssum.md|commands/sa.md|save-system-home) return 0 ;;
    *) return 1 ;;
  esac
}

uninstall_client() {
  client=$1
  target_root=$2
  if [ -L "$target_root" ] || { [ -e "$target_root" ] && [ ! -d "$target_root" ]; }; then
    echo "$client adapter:"
    echo "  client root is not a real directory; nothing removed"
    return
  fi
  manifest=$target_root/session-save-system.manifest
  remaining=$(mktemp "${TMPDIR:-/tmp}/session-save-$client-remaining.XXXXXX")
  TEMP_FILES="$TEMP_FILES $remaining"

  echo "$client adapter:"
  if [ -L "$manifest" ] || { [ -e "$manifest" ] && [ ! -f "$manifest" ]; }; then
    echo "  ownership manifest is not a regular file; nothing removed"
    rm -f "$remaining"; TEMP_FILES=
    return
  fi
  if [ ! -f "$manifest" ]; then
    echo "  no ownership manifest; nothing removed"
    rm -f "$remaining"; TEMP_FILES=
    return
  fi

  while IFS="$(printf '\t')" read -r expected relative; do
    [ -n "$expected" ] && [ -n "$relative" ] || continue
    if ! is_allowed_path "$relative"; then
      echo "  preserved unrecognized manifest path: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
      continue
    fi
    target=$target_root/$relative
    if has_symlink_component "$target_root" "$relative"; then
      echo "  preserved path below symlinked directory: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
    elif [ ! -e "$target" ]; then
      echo "  already absent: $relative"
    elif [ -L "$target" ] || [ ! -f "$target" ]; then
      echo "  preserved non-file target: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
    elif [ "$(hash_file "$target")" = "$expected" ]; then
      rm -f "$target"
      echo "  removed verified file: $relative"
      case "$relative" in
        skills/*/scripts/session_save.py) rmdir "$(dirname "$target")" 2>/dev/null || true ;;
        skills/*/SKILL.md|skills/*/CLIENT.md) rmdir "$(dirname "$target")" 2>/dev/null || true ;;
      esac
    else
      echo "  preserved modified file: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
    fi
  done < "$manifest"

  for skill in session-tag session-save session-summary session-audit; do
    rmdir "$target_root/skills/$skill/scripts" 2>/dev/null || true
    rmdir "$target_root/skills/$skill" 2>/dev/null || true
  done

  if [ -s "$remaining" ]; then
    cp "$remaining" "$manifest"
    echo "  manifest retained for preserved files"
  else
    rm -f "$manifest"
    echo "  ownership manifest removed"
  fi
  rm -f "$remaining"; TEMP_FILES=
}

uninstall_shared() {
  echo "shared kernel:"
  if [ -L "$LIB_DIR" ] || { [ -e "$LIB_DIR" ] && [ ! -d "$LIB_DIR" ]; }; then
    echo "  shared library path is not a real directory; nothing removed"
    return
  fi
  if [ -L "$SHARED_MANIFEST" ] || { [ -e "$SHARED_MANIFEST" ] && [ ! -f "$SHARED_MANIFEST" ]; }; then
    echo "  shared ownership manifest is not a regular file; nothing removed"
    return
  fi
  if [ ! -f "$SHARED_MANIFEST" ]; then
    echo "  no shared ownership manifest; nothing removed"
    return
  fi

  remaining=$(mktemp "${TMPDIR:-/tmp}/session-save-shared-remaining.XXXXXX")
  TEMP_FILES="$TEMP_FILES $remaining"
  while IFS="$(printf '\t')" read -r expected relative; do
    [ -n "$expected" ] && [ -n "$relative" ] || continue
    case "$relative" in
      session_save.py|VERSION) ;;
      *)
        echo "  preserved unrecognized shared manifest path: $relative"
        printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
        continue
        ;;
    esac
    target=$LIB_DIR/$relative
    if [ ! -e "$target" ]; then
      echo "  already absent: $relative"
    elif [ -L "$target" ] || [ ! -f "$target" ]; then
      echo "  preserved non-file shared target: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
    elif [ "$(hash_file "$target")" = "$expected" ]; then
      rm -f "$target"
      echo "  removed verified shared file: $relative"
    else
      echo "  preserved modified shared file: $relative"
      printf '%s\t%s\n' "$expected" "$relative" >> "$remaining"
    fi
  done < "$SHARED_MANIFEST"

  if [ -s "$remaining" ]; then
    cp "$remaining" "$SHARED_MANIFEST"
    echo "  shared manifest retained for preserved files"
  else
    rm -f "$SHARED_MANIFEST"
    rmdir "$LIB_DIR" 2>/dev/null || true
    echo "  shared ownership manifest removed"
  fi
  rm -f "$remaining"; TEMP_FILES=
}

echo "Session Save System v2 uninstaller"
contains_client claude && uninstall_client claude "$CLAUDE_DIR"
contains_client codex && uninstall_client codex "$AGENTS_DIR"

manifest_has_launcher() {
  manifest=$1
  [ -f "$manifest" ] || return 1
  awk -F '\t' '{ n=split($2,p,"/"); if (n == 4 && p[1] == "skills" && p[3] == "scripts" && p[4] == "session_save.py") found=1 } END { exit found ? 0 : 1 }' "$manifest"
}

if manifest_has_launcher "$CLAUDE_DIR/session-save-system.manifest" || manifest_has_launcher "$AGENTS_DIR/session-save-system.manifest"; then
  echo "shared kernel:"
  echo "  retained because a managed kernel launcher remains installed"
else
  uninstall_shared
fi

echo ""
echo "Uninstall complete. The shared config, logs, migration sources, and backups were not touched."
