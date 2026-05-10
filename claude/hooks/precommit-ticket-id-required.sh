#!/usr/bin/env bash
# =============================================================================
# precommit-ticket-id-required.sh — PreCommit
# Erzwingt Conventional-Commit + Ticket-ID.
# =============================================================================
set -euo pipefail

MSG="${CLAUDE_TOOL_INPUT_message:-}"
[ -z "$MSG" ] && MSG=$(cat .git/COMMIT_EDITMSG 2>/dev/null || echo "")
[ -z "$MSG" ] && exit 0

# Pattern: type(TICKET-NR): description
if ! echo "$MSG" | head -1 | grep -qE '^(feat|fix|chore|docs|refactor|test|perf|style)\([A-Z]+-[0-9]+\):.+'; then
  cat <<HELP >&2
🚫 BLOCKED: Commit-Message folgt nicht Conventional-Commit + Ticket-ID.

Format:
  <type>(<PREFIX>-<nr>): <description>

Beispiele:
  feat(EXAMPLE-42): add login form
  fix(EXAMPLE-43): handle empty email
  chore(EXAMPLE-44): bump dependencies

Erlaubte Types: feat, fix, chore, docs, refactor, test, perf, style
HELP
  exit 1
fi
exit 0
