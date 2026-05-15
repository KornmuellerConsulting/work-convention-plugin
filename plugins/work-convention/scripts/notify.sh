#!/usr/bin/env bash
# =============================================================================
# notify.sh — Master-Notification-Wrapper
# v1.2: Sub-Script-Lookup via ${CLAUDE_PLUGIN_ROOT} (mit $(dirname "$0") fallback).
#       Warn-loud auch bei status/info/warning (kein silent fail).
# =============================================================================
set -uo pipefail

SEVERITY="${1:-info}"
SUBJECT="${2:-(no subject)}"
BODY="${3:-(no body)}"
shift 3 || true

NO_RATE_LIMIT=0
TICKET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-rate-limit) NO_RATE_LIMIT=1; shift ;;
    --ticket) TICKET="$2"; shift 2 ;;
    *) shift ;;
  esac
done

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Sub-script lookup: prefer CLAUDE_PLUGIN_ROOT (when called from hook), fallback to sibling-dir
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/scripts" ]; then
  SCRIPT_DIR="$CLAUDE_PLUGIN_ROOT/scripts"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

STATE_DIR="$PROJECT_DIR/.claude/state"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/notify.log"

# Dedup (5min) außer bei confirm/blocker
if [ "$NO_RATE_LIMIT" -ne 1 ] && [ "$SEVERITY" != "confirm" ] && [ "$SEVERITY" != "blocker" ]; then
  HASH=$(echo "$SEVERITY|$SUBJECT" | md5sum 2>/dev/null | cut -d' ' -f1)
  HASH=${HASH:-$(echo "$SEVERITY|$SUBJECT" | md5 2>/dev/null | awk '{print $NF}')}
  DEDUP_FILE="$STATE_DIR/notify-dedup-$HASH"
  if [ -f "$DEDUP_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$DEDUP_FILE" 2>/dev/null || stat -c %Y "$DEDUP_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 300 ]; then
      exit 0  # Dedup-suppressed
    fi
  fi
  touch "$DEDUP_FILE"
fi

# Channel-Routing
case "$SEVERITY" in
  status)
    CHANNEL="${SLACK_CHANNEL_STATUS:-empire-status}"
    PUSHOVER_PRIORITY=""; WHATSAPP=0
    ;;
  info)
    CHANNEL="${SLACK_CHANNEL_APP_BUILD:-${APP_NAME:-empire}-build}"
    PUSHOVER_PRIORITY=""; WHATSAPP=0
    ;;
  warning)
    CHANNEL="${SLACK_CHANNEL_APP_BUILD:-${APP_NAME:-empire}-build}"
    PUSHOVER_PRIORITY="0"; WHATSAPP=0
    ;;
  blocker)
    CHANNEL="${SLACK_CHANNEL_BLOCKERS:-empire-blockers}"
    PUSHOVER_PRIORITY="1"; WHATSAPP=1
    ;;
  confirm)
    CHANNEL="${SLACK_CHANNEL_BLOCKERS:-empire-blockers}"
    PUSHOVER_PRIORITY="2"; WHATSAPP=1
    ;;
  *)
    CHANNEL="${SLACK_CHANNEL_APP_BUILD:-${APP_NAME:-empire}-build}"
    PUSHOVER_PRIORITY=""; WHATSAPP=0
    ;;
esac

# Slack
SLACK_OK=0
SLACK_ERR=""
if [ -x "$SCRIPT_DIR/notify-slack.sh" ]; then
  SLACK_ERR=$(bash "$SCRIPT_DIR/notify-slack.sh" "$CHANNEL" "$SUBJECT" "$BODY" "$SEVERITY" 2>&1)
  if [ $? -eq 0 ]; then
    SLACK_OK=1
  fi
fi

# Pushover
PUSHOVER_OK=0
if [ -n "$PUSHOVER_PRIORITY" ] && [ -x "$SCRIPT_DIR/notify-pushover.sh" ]; then
  if bash "$SCRIPT_DIR/notify-pushover.sh" "$PUSHOVER_PRIORITY" "$SUBJECT" "$BODY" 2>/dev/null; then
    PUSHOVER_OK=1
  fi
fi

# WhatsApp
WA_OK=0
if [ "$WHATSAPP" -eq 1 ] && [ -x "$SCRIPT_DIR/notify-whatsapp.sh" ]; then
  if NO_DEDUP=1 bash "$SCRIPT_DIR/notify-whatsapp.sh" "$SUBJECT" "$BODY" 2>/dev/null; then
    WA_OK=1
  fi
fi

# Log
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | severity=$SEVERITY | app=${APP_NAME:-?} | operator=${CURRENT_OPERATOR:-?} | subject=$SUBJECT | slack=$SLACK_OK pushover=$PUSHOVER_OK whatsapp=$WA_OK" >> "$LOG"

# Fail-loud bei blocker/confirm wenn ALLE Channels fail
if [ "$SEVERITY" = "blocker" ] || [ "$SEVERITY" = "confirm" ]; then
  if [ "$SLACK_OK" -eq 0 ] && [ "$PUSHOVER_OK" -eq 0 ] && [ "$WA_OK" -eq 0 ]; then
    echo "🚨 KRITISCH: Notification ($SEVERITY) konnte über KEINEN Channel gesendet werden!" >&2
    echo "    Subject: $SUBJECT" >&2
    echo "    Slack-Fehler: $SLACK_ERR" >&2
    echo "    Check Tokens in .env: SLACK_BOT_TOKEN, PUSHOVER_*, CALLMEBOT_*" >&2
    exit 2
  fi
fi

# Warn (kein hard-fail) bei status/info/warning wenn Slack failed
if [ "$SLACK_OK" -eq 0 ] && [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  echo "⚠️  notify.sh: Slack-Send fehlgeschlagen ($SEVERITY/$SUBJECT)" >&2
  [ -n "$SLACK_ERR" ] && echo "    $SLACK_ERR" >&2
fi

exit 0
