#!/usr/bin/env bash
# =============================================================================
# pre-bash-escalation-block.sh — PreToolUse:Bash
# Hard-Block bei Fail #4 ohne Solver-Aktivierung.
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
COUNTER_FILE="$STATE_DIR/escalation-counter.state"
SOLVER_FLAG="$STATE_DIR/solver-activated.flag"

[ ! -f "$COUNTER_FILE" ] && exit 0

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -ge 4 ] && [ ! -f "$SOLVER_FLAG" ]; then
  cat <<MSG >&2
🚫 HARD-BLOCK: $COUNT aufeinanderfolgende Fails.

Solver-Subagent muss aktiviert werden bevor weitergearbeitet wird.

Aktivierung: Sag im Prompt:
  "Aktiviere Solver-Subagent für [Problem-Beschreibung]"

Reset (nur wenn bewusst):
  /escalate reset
MSG
  exit 1
fi
exit 0
