#!/usr/bin/env bash
# =============================================================================
# userprompt-todo-reminder.sh — UserPromptSubmit
# Reminder zur TodoWrite-Nutzung bei Multi-Step-Prompts.
# =============================================================================
set -euo pipefail

PROMPT="${CLAUDE_USER_PROMPT:-}"
[ -z "$PROMPT" ] && exit 0

# Heuristik: "und", "dann", Listenformate
INDICATORS=$(echo "$PROMPT" | grep -oiE '\b(und|dann|danach|außerdem|sowie|außerdem)\b|^[0-9]\.|^- ' | wc -l | tr -d ' ')

if [ "$INDICATORS" -ge 3 ]; then
  echo ""
  echo "💡 [Hint] Multi-Step-Prompt erkannt. Erwäge: TodoWrite für Übersicht."
fi
exit 0
