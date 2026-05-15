#!/usr/bin/env bash
# =============================================================================
# pre-edit-plugin-files.sh — PreToolUse:Edit/Write
# Blockt direkte Edits in App-lokalen .claude/plugin-folders.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

# Erlaubte App-lokale Files
case "$FILE" in
  *.claude/settings.local.json) exit 0 ;;
  *.claude/state/*) exit 0 ;;
  *.claude/app.json) exit 0 ;;
  *.claude/hooks/diag-*) exit 0 ;;  # Diagnose-Hooks dürfen lokal sein
esac

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
    exit 2
  fi
done
exit 0
