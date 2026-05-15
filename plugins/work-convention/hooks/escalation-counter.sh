#!/usr/bin/env bash
# =============================================================================
# escalation-counter.sh — PostToolUse
# Zählt Tool-Fails. Bei 3+ → Hard-Trigger-Flag.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Workaround: not every tool has exit_code in tool_response.
# For Bash, tool_response has "stdout", "stderr", "interrupted".
# Heuristic: if tool_response has "is_error" or interrupted = true → count as fail.
if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
  IS_ERROR=$(echo "$INPUT" | jq -r '.tool_response.is_error // false' 2>/dev/null)
  INTERRUPTED=$(echo "$INPUT" | jq -r '.tool_response.interrupted // false' 2>/dev/null)
  if [ "$IS_ERROR" = "true" ] || [ "$INTERRUPTED" = "true" ]; then
    EXIT_CODE=1
  fi
fi

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"
COUNTER_FILE="$STATE_DIR/escalation-counter.state"
FLAG_FILE="$STATE_DIR/escalation-3fail.flag"

if [ "$EXIT_CODE" != "0" ] && [ "$EXIT_CODE" != "null" ]; then
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
  if [ -f "$COUNTER_FILE" ]; then
    rm -f "$COUNTER_FILE" "$FLAG_FILE" "$STATE_DIR/solver-activated.flag" 2>/dev/null || true
  fi
fi
exit 0
