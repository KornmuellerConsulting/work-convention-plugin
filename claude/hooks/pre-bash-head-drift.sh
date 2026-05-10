#!/usr/bin/env bash
# =============================================================================
# pre-bash-head-drift.sh — PreToolUse:Bash
# Warnt wenn HEAD seit letztem Tool-Use gedriftet ist (extern checked out).
# =============================================================================
set -euo pipefail

STATE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state/last-head.txt"
[ ! -f "$STATE" ] && exit 0

LAST=$(cat "$STATE" 2>/dev/null)
NOW=$(git rev-parse HEAD 2>/dev/null || echo "")

if [ -n "$LAST" ] && [ -n "$NOW" ] && [ "$LAST" != "$NOW" ]; then
  cat <<MSG >&2
⚠️  HEAD-Drift erkannt.
  Letzter Stand: $LAST
  Jetzt:         $NOW

Wahrscheinlich wurde extern ge-rebase'd, ge-checkout'd oder gepullt.
Verify mit: git log --oneline -5
MSG
fi
exit 0
