#!/usr/bin/env bash
# =============================================================================
# userprompt-reviewer-trigger.sh — UserPromptSubmit
# Audit-Fix #2: Triggert Reviewer-Subagent-Hint alle 30 Min.
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"
LAST="$STATE_DIR/last-reviewer-run.timestamp"

NOW=$(date +%s)
LAST_RUN=$(cat "$LAST" 2>/dev/null || echo 0)
DIFF=$((NOW - LAST_RUN))
INTERVAL=1800  # 30 Min

if [ "$DIFF" -ge "$INTERVAL" ]; then
  echo ""
  echo "🔍 [Reviewer-Hint] 30+ Min seit letztem Drift-Check. Erwäge:"
  echo "     'Aktiviere Reviewer-Subagent für aktuelle Session'"
  echo "$NOW" > "$LAST"
fi
exit 0
