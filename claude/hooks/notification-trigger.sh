#!/usr/bin/env bash
# =============================================================================
# notification-trigger.sh — PostToolUse + SubagentStop
# Routet Subagent-Resultate zu passenden Channels.
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
SUBAGENT_OUT="$STATE_DIR/last-subagent.json"

[ ! -f "$SUBAGENT_OUT" ] && exit 0

# Optional best-effort routing — wird vom subagent selbst geschrieben
NOTIFY="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/scripts/notify.sh"
if [ -x "$NOTIFY" ]; then
  SEVERITY=$(jq -r '.severity // "info"' "$SUBAGENT_OUT" 2>/dev/null || echo info)
  SUBJECT=$(jq -r '.subject // "Subagent-Update"' "$SUBAGENT_OUT" 2>/dev/null)
  BODY=$(jq -r '.body // "(no body)"' "$SUBAGENT_OUT" 2>/dev/null)
  
  bash "$NOTIFY" "$SEVERITY" "$SUBJECT" "$BODY" 2>/dev/null || true
  rm -f "$SUBAGENT_OUT"
fi
exit 0
