#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh — End-to-End-Verify aller Plugin-Komponenten (v1.1+)
# =============================================================================
set -uo pipefail

APP_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -f "$APP_DIR/.env" ] && { set -a; source "$APP_DIR/.env"; set +a; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "═══ Plugin-Files (Plugin-Cache) ═══"
[ -f "$SCRIPT_DIR/notify.sh" ] && ok "notify.sh" || fail "notify.sh missing"
[ -f "$SCRIPT_DIR/notify-slack.sh" ] && ok "notify-slack.sh" || fail "notify-slack.sh missing"
[ -f "$SCRIPT_DIR/clickup-spiegel.py" ] && ok "clickup-spiegel.py" || fail "clickup-spiegel.py missing"

PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_COUNT=$(find "$PARENT_DIR/hooks" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$HOOKS_COUNT" -ge 19 ] && ok "$HOOKS_COUNT Hooks installiert" || warn "$HOOKS_COUNT Hooks (erwartet ≥19)"

[ -d "$PARENT_DIR/agents" ] && ok "agents/ dir" || fail "agents/ missing"
[ -d "$PARENT_DIR/commands" ] && ok "commands/ dir" || fail "commands/ missing"

echo ""
echo "═══ App-Config (.env in $APP_DIR) ═══"
[ -f "$APP_DIR/.env" ] && ok ".env vorhanden" || warn ".env fehlt — cp .env.example .env"
[ -n "${APP_NAME:-}" ] && ok "APP_NAME=$APP_NAME" || fail "APP_NAME nicht gesetzt"
[ -n "${APP_PROJECT_PREFIX:-}" ] && ok "APP_PROJECT_PREFIX=$APP_PROJECT_PREFIX" || fail "APP_PROJECT_PREFIX nicht gesetzt"
if [ "${CURRENT_OPERATOR:-}" = "patrick" ] || [ "${CURRENT_OPERATOR:-}" = "justin" ]; then
  ok "CURRENT_OPERATOR=$CURRENT_OPERATOR"
else
  warn "CURRENT_OPERATOR sollte 'patrick' oder 'justin' sein"
fi

echo ""
echo "═══ ClickUp ═══"
[ -n "${CLICKUP_API_TOKEN:-}" ] && ok "CLICKUP_API_TOKEN gesetzt" || warn "CLICKUP_API_TOKEN fehlt"
[ -n "${CLICKUP_TEAM_ID:-}" ] && ok "CLICKUP_TEAM_ID=$CLICKUP_TEAM_ID" || warn "CLICKUP_TEAM_ID fehlt"
if [ -n "${CLICKUP_API_TOKEN:-}" ]; then
  RESPONSE=$(curl -sS --max-time 5 -H "Authorization: $CLICKUP_API_TOKEN" "https://api.clickup.com/api/v2/team" 2>/dev/null || echo "")
  echo "$RESPONSE" | grep -q "teams" && ok "ClickUp-API erreichbar" || warn "ClickUp-API-Call fehlgeschlagen"
fi

echo ""
echo "═══ Slack ═══"
[ -n "${SLACK_BOT_TOKEN:-}" ] && ok "SLACK_BOT_TOKEN gesetzt" || warn "SLACK_BOT_TOKEN fehlt"
[ -n "${SLACK_USER_PATRICK:-}" ] && ok "SLACK_USER_PATRICK gesetzt" || warn "SLACK_USER_PATRICK fehlt"
[ -n "${SLACK_USER_JUSTIN:-}" ] && ok "SLACK_USER_JUSTIN gesetzt" || warn "SLACK_USER_JUSTIN fehlt"
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  RESPONSE=$(curl -sS --max-time 5 -H "Authorization: Bearer $SLACK_BOT_TOKEN" "https://slack.com/api/auth.test" 2>/dev/null || echo "")
  echo "$RESPONSE" | grep -q '"ok":true' && ok "Slack-Auth ok" || warn "Slack-Auth fehlgeschlagen"
fi

echo ""
echo "═══ WhatsApp (optional, best-effort) ═══"
[ -n "${CALLMEBOT_PHONE_PATRICK:-}" ] && [ -n "${CALLMEBOT_APIKEY_PATRICK:-}" ] && ok "Patrick CallMeBot gesetzt" || warn "Patrick CallMeBot unvollständig"
[ -n "${CALLMEBOT_PHONE_JUSTIN:-}" ] && [ -n "${CALLMEBOT_APIKEY_JUSTIN:-}" ] && ok "Justin CallMeBot gesetzt" || warn "Justin CallMeBot unvollständig"

echo ""
echo "═══ Tools ═══"
command -v git &>/dev/null && ok "git" || fail "git fehlt"
command -v python3 &>/dev/null && ok "python3" || fail "python3 fehlt"
command -v jq &>/dev/null && ok "jq" || warn "jq fehlt"
command -v gh &>/dev/null && ok "gh-cli" || warn "gh-cli fehlt"
command -v gitleaks &>/dev/null && ok "gitleaks" || warn "gitleaks fehlt"
command -v claude &>/dev/null && ok "claude-CLI" || warn "claude-CLI fehlt"

echo ""
echo "═══ Summary ═══"
echo "  Total: $((PASS + FAIL + WARN)) — ✅ $PASS / ⚠️  $WARN / ❌ $FAIL"

[ "$FAIL" -gt 0 ] && { echo ""; echo "🚨 $FAIL kritische Fehler — fix vor erstem Tool-Use."; exit 1; }
exit 0
