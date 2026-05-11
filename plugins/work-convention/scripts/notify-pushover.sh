#!/usr/bin/env bash
# =============================================================================
# notify-pushover.sh — Push an beide Co-Founder
# =============================================================================
set -uo pipefail

PRIORITY="${1:-0}"
SUBJECT="${2:-}"
BODY="${3:-}"

if [ -z "${PUSHOVER_APP_TOKEN:-}" ]; then
  echo "⚠️  PUSHOVER_APP_TOKEN nicht gesetzt" >&2
  exit 1
fi

ANY_OK=0

for var in PUSHOVER_USER_PATRICK PUSHOVER_USER_JUSTIN; do
  USER_KEY="${!var:-}"
  [ -z "$USER_KEY" ] && continue
  
  ARGS=(
    -F "token=$PUSHOVER_APP_TOKEN"
    -F "user=$USER_KEY"
    -F "title=$SUBJECT"
    -F "message=$BODY"
    -F "priority=$PRIORITY"
  )
  
  # P2 braucht retry/expire
  if [ "$PRIORITY" = "2" ]; then
    ARGS+=(-F "retry=60" -F "expire=3600")
  fi
  
  RESPONSE=$(curl -sS "${ARGS[@]}" "https://api.pushover.net/1/messages.json" 2>/dev/null || echo "")
  STATUS=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status', 0))" 2>/dev/null || echo 0)
  
  if [ "$STATUS" = "1" ]; then
    ANY_OK=1
  fi
done

[ "$ANY_OK" -eq 1 ] && exit 0 || exit 1
