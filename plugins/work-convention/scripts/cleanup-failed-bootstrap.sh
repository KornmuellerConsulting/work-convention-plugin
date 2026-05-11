#!/usr/bin/env bash
# =============================================================================
# cleanup-failed-bootstrap.sh — Audit-Fix #15
# =============================================================================
# Räumt nach gescheitertem Bootstrap auf — mit explizitem User-Confirm pro Step.
# =============================================================================
set -uo pipefail

NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --help)
      echo "Usage: cleanup-failed-bootstrap.sh --name <app>"
      exit 0
      ;;
    *) shift ;;
  esac
done

[ -z "$NAME" ] && { echo "❌ --name required"; exit 1; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

confirm() {
  local prompt="$1"
  read -p "  $prompt [y/N]: " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]]
}

echo "🧹 Cleanup für '$NAME' — pro Step explizites Confirm"
echo ""

# 1. Lokales Folder
MONOREPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd 2>/dev/null || echo "$PROJECT_DIR")"
APP_DIR="$MONOREPO_ROOT/apps/$NAME"
if [ -d "$APP_DIR" ]; then
  echo "1️⃣  Lokales Folder: $APP_DIR"
  if confirm "Löschen?"; then
    rm -rf "$APP_DIR"
    echo "  ✅ Folder gelöscht"
  fi
fi

# 2. ClickUp-Space
if [ -n "${CLICKUP_API_TOKEN:-}" ] && [ -n "${CLICKUP_TEAM_ID:-}" ]; then
  echo "2️⃣  ClickUp-Space '$NAME'"
  if confirm "ClickUp-Space löschen?"; then
    SPACES=$(curl -sS --max-time 5 -H "Authorization: $CLICKUP_API_TOKEN" \
      "https://api.clickup.com/api/v2/team/$CLICKUP_TEAM_ID/space?archived=false" 2>/dev/null || echo "")
    SPACE_ID=$(echo "$SPACES" | python3 -c "
import json,sys
data = json.load(sys.stdin)
for s in data.get('spaces', []):
    if s['name'].lower() == '$NAME'.lower():
        print(s['id']); break
" 2>/dev/null)
    if [ -n "$SPACE_ID" ]; then
      curl -sS -X DELETE -H "Authorization: $CLICKUP_API_TOKEN" \
        "https://api.clickup.com/api/v2/space/$SPACE_ID" >/dev/null
      echo "  ✅ Space $SPACE_ID gelöscht"
    else
      echo "  ℹ️  Space nicht gefunden"
    fi
  fi
fi

# 3. Slack-Channel
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  echo "3️⃣  Slack-Channel #${NAME}-build"
  if confirm "Channel archivieren?"; then
    CHANNEL_ID=$(curl -sS --max-time 5 -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
      "https://slack.com/api/conversations.list?types=public_channel,private_channel" \
      | python3 -c "
import json,sys
data = json.load(sys.stdin)
for c in data.get('channels', []):
    if c.get('name') == '${NAME}-build':
        print(c['id']); break
" 2>/dev/null)
    if [ -n "$CHANNEL_ID" ]; then
      curl -sS -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        --data "channel=$CHANNEL_ID" \
        "https://slack.com/api/conversations.archive" >/dev/null
      echo "  ✅ Channel archiviert"
    else
      echo "  ℹ️  Channel nicht gefunden"
    fi
  fi
fi

echo ""
echo "✅ Cleanup abgeschlossen"
echo ""
echo "Manuell zu erledigen (kann nicht automatisch):"
echo "  - Vercel-Project löschen via Dashboard"
echo "  - Supabase-Projects (Stage + Prod) löschen via Dashboard"
