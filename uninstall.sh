#!/bin/sh
# Session Save System uninstaller — removes only hash-proven managed files.
set -eu

CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
MANIFEST=$CLAUDE_DIR/session-save-system.manifest
TMP_REMAINING=$(mktemp "${TMPDIR:-/tmp}/session-save-remaining.XXXXXX")
trap 'rm -f "$TMP_REMAINING"' EXIT HUP INT TERM

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

is_allowed_path() {
  case "$1" in
    skills/session-tag/SKILL.md|skills/session-save/SKILL.md|skills/session-summary/SKILL.md|skills/session-audit/SKILL.md|commands/session-tag.md|commands/session-save.md|commands/session-summary.md|commands/session-audit.md|commands/st.md|commands/ss.md|commands/ssum.md|commands/sa.md|save-system-home) return 0 ;;
    *) return 1 ;;
  esac
}

echo "Session Save System uninstaller"
if [ -L "$MANIFEST" ] || { [ -e "$MANIFEST" ] && [ ! -f "$MANIFEST" ]; }; then
  echo "  ownership manifest is not a regular file; nothing was removed"
  exit 0
fi
if [ ! -f "$MANIFEST" ]; then
  echo "  no ownership manifest found; nothing was removed"
  echo "  legacy or unrelated files require manual review"
  exit 0
fi

while IFS="$(printf '\t')" read -r expected relative; do
  [ -n "$expected" ] && [ -n "$relative" ] || continue
  if ! is_allowed_path "$relative"; then
    echo "  preserved unrecognized manifest path: $relative"
    printf '%s\t%s\n' "$expected" "$relative" >> "$TMP_REMAINING"
    continue
  fi

  target=$CLAUDE_DIR/$relative
  if [ ! -e "$target" ]; then
    echo "  already absent: $relative"
  elif [ -L "$target" ] || [ ! -f "$target" ]; then
    echo "  preserved non-file target: $relative"
    printf '%s\t%s\n' "$expected" "$relative" >> "$TMP_REMAINING"
  elif [ "$(hash_file "$target")" = "$expected" ]; then
    rm -f "$target"
    echo "  removed verified file: $relative"
    case "$relative" in
      skills/*/SKILL.md) rmdir "$(dirname "$target")" 2>/dev/null || true ;;
    esac
  else
    echo "  preserved modified file: $relative"
    printf '%s\t%s\n' "$expected" "$relative" >> "$TMP_REMAINING"
  fi
done < "$MANIFEST"

if [ -s "$TMP_REMAINING" ]; then
  cp "$TMP_REMAINING" "$MANIFEST"
  echo "  manifest retained for files that were not removed"
else
  rm -f "$MANIFEST"
  echo "  ownership manifest removed"
fi

echo ""
echo "Uninstall complete. Session logs and installer backups were not touched."
