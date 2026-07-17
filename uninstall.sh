#!/bin/sh
# Session Save System uninstaller — removes skills + commands. NEVER touches your logs.
set -e
SKILLS_DIR="$HOME/.claude/skills"
COMMANDS_DIR="$HOME/.claude/commands"

echo "Session Save System uninstaller"
for s in session-tag session-save session-summary session-audit; do
  if [ -e "$SKILLS_DIR/$s" ] && grep -q "Session Save System" "$SKILLS_DIR/$s/SKILL.md" 2>/dev/null; then
    rm -rf "$SKILLS_DIR/$s"; echo "  removed skill: $s"
  fi
done
for c in session-tag session-save session-summary session-audit st ss ssum sa; do
  if [ -e "$COMMANDS_DIR/$c.md" ] && grep -q "session-" "$COMMANDS_DIR/$c.md" 2>/dev/null; then
    rm -f "$COMMANDS_DIR/$c.md"; echo "  removed command: /$c"
  fi
done
rm -f "$HOME/.claude/save-system-home"
echo ""
echo "✅ Uninstalled. Your logs folder was NOT touched — it's yours, delete it manually if you want."
