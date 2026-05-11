#!/usr/bin/env bash
# =============================================================================
# stop-completeness.sh — Stop
# Diagnose: gibt es ungelöste Issues / unfertige Edits?
# =============================================================================
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"

WARNINGS=()

# Uncommitted changes?
if [ -d "$PROJECT_DIR/.git" ]; then
  CHANGES=$(cd "$PROJECT_DIR" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CHANGES" -gt 0 ]; then
    WARNINGS+=("$CHANGES uncommitted changes")
  fi
fi

# Hard-Trigger noch aktiv?
if [ -f "$STATE_DIR/escalation-3fail.flag" ]; then
  WARNINGS+=("Hard-Trigger aktiv — Solver-Subagent nicht abgeschlossen?")
fi

# Open Blockers?
if [ -f "$PROJECT_DIR/BLOCKERS.md" ]; then
  OPEN=$(grep -c "^- " "$PROJECT_DIR/BLOCKERS.md" 2>/dev/null || echo 0)
  if [ "$OPEN" -gt 0 ]; then
    WARNINGS+=("$OPEN offene Blocker in BLOCKERS.md")
  fi
fi

if [ "${#WARNINGS[@]}" -gt 0 ]; then
  echo "" >&2
  echo "⚠️  Session-Ende — ungelöste Issues:" >&2
  for w in "${WARNINGS[@]}"; do echo "  - $w" >&2; done
fi
exit 0
