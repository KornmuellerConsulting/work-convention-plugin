#!/usr/bin/env bash
# =============================================================================
# pre-edit-plugin-files.sh — PreToolUse:Edit/Write
# Blockt direkte Edits in App-lokalen .claude/plugin-folders.
# v1.3: settings.json ist jetzt key-scoped statt file-scoped geblockt —
#       nur echte Plugin-Wiring-Keys (enabledPlugins, extraKnownMarketplaces)
#       sind geschützt. Generische Settings (advisorModel, theme, ...) sind
#       kein Plugin-Wiring und werden frei durchgelassen.
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

# settings.json: nur Plugin-Wiring-Keys schützen, alles andere ist generische
# Claude-Code-Config und darf frei editiert werden.
if [[ "$FILE" == *".claude/settings.json"* ]]; then
  PROTECTED_KEYS=("enabledPlugins" "extraKnownMarketplaces")
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  BLOCK_REASON=""

  if [ "$TOOL_NAME" = "Write" ]; then
    # Write ersetzt die ganze Datei — geschützte Keys gegen aktuellen Stand diffen
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
    for key in "${PROTECTED_KEYS[@]}"; do
      OLD_VAL=$(jq -c ".${key} // null" "$FILE" 2>/dev/null)
      NEW_VAL=$(echo "$NEW_CONTENT" | jq -c ".${key} // null" 2>/dev/null)
      if [ "$OLD_VAL" != "$NEW_VAL" ]; then
        BLOCK_REASON="Write ändert geschützten Key '$key'"
        break
      fi
    done
  else
    # Edit: geänderte Fragmente auf geschützte Key-Namen prüfen
    OLD_STR=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
    NEW_STR=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
    for key in "${PROTECTED_KEYS[@]}"; do
      if echo "${OLD_STR}${NEW_STR}" | grep -q "\"$key\""; then
        BLOCK_REASON="Edit berührt geschützten Key '$key'"
        break
      fi
    done
  fi

  if [ -n "$BLOCK_REASON" ]; then
    cat <<MSG >&2
🚫 BLOCKED: $BLOCK_REASON ($FILE)

Plugin-Wiring-Keys (enabledPlugins, extraKnownMarketplaces) werden über
offizielle Plugin-Commands gepflegt (claude plugin install/enable/marketplace),
nicht per Hand editiert:
  https://github.com/KornmuellerConsulting/work-convention-plugin

Generische Settings (advisorModel, theme, agentPushNotifEnabled, ...) sind
kein Plugin-Wiring und dürfen frei editiert werden.
MSG
    exit 2
  fi
  exit 0
fi

BLOCKED_PATTERNS=(
  ".claude/hooks/"
  ".claude/agents/"
  ".claude/skills/"
  ".claude/commands/"
  ".claude/scripts/"
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
