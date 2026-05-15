#!/usr/bin/env bash
# =============================================================================
# userprompt-todo-reminder.sh — UserPromptSubmit
# Reminder zur TodoWrite-Nutzung bei Multi-Step-Prompts.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // .prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

INDICATORS=$(echo "$PROMPT" | grep -oiE '\b(und|dann|danach|außerdem|sowie)\b|^[0-9]\.|^- ' | wc -l | tr -d ' ')

if [ "$INDICATORS" -ge 3 ]; then
  echo ""
  echo "💡 [Hint] Multi-Step-Prompt erkannt. Erwäge: TodoWrite für Übersicht."
fi
exit 0
