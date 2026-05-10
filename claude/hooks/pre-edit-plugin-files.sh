#!/usr/bin/env bash
# =============================================================================
# pre-edit-plugin-files.sh — PreToolUse:Edit/Write
# Blockt direkte Edits in .claude/{hooks,agents,skills,commands,scripts,settings.json}.
# Plugin-Updates gehen nur über Plugin-Repo.
# =============================================================================
set -euo pipefail

FILE="${CLAUDE_TOOL_INPUT_file_path:-}"
[ -z "$FILE" ] && exit 0

# Erlaubte App-lokale Files
case "$FILE" in
  *.claude/settings.local.json) exit 0 ;;
  *.claude/state/*) exit 0 ;;
  *.claude/app.json) exit 0 ;;
esac

# Geblockte Plugin-Files
BLOCKED_PATTERNS=(
  ".claude/hooks/"
  ".claude/agents/"
  ".claude/skills/"
  ".claude/commands/"
  ".claude/scripts/"
  ".claude/settings.json"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    cat <<MSG >&2
🚫 BLOCKED: Direkter Edit von Plugin-File: $FILE

Plugin-Files werden über das Plugin-Repo gepflegt:
  https://github.com/KornmuellerConsulting/work-convention-plugin

App-lokale Anpassungen:
  - Settings: .claude/settings.local.json (überschreibt Plugin-Wiring)
  - App-Config: .claude/app.json
  - Plugin-PR: editiere Plugin-Repo, dann claude plugin update
MSG
    exit 1
  fi
done
exit 0
