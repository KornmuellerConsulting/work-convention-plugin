#!/usr/bin/env bash
# =============================================================================
# post-bash-head-record.sh — PostToolUse:Bash
# Speichert aktuellen HEAD nach jedem Bash-Tool-Use.
# =============================================================================
set -euo pipefail
STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"
git rev-parse HEAD 2>/dev/null > "$STATE_DIR/last-head.txt" || true
exit 0
