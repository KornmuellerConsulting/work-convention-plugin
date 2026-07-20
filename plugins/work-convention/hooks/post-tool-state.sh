#!/usr/bin/env bash
# =============================================================================
# post-tool-state.sh — PostToolUse (v2.0: konsolidierter Dispatcher)
#
# Ersetzt zwei Einzel-Hooks:
#   1. Eskalations-Counter (alle Tools): zählt Fails, setzt Hard-Trigger bei 3+
#   2. HEAD-Record (nur Bash): merkt sich HEAD für die Drift-Warnung
# =============================================================================
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"
mkdir -p "$STATE_DIR"

INPUT=$(cat 2>/dev/null || echo '{}')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)
# jq auf leerem/kaputtem Input liefert Leerstring — das ist kein Fail,
# sonst zählt jeder Hook-Aufruf ohne parsebares JSON den Counter hoch.
[ -z "$EXIT_CODE" ] && EXIT_CODE=0

# Nicht jedes Tool liefert exit_code — Bash liefert stdout/stderr/interrupted.
if [ "$EXIT_CODE" = "0" ] || [ "$EXIT_CODE" = "null" ]; then
  IS_ERROR=$(echo "$INPUT" | jq -r '.tool_response.is_error // false' 2>/dev/null)
  INTERRUPTED=$(echo "$INPUT" | jq -r '.tool_response.interrupted // false' 2>/dev/null)
  if [ "$IS_ERROR" = "true" ] || [ "$INTERRUPTED" = "true" ]; then
    EXIT_CODE=1
  fi
fi

# --- 1. Eskalations-Counter --------------------------------------------------
COUNTER_FILE="$STATE_DIR/escalation-counter.state"
FLAG_FILE="$STATE_DIR/escalation-3fail.flag"

if [ "$EXIT_CODE" != "0" ] && [ "$EXIT_CODE" != "null" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
  case "$COUNT" in (*[!0-9]*|"") COUNT=0 ;; esac
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

# --- 2. HEAD-Record (nur nach Bash) -----------------------------------------
if [ "$TOOL" = "Bash" ]; then
  git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null > "$STATE_DIR/last-head.txt" || true
fi

exit 0
