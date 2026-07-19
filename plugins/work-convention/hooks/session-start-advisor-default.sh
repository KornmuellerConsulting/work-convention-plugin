#!/usr/bin/env bash
# =============================================================================
# session-start-advisor-default.sh — SessionStart
#
# OPT-IN seit v1.3.0. Trägt advisorModel in die globale ~/.claude/settings.json
# ein — aber nur, wenn WORK_CONVENTION_ADVISOR_DEFAULT ausdrücklich auf ein
# Modell gesetzt ist. Ohne diese Variable passiert nichts.
#
# Bis v1.2.4 war es umgekehrt: fehlte die Variable, schrieb der Hook ungefragt
# "opus". Das hat auf jeder Maschine des Empire einen Advisor aktiviert, den
# niemand bestellt hatte. session-start-advisor-cleanup.sh sammelt diese
# Altlast einmalig wieder ein.
#
# Rührt nichts an, falls advisorModel schon existiert — explizite User-Wahl
# hat immer Vorrang.
#
# Der Hook schweigt außerdem komplett, wenn CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1
# gesetzt ist. Diese Var gewinnt gegen jedes advisorModel und ist damit die
# einzige order-unabhängige Abschaltung (env-Block der settings.json oder
# Shell-Var). Alternativ: /advisor off.
#
# Es wird nie ein Pseudo-Wert wie "off" geschrieben — advisorModel akzeptiert
# nur echte Model-Aliase (opus|sonnet|haiku|fable) bzw. volle Model-IDs.
# =============================================================================
set -uo pipefail

# v1.2.1-Pattern: $CLAUDE_PROJECT_DIR/.env sourcen, falls vorhanden, damit
# WORK_CONVENTION_ADVISOR_DEFAULT pro App überschrieben werden kann.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if [ -f "$PROJECT_DIR/.env" ]; then
  # v1.2.3-Pattern: Syntax-Guard, damit ein kaputtes .env den Hook nicht killt
  if bash -n "$PROJECT_DIR/.env" 2>/dev/null; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    set +a
  fi
fi

# --- Opt-out 1: Advisor-Tool global hart deaktiviert -------------------------
# Wenn der User den Advisor ohnehin abgeschaltet hat, wäre ein advisorModel-
# Eintrag toter Ballast (die Env-Var gewinnt) und nur verwirrend.
if [ "${CLAUDE_CODE_DISABLE_ADVISOR_TOOL:-}" = "1" ]; then
  exit 0
fi

# --- Opt-out 2: kein explizites Opt-in -> gar nichts tun ---------------------
# v1.3.0 hat den Default UMGEDREHT. Bis v1.2.4 schrieb der Hook ungefragt
# "opus", wenn die Variable fehlte — genau das hat auf jeder Maschine des
# Empire einen Advisor aktiviert, den niemand bestellt hatte, und wird von
# session-start-advisor-cleanup.sh wieder eingesammelt.
#
# Jetzt gilt: ohne ausdrücklichen Modellwert in WORK_CONVENTION_ADVISOR_DEFAULT
# fasst der Hook die globale settings.json nicht an.
RAW_DEFAULT="${WORK_CONVENTION_ADVISOR_DEFAULT-unset}"
case "$(echo "$RAW_DEFAULT" | tr '[:upper:]' '[:lower:]')" in
  unset|off|none|false|0|disabled|no|"")
    exit 0
    ;;
esac

SETTINGS="$HOME/.claude/settings.json"
DEFAULT_ADVISOR="$WORK_CONVENTION_ADVISOR_DEFAULT"

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Schon gesetzt (auch explizit null)? Nichts tun.
if jq -e 'has("advisorModel")' "$SETTINGS" >/dev/null 2>&1; then
  exit 0
fi

TMP="$(mktemp)"
if jq --arg model "$DEFAULT_ADVISOR" '.advisorModel = $model' "$SETTINGS" > "$TMP" 2>/dev/null; then
  mv "$TMP" "$SETTINGS"
  echo "🧭 Advisor-Default gesetzt: advisorModel=\"$DEFAULT_ADVISOR\" (~/.claude/settings.json). Ändern via /advisor, abschalten via /advisor off oder WORK_CONVENTION_ADVISOR_DEFAULT=off in der .env."
else
  rm -f "$TMP"
fi
