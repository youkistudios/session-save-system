#!/bin/sh
# Session Save System installer — copies skills + commands into ~/.claude and creates the home folder.
# Safe to re-run: never overwrites your logs; backs up anything it replaces.
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${SAVE_SYSTEM_HOME:-$HOME/Desktop/session-logs}"
SKILLS_DIR="$HOME/.claude/skills"
COMMANDS_DIR="$HOME/.claude/commands"
STAMP=$(date +%Y%m%d-%H%M%S)

echo "Session Save System installer"
echo "  home folder: $HOME_DIR"

# 1. Skills — with collision guard (never silently overwrite an unrelated skill)
mkdir -p "$SKILLS_DIR" "$COMMANDS_DIR"
for s in session-tag session-save session-summary session-audit; do
  if [ -e "$SKILLS_DIR/$s" ] && ! grep -q "Session Save System" "$SKILLS_DIR/$s/SKILL.md" 2>/dev/null; then
    echo "  ⚠ SKIPPED skill '$s' — you already have a different skill by that name."
    echo "    (Back it up or remove it, then re-run install.)"
    continue
  fi
  mkdir -p "$SKILLS_DIR/$s"
  cp "$REPO_DIR/skills/$s/SKILL.md" "$SKILLS_DIR/$s/SKILL.md"
  echo "  installed skill: $s"
done

# 2. Commands — same guard
for c in session-tag session-save session-summary session-audit st ss ssum sa; do
  if [ -e "$COMMANDS_DIR/$c.md" ] && ! grep -q "session-" "$COMMANDS_DIR/$c.md" 2>/dev/null; then
    echo "  ⚠ skipped command /$c — you already have an unrelated $c.md"
  else
    cp "$REPO_DIR/commands/$c.md" "$COMMANDS_DIR/$c.md"
    echo "  installed command: /$c"
  fi
done

# 3. Persist the home path so skills find it at runtime (env vars don't reach Claude sessions)
printf '%s\n' "$HOME_DIR" > "$HOME/.claude/save-system-home"
echo "  home path saved to ~/.claude/save-system-home"

# 4. Home folder skeleton (never overwrite existing logs; back up a customized GUIDE)
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/audits"
if [ -f "$HOME_DIR/GUIDE.md" ] && ! cmp -s "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"; then
  cp "$HOME_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md.bak-$STAMP"
  echo "  ⚠ your customized GUIDE.md was backed up to GUIDE.md.bak-$STAMP before updating"
fi
cp "$REPO_DIR/GUIDE.md" "$HOME_DIR/GUIDE.md"
[ -f "$HOME_DIR/_INDEX.md" ] || cat > "$HOME_DIR/_INDEX.md" <<'EOF'
# Session Index
> One line per session, newest first. Read this to catch up across chats.
> 🟢 open · ✅ closed

| Date | Session | Status | Gist | Folder |
|------|---------|--------|------|--------|
EOF
[ -f "$HOME_DIR/sessions/_PROJECTS.md" ] || cat > "$HOME_DIR/sessions/_PROJECTS.md" <<'EOF'
# Projects
> Auto-built registry. The first time you tag a session about something new, /session-tag proposes a project; approved projects get one line here.
> Example of what a registered project looks like:
> - **Portfolio** — my photography portfolio website (first: 2026-07-17)
EOF

cp "$REPO_DIR/VERSION" "$HOME_DIR/.version" 2>/dev/null || true

echo ""
echo "✅ Done. Open any Claude Code session and type /session-tag (or its alias /st)"
echo "   Logs live in: $HOME_DIR"
echo "   Uninstall anytime: ./uninstall.sh (your logs are never touched)"
