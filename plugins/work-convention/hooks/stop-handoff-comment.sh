#!/usr/bin/env bash
# =============================================================================
# stop-handoff-comment.sh — Stop
# Postet Hand-off-Comment im aktuellen ClickUp-Task.
# =============================================================================
set -euo pipefail

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
ACTIVE_TICKET="$STATE_DIR/active-ticket.txt"

# v1.2.3: source .env so CURRENT_OPERATOR, CLICKUP_* vars are available.
# bash -n guard + skip-on-error: a single quoting bug in .env
# (e.g. ")" in a password) must not kill the whole hand-off-post.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if [ -f "$PROJECT_DIR/.env" ] && bash -n "$PROJECT_DIR/.env" 2>/dev/null; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env" 2>/dev/null || true
  set +a
fi

[ ! -f "$ACTIVE_TICKET" ] && exit 0
TICKET=$(cat "$ACTIVE_TICKET" 2>/dev/null)
[ -z "$TICKET" ] && exit 0

CLICKUP_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/clickup-spiegel.py"
[ ! -f "$CLICKUP_SCRIPT" ] && exit 0

OPERATOR="${CURRENT_OPERATOR:-unknown}"
BRANCH=$(git branch --show-current 2>/dev/null || echo "?")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

BODY=$(cat <<MSG
**Session-Hand-off** ($OPERATOR @ $TIMESTAMP)

- Branch: \`$BRANCH\`
- HEAD: \`$HEAD\`
- Status: $(cat "${CLAUDE_PROJECT_DIR:-$(pwd)}/STATUS.md" 2>/dev/null | head -20 || echo 'STATUS.md nicht verfügbar')
MSG
)

python3 "$CLICKUP_SCRIPT" comment --ticket "$TICKET" --body "$BODY" 2>/dev/null || true
exit 0
