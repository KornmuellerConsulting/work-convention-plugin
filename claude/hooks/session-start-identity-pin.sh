#!/usr/bin/env bash
# =============================================================================
# session-start-identity-pin.sh — SessionStart
# Pinnt Operator + Worktree + Branch in .claude/state/session-identity.json
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"

OPERATOR="${CURRENT_OPERATOR:-unknown}"
WORKTREE="$(pwd)"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
HEAD="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$STATE_DIR/session-identity.json" <<JSON
{
  "operator": "$OPERATOR",
  "worktree": "$WORKTREE",
  "branch": "$BRANCH",
  "head": "$HEAD",
  "session_start": "$TIMESTAMP"
}
JSON

echo "🔐 Identity pinned: $OPERATOR @ $BRANCH ($HEAD)"
