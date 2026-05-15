#!/usr/bin/env bash
# =============================================================================
# precommit-ticket-id-required.sh — git pre-commit hook (NICHT Claude-Code-Hook)
# Erzwingt Conventional-Commit + Ticket-ID.
# v1.2: läuft als echter git-Hook via core.hooksPath.
# =============================================================================
set -uo pipefail

# git pre-commit übergibt die Commit-Message via .git/COMMIT_EDITMSG
# (genauer: commit-msg-hook bekommt sie als $1, aber wir nutzen den early-fail-Pfad)
MSG_FILE="${1:-.git/COMMIT_EDITMSG}"
[ ! -f "$MSG_FILE" ] && exit 0

MSG=$(head -1 "$MSG_FILE")
[ -z "$MSG" ] && exit 0

# Skip Merge-Commits, Reverts, Initial-Commits
echo "$MSG" | grep -qE '^(Merge|Revert)' && exit 0
[ "$MSG" = "Initial commit" ] && exit 0

if ! echo "$MSG" | grep -qE '^(feat|fix|chore|docs|refactor|test|perf|style)\([A-Z]+-[0-9]+\)!?:.+'; then
  cat <<HELP >&2
🚫 BLOCKED: Commit-Message folgt nicht Conventional-Commit + Ticket-ID.

Format:
  <type>(<PREFIX>-<nr>): <description>
  <type>(<PREFIX>-<nr>)!: <description>   (breaking change)

Beispiele:
  feat(EXAMPLE-42): add login form
  fix(EXAMPLE-43): handle empty email
  chore(EXAMPLE-44)!: bump major deps

Erlaubte Types: feat, fix, chore, docs, refactor, test, perf, style
HELP
  exit 1
fi
exit 0
