#!/usr/bin/env bash
# =============================================================================
# notify-whatsapp.sh — CallMeBot WhatsApp (best-effort, Audit-Fix #9)
# =============================================================================
set -uo pipefail

SUBJECT="${1:-}"
BODY="${2:-}"

ANY_OK=0
STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"

for person in PATRICK JUSTIN; do
  PHONE_VAR="CALLMEBOT_PHONE_$person"
  KEY_VAR="CALLMEBOT_APIKEY_$person"
  PHONE="${!PHONE_VAR:-}"
  KEY="${!KEY_VAR:-}"
  
  [ -z "$PHONE" ] && continue
  [ -z "$KEY" ] && continue
  
  # Rate-Limit pro Empfänger (30 Min)
  RATE_FILE="$STATE_DIR/wa-rate-$person.timestamp"
  NOW=$(date +%s)
  LAST=$(cat "$RATE_FILE" 2>/dev/null || echo 0)
  if [ $((NOW - LAST)) -lt 1800 ]; then
    continue  # Skip — too soon
  fi
  
  MESSAGE="${SUBJECT}: ${BODY}"
  ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$MESSAGE")
  
  RESPONSE=$(curl -sS --max-time 10 \
    "https://api.callmebot.com/whatsapp.php?phone=$PHONE&text=$ENCODED&apikey=$KEY" 2>/dev/null || echo "")
  
  if echo "$RESPONSE" | grep -qi "Message queued"; then
    ANY_OK=1
    echo "$NOW" > "$RATE_FILE"
  fi
done

[ "$ANY_OK" -eq 1 ] && exit 0 || exit 1
