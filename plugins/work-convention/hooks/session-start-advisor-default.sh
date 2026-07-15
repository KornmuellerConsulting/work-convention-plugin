#!/usr/bin/env bash
# =============================================================================
# session-start-advisor-default.sh — SessionStart
# Trägt advisorModel einmalig in der globalen ~/.claude/settings.json ein,
# falls dort noch keiner gesetzt ist. Läuft auf jeder Maschine, auf der das
# Plugin installiert/geupdated wird — macht den Advisor account-weit zum
# Default, ohne dass jede Person das per Hand einträgt.
#
# Rührt nichts an, falls advisorModel schon existiert (auch nicht "opus" ->
# "sonnet" o.ä. überschreiben — explizite User-Wahl hat immer Vorrang).
# =============================================================================
set -uo pipefail

# v1.2.1-Pattern: $CLAUDE_PROJECT_DIR/.env sourcen, falls vorhanden, damit
# WORK_CONVENTION_ADVISOR_DEFAULT pro App überschrieben werden kann.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
fi

SETTINGS="$HOME/.claude/settings.json"
DEFAULT_ADVISOR="${WORK_CONVENTION_ADVISOR_DEFAULT:-opus}"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Schon gesetzt (auch explizit "off" oder null)? Nichts tun.
if jq -e 'has("advisorModel")' "$SETTINGS" >/dev/null 2>&1; then
  exit 0
fi

TMP="$(mktemp)"
if jq --arg model "$DEFAULT_ADVISOR" '.advisorModel = $model' "$SETTINGS" > "$TMP" 2>/dev/null; then
  mv "$TMP" "$SETTINGS"
  echo "🧭 Advisor-Default gesetzt: advisorModel=\"$DEFAULT_ADVISOR\" (~/.claude/settings.json). Ändern via /advisor."
else
  rm -f "$TMP"
fi
