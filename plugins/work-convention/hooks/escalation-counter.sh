#!/usr/bin/env bash
# =============================================================================
# escalation-counter.sh — PostToolUse
# Audit-Fix #1: Echte Hard-Trigger-Implementation.
# Zählt Tool-Fails. Bei 3+ → Hard-Trigger-Flag schreiben.
# Auto-Reset bei erfolgreichem Tool-Use (Audit-Fix #16).
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"
COUNTER_FILE="$STATE_DIR/escalation-counter.state"
FLAG_FILE="$STATE_DIR/escalation-3fail.flag"

EXIT_CODE="${CLAUDE_TOOL_OUTPUT_exit_code:-0}"
TOOL="${CLAUDE_TOOL_NAME:-}"

# Counter-Logic
if [ "$EXIT_CODE" != "0" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
  COUNT=$((COUNT + 1))
  echo "$COUNT" > "$COUNTER_FILE"
  
  if [ "$COUNT" -ge 3 ] && [ ! -f "$FLAG_FILE" ]; then
    cat > "$FLAG_FILE" <<JSON
{
  "trigger_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "fail_count": $COUNT,
  "last_tool": "$TOOL"
}
JSON
    echo "🚨 HARD-TRIGGER aktiv: $COUNT Fails — Solver-Subagent erforderlich" >&2
  fi
else
  # Auto-Reset bei Success
  if [ -f "$COUNTER_FILE" ]; then
    rm -f "$COUNTER_FILE" "$FLAG_FILE" "$STATE_DIR/solver-activated.flag" 2>/dev/null || true
  fi
fi
exit 0
