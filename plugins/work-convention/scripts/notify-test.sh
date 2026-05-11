#!/usr/bin/env bash
# =============================================================================
# notify-test.sh — End-to-End-Test aller Notification-Channels
# =============================================================================
set -uo pipefail

CHANNEL="${1:-all}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Load .env
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

SUBJECT="🧪 Notification-Test"
BODY="Test vom $(date) — wenn du das siehst funktioniert der Channel."

case "$CHANNEL" in
  slack)
    bash "$(dirname "$0")/notify-slack.sh" \
      "${SLACK_CHANNEL_STATUS:-empire-status}" "$SUBJECT" "$BODY" "info"
    ;;
  pushover)
    bash "$(dirname "$0")/notify-pushover.sh" "0" "$SUBJECT" "$BODY"
    ;;
  whatsapp)
    bash "$(dirname "$0")/notify-whatsapp.sh" "$SUBJECT" "$BODY"
    ;;
  all)
    echo "Testing Slack..."
    bash "$(dirname "$0")/notify-slack.sh" \
      "${SLACK_CHANNEL_STATUS:-empire-status}" "$SUBJECT" "$BODY" "info" \
      && echo "  ✅ Slack ok" || echo "  ❌ Slack fail"
    echo "Testing Pushover..."
    bash "$(dirname "$0")/notify-pushover.sh" "0" "$SUBJECT" "$BODY" \
      && echo "  ✅ Pushover ok" || echo "  ❌ Pushover fail"
    echo "Testing WhatsApp..."
    bash "$(dirname "$0")/notify-whatsapp.sh" "$SUBJECT" "$BODY" \
      && echo "  ✅ WhatsApp ok" || echo "  ⚠️  WhatsApp fail (best-effort)"
    ;;
  *)
    echo "Usage: notify-test.sh [slack|pushover|whatsapp|all]"
    exit 1
    ;;
esac
