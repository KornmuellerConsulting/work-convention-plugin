#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh — End-to-End-Verify aller Plugin-Komponenten
# =============================================================================
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "═══ Plugin-Files ═══"
[ -d "$PROJECT_DIR/.claude" ] && ok ".claude/ exists" || fail ".claude/ missing"
[ -f "$PROJECT_DIR/.claude/settings.json" ] && ok "settings.json" || fail "settings.json missing"
[ -d "$PROJECT_DIR/.claude/hooks" ] && ok "hooks/ dir" || fail "hooks/ missing"
[ -d "$PROJECT_DIR/.claude/agents" ] && ok "agents/ dir" || fail "agents/ missing"
[ -d "$PROJECT_DIR/.claude/scripts" ] && ok "scripts/ dir" || fail "scripts/ missing"
[ -f "$PROJECT_DIR/CLAUDE.md" ] && ok "CLAUDE.md" || fail "CLAUDE.md missing"

HOOKS_COUNT=$(find "$PROJECT_DIR/.claude/hooks" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$HOOKS_COUNT" -ge 19 ] && ok "$HOOKS_COUNT Hooks installiert" || warn "$HOOKS_COUNT Hooks (erwartet ≥19)"

echo ""
echo "═══ Identity ═══"
[ -n "${APP_NAME:-}" ] && ok "APP_NAME=$APP_NAME" || fail "APP_NAME nicht gesetzt"
[ -n "${APP_PROJECT_PREFIX:-}" ] && ok "APP_PROJECT_PREFIX=$APP_PROJECT_PREFIX" || fail "APP_PROJECT_PREFIX nicht gesetzt"
[ "${CURRENT_OPERATOR:-}" = "patrick" ] || [ "${CURRENT_OPERATOR:-}" = "justin" ] && ok "CURRENT_OPERATOR=$CURRENT_OPERATOR" || warn "CURRENT_OPERATOR sollte 'patrick' oder 'justin' sein"

echo ""
echo "═══ ClickUp ═══"
[ -n "${CLICKUP_API_TOKEN:-}" ] && ok "CLICKUP_API_TOKEN gesetzt" || warn "CLICKUP_API_TOKEN fehlt"
[ -n "${CLICKUP_TEAM_ID:-}" ] && ok "CLICKUP_TEAM_ID=$CLICKUP_TEAM_ID" || warn "CLICKUP_TEAM_ID fehlt"
[ -n "${CLICKUP_SPACE_ID:-}" ] && ok "CLICKUP_SPACE_ID gesetzt" || warn "CLICKUP_SPACE_ID fehlt (run bootstrap-space)"

if [ -n "${CLICKUP_API_TOKEN:-}" ] && [ -n "${CLICKUP_TEAM_ID:-}" ]; then
  RESPONSE=$(curl -sS --max-time 5 -H "Authorization: $CLICKUP_API_TOKEN" "https://api.clickup.com/api/v2/team" 2>/dev/null || echo "")
  if echo "$RESPONSE" | grep -q "teams"; then
    ok "ClickUp-API erreichbar"
  else
    warn "ClickUp-API-Call fehlgeschlagen"
  fi
fi

echo ""
echo "═══ Slack ═══"
[ -n "${SLACK_BOT_TOKEN:-}" ] && ok "SLACK_BOT_TOKEN gesetzt" || warn "SLACK_BOT_TOKEN fehlt"
[ -n "${SLACK_USER_PATRICK:-}" ] && ok "SLACK_USER_PATRICK gesetzt" || warn "SLACK_USER_PATRICK fehlt"
[ -n "${SLACK_USER_JUSTIN:-}" ] && ok "SLACK_USER_JUSTIN gesetzt" || warn "SLACK_USER_JUSTIN fehlt"

if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  RESPONSE=$(curl -sS --max-time 5 -H "Authorization: Bearer $SLACK_BOT_TOKEN" "https://slack.com/api/auth.test" 2>/dev/null || echo "")
  if echo "$RESPONSE" | grep -q '"ok":true'; then
    ok "Slack-Auth ok"
  else
    warn "Slack-Auth fehlgeschlagen"
  fi
fi

echo ""
echo "═══ Pushover ═══"
[ -n "${PUSHOVER_APP_TOKEN:-}" ] && ok "PUSHOVER_APP_TOKEN gesetzt" || warn "PUSHOVER_APP_TOKEN fehlt"
[ -n "${PUSHOVER_USER_PATRICK:-}" ] && ok "PUSHOVER_USER_PATRICK gesetzt" || warn "PUSHOVER_USER_PATRICK fehlt"
[ -n "${PUSHOVER_USER_JUSTIN:-}" ] && ok "PUSHOVER_USER_JUSTIN gesetzt" || warn "PUSHOVER_USER_JUSTIN fehlt"

echo ""
echo "═══ WhatsApp ═══"
[ -n "${CALLMEBOT_PHONE_PATRICK:-}" ] && [ -n "${CALLMEBOT_APIKEY_PATRICK:-}" ] && ok "Patrick CallMeBot gesetzt" || warn "Patrick CallMeBot unvollständig"
[ -n "${CALLMEBOT_PHONE_JUSTIN:-}" ] && [ -n "${CALLMEBOT_APIKEY_JUSTIN:-}" ] && ok "Justin CallMeBot gesetzt" || warn "Justin CallMeBot unvollständig"

echo ""
echo "═══ Tools ═══"
command -v git &>/dev/null && ok "git" || fail "git fehlt"
command -v python3 &>/dev/null && ok "python3" || fail "python3 fehlt"
command -v jq &>/dev/null && ok "jq" || warn "jq fehlt (für notification-trigger.sh)"
command -v gh &>/dev/null && ok "gh-cli" || warn "gh-cli fehlt (Repo-Operations)"
command -v gitleaks &>/dev/null && ok "gitleaks" || warn "gitleaks fehlt (Pre-Commit-Scan überspringt)"

echo ""
echo "═══ Summary ═══"
TOTAL=$((PASS + FAIL + WARN))
echo "  Total:    $TOTAL"
echo "  ✅ Pass:  $PASS"
echo "  ⚠️  Warn:  $WARN"
echo "  ❌ Fail:  $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "🚨 $FAIL kritische Fehler — fix vor erstem Tool-Use."
  exit 1
fi
exit 0
