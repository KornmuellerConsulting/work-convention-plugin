#!/usr/bin/env bash
# =============================================================================
# notify-whatsapp.sh — CallMeBot WhatsApp (best-effort)
# v1.2: 5-Min Subject-Hash-Dedup statt 30-Min global Cooldown.
#       Bei severity=blocker (env NO_DEDUP=1) gar kein Dedup.
# =============================================================================
set -uo pipefail

SUBJECT="${1:-}"
BODY="${2:-}"
NO_DEDUP="${NO_DEDUP:-0}"

ANY_OK=0
STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state"
mkdir -p "$STATE_DIR"

# Subject-Hash für targeted Dedup (statt globalem Rate-Limit)
HASH=$(echo "$SUBJECT" | md5sum 2>/dev/null | cut -d' ' -f1)
HASH=${HASH:-$(echo "$SUBJECT" | md5 2>/dev/null | awk '{print $NF}')}
HASH="${HASH:0:12}"

for person in PATRICK JUSTIN; do
  PHONE_VAR="CALLMEBOT_PHONE_$person"
  KEY_VAR="CALLMEBOT_APIKEY_$person"
  PHONE="${!PHONE_VAR:-}"
  KEY="${!KEY_VAR:-}"
  
  [ -z "$PHONE" ] && continue
  [ -z "$KEY" ] && continue
  
  # Subject-Hash Dedup: 5min cooldown nur für identische Subjects pro Empfänger
  if [ "$NO_DEDUP" != "1" ]; then
    RATE_FILE="$STATE_DIR/wa-rate-$person-$HASH.timestamp"
    NOW=$(date +%s)
    LAST=$(cat "$RATE_FILE" 2>/dev/null || echo 0)
    if [ $((NOW - LAST)) -lt 300 ]; then
      continue  # gleiches Subject vor < 5min an diesen Empfänger
    fi
  fi
  
  MESSAGE="${SUBJECT}: ${BODY}"
  ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$MESSAGE")
  
  RESPONSE=$(curl -sS --max-time 10 \
    "https://api.callmebot.com/whatsapp.php?phone=$PHONE&text=$ENCODED&apikey=$KEY" 2>/dev/null || echo "")
  
  if echo "$RESPONSE" | grep -qi "Message queued"; then
    ANY_OK=1
    [ "$NO_DEDUP" != "1" ] && echo "$NOW" > "$RATE_FILE"
  fi
done

[ "$ANY_OK" -eq 1 ] && exit 0 || exit 1
