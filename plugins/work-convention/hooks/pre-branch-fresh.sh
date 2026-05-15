#!/usr/bin/env bash
# =============================================================================
# pre-branch-fresh.sh — git pre-push hook
# Verhindert Push wenn local hinter origin/main ist.
# v1.2: läuft als echter git-Hook.
# =============================================================================
set -uo pipefail

git fetch origin main --quiet 2>/dev/null || true

LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "")
BASE=$(git merge-base @ origin/main 2>/dev/null || echo "")

[ -z "$REMOTE" ] && exit 0

if [ "$LOCAL" = "$REMOTE" ]; then
  exit 0
elif [ "$LOCAL" = "$BASE" ]; then
  cat <<MSG >&2
🚫 BLOCKED: Lokal hinter origin/main.

Lösung:
  git pull --rebase origin main
  # Konflikte? Lösen, dann:
  git rebase --continue
  git push origin main
MSG
  exit 1
elif [ "$REMOTE" = "$BASE" ]; then
  # Local ist vor remote (fast-forward möglich) — ok
  exit 0
else
  cat <<MSG >&2
⚠️  WARNING: Local und remote sind diverged.

LOCAL:  $LOCAL
REMOTE: $REMOTE
BASE:   $BASE

Lösung:
  git pull --rebase origin main
  (oder fix conflicts manuell)
MSG
  exit 1
fi
