#!/usr/bin/env bash
# =============================================================================
# notify-slack.sh — Slack via chat.postMessage (Audit-Fix #5)
# =============================================================================
set -uo pipefail

CHANNEL="${1:?Channel required}"
SUBJECT="${2:-}"
BODY="${3:-}"
SEVERITY="${4:-info}"

if [ -z "${SLACK_BOT_TOKEN:-}" ]; then
  echo "⚠️  SLACK_BOT_TOKEN nicht gesetzt" >&2
  exit 1
fi

# Bei blocker/confirm — Mention beider Co-Founder
MENTIONS=""
if [ "$SEVERITY" = "blocker" ] || [ "$SEVERITY" = "confirm" ]; then
  [ -n "${SLACK_USER_PATRICK:-}" ] && MENTIONS="<@$SLACK_USER_PATRICK> "
  [ -n "${SLACK_USER_JUSTIN:-}" ] && MENTIONS="${MENTIONS}<@$SLACK_USER_JUSTIN>"
fi

# Severity-Emoji
case "$SEVERITY" in
  status)  EMOJI="📊" ;;
  info)    EMOJI="ℹ️" ;;
  warning) EMOJI="⚠️" ;;
  blocker) EMOJI="🚨" ;;
  confirm) EMOJI="🔥" ;;
  *)       EMOJI="•" ;;
esac

TEXT="${MENTIONS:+${MENTIONS}\n}$EMOJI *${SUBJECT}*\n${BODY}"

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
  'channel': '$CHANNEL',
  'text': '''$TEXT''',
  'unfurl_links': False,
  'unfurl_media': False
}))
")

RESPONSE=$(curl -sS -X POST \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data "$PAYLOAD" \
  "https://slack.com/api/chat.postMessage")

OK=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null || echo "False")

if [ "$OK" = "True" ]; then
  exit 0
else
  ERROR=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null || echo "parse_error")
  echo "Slack-Error: $ERROR" >&2
  exit 1
fi
