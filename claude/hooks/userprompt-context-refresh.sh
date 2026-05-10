#!/usr/bin/env bash
# =============================================================================
# userprompt-context-refresh.sh — UserPromptSubmit
# Injiziert Hard-Trigger-Hint, Reviewer-Findings, Status-Snippets.
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"

if [ -f "$STATE_DIR/escalation-3fail.flag" ]; then
  echo ""
  echo "🚨 [Reminder] Hard-Trigger aktiv — Solver-Subagent erforderlich."
fi

if [ -f "$STATE_DIR/reviewer-finding.md" ]; then
  echo ""
  echo "📋 [Reviewer-Finding offen — siehe state/reviewer-finding.md]"
fi
exit 0
