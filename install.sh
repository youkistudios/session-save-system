#!/bin/sh
# Session Save System installer — exact-identity install with recoverable replacements.
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HOME_DIR=${SAVE_SYSTEM_HOME:-"$HOME/Desktop/session-logs"}
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
MANIFEST=$CLAUDE_DIR/session-save-system.manifest
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_BASE=$CLAUDE_DIR/session-save-system-backups/$STAMP
BACKUP_ROOT=$BACKUP_BASE
BACKUP_SUFFIX=0
while [ -e "$BACKUP_ROOT" ]; do
  BACKUP_SUFFIX=$((BACKUP_SUFFIX + 1))
  BACKUP_ROOT=$BACKUP_BASE-$BACKUP_SUFFIX
done
TMP_MANIFEST=$(mktemp "${TMPDIR:-/tmp}/session-save-manifest.XXXXXX")
TMP_HOME=$(mktemp "${TMPDIR:-/tmp}/session-save-home.XXXXXX")
MANIFEST_NEXT=
trap 'rm -f "$TMP_MANIFEST" "$TMP_HOME" ${MANIFEST_NEXT:+"$MANIFEST_NEXT"}' EXIT HUP INT TERM

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

previous_hash() {
  [ -f "$MANIFEST" ] || return 0
  awk -F '\t' -v wanted="$1" '$2 == wanted { print $1; exit }' "$MANIFEST"
}

backup_file() {
  relative=$1
  target=$CLAUDE_DIR/$relative
  backup=$BACKUP_ROOT/$relative
  mkdir -p "$(dirname "$backup")"
  cp -p "$target" "$backup"
  echo "  backed up: $relative -> $backup"
}

install_managed() {
  source_file=$1
  relative=$2
  label=$3
  target=$CLAUDE_DIR/$relative
  prior=$(previous_hash "$relative")

  mkdir -p "$(dirname "$target")"
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    echo "  skipped $label — target exists and is not a regular file: $target"
    return
  fi

  if [ -f "$target" ] && cmp -s "$source_file" "$target"; then
    echo "  verified $label"
  elif [ -f "$target" ] && [ -z "$prior" ]; then
    echo "  skipped $label — unrelated file already exists: $target"
    return
  else
    if [ -f "$target" ]; then
      current=$(hash_file "$target")
      if [ "$current" != "$prior" ]; then
        echo "  note: $label changed since the previous install"
      fi
      backup_file "$relative"
    fi
    cp "$source_file" "$target"
    echo "  installed $label"
  fi

  printf '%s\t%s\n' "$(hash_file "$target")" "$relative" >> "$TMP_MANIFEST"
}

echo "Session Save System installer"
echo "  home folder: $HOME_DIR"
echo "  Claude config: $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"
if [ -L "$MANIFEST" ] || { [ -e "$MANIFEST" ] && [ ! -f "$MANIFEST" ]; }; then
  echo "  cannot use ownership manifest — path is not a regular file: $MANIFEST" >&2
  exit 1
fi
MANIFEST_NEXT=$(mktemp "$CLAUDE_DIR/.session-save-system.manifest.XXXXXX")

for skill in session-tag session-save session-summary session-audit; do
  install_managed "$REPO_DIR/skills/$skill/SKILL.md" "skills/$skill/SKILL.md" "skill $skill"
done

for command in session-tag session-save session-summary session-audit st ss ssum sa; do
  install_managed "$REPO_DIR/commands/$command.md" "commands/$command.md" "command /$command"
done

printf '%s\n' "$HOME_DIR" > "$TMP_HOME"
install_managed "$TMP_HOME" "save-system-home" "home-path pointer"

if [ -s "$TMP_MANIFEST" ]; then
  sort -t "$(printf '\t')" -k2,2 "$TMP_MANIFEST" > "$MANIFEST_NEXT"
  mv "$MANIFEST_NEXT" "$MANIFEST"
  MANIFEST_NEXT=
  echo "  ownership manifest: $MANIFEST"
else
  echo "  no files installed; ownership manifest unchanged"
fi

# The log home is user data, not part of the uninstall manifest.
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/audits"
if [ -f "$HOME_DIR/GUIDE.md" ] && ! cmp -s "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"; then
  mkdir -p "$BACKUP_ROOT/log-home"
  cp -p "$HOME_DIR/GUIDE.md" "$BACKUP_ROOT/log-home/GUIDE.md"
  echo "  backed up customized GUIDE.md -> $BACKUP_ROOT/log-home/GUIDE.md"
fi
cp "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"

if [ ! -f "$HOME_DIR/_INDEX.md" ]; then
  printf '%s\n' '# Session Index' '> One row per session, newest first. Read this to catch up across chats.' '> 🟡 provisional · 🟢 open · ✅ closed' '' '| Date | Session | Status | Gist | Folder |' '|------|---------|--------|------|--------|' > "$HOME_DIR/_INDEX.md"
fi
if [ ! -f "$HOME_DIR/sessions/_PROJECTS.md" ]; then
  printf '%s\n' '# Projects' '> User-approved project registry. New candidates remain unconfirmed until reviewed.' > "$HOME_DIR/sessions/_PROJECTS.md"
fi
cp "$REPO_DIR/VERSION" "$HOME_DIR/.version" 2>/dev/null || true

echo ""
echo "Done. Open Claude Code and type /session-tag (or /st)."
echo "Logs live in: $HOME_DIR"
echo "Uninstall with ./uninstall.sh; logs and backups are never removed."
