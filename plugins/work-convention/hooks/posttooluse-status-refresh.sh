#!/usr/bin/env bash
# =============================================================================
# posttooluse-status-refresh.sh — PostToolUse
# Aktualisiert STATUS.md (throttled 1×/Min).
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"
THROTTLE="$STATE_DIR/last-status-refresh.timestamp"

NOW=$(date +%s)
LAST=$(cat "$THROTTLE" 2>/dev/null || echo 0)
DIFF=$((NOW - LAST))

[ "$DIFF" -lt 60 ] && exit 0
echo "$NOW" > "$THROTTLE"

GENERATOR="${CLAUDE_PLUGIN_ROOT:-}/scripts/status-generate.py"
if [ -f "$GENERATOR" ]; then
  python3 "$GENERATOR" --mode markdown > "${CLAUDE_PROJECT_DIR:-$(pwd)}/STATUS.md" 2>/dev/null || true
fi
exit 0
