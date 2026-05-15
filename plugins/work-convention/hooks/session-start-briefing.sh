#!/usr/bin/env bash
# =============================================================================
# session-start-briefing.sh — SessionStart
# Lädt CLAUDE.md, STATUS.md, BLOCKERS.md, Reviewer-Findings ins Context.
# =============================================================================
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"

# v1.2.1: source .env so per-project vars (CURRENT_OPERATOR, APP_NAME, …) are available
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
fi

cat <<MSG
═══════════════════════════════════════════════════════
  Session-Briefing
═══════════════════════════════════════════════════════

Operator: ${CURRENT_OPERATOR:-(unbekannt — setze CURRENT_OPERATOR in .env)}
App: ${APP_NAME:-(unbekannt)}
Worktree: $(pwd)
Branch: $(git branch --show-current 2>/dev/null || echo "?")

Konstitution: CLAUDE.md
Status: STATUS.md
Blocker: BLOCKERS.md (manuell gepflegt)
Decisions: DECISIONS.md (Append-Only)
MSG

# Reviewer-Findings einblenden falls vorhanden
if [ -f "$STATE_DIR/reviewer-finding.md" ]; then
  echo ""
  echo "📋 Reviewer-Finding offen:"
  cat "$STATE_DIR/reviewer-finding.md"
fi

# Hard-Trigger?
if [ -f "$STATE_DIR/escalation-3fail.flag" ]; then
  echo ""
  echo "🚨 HARD-TRIGGER aktiv. Solver-Subagent erforderlich bevor weitergearbeitet wird."
fi
exit 0
