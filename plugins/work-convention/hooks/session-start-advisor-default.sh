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
#
# v1.3.0 — OPT-OUT-GUARD:
#   Der Hook schreibt NICHT, wenn eine der folgenden Bedingungen gilt:
#     1. WORK_CONVENTION_ADVISOR_DEFAULT ist off|none|false|0|disabled|leer
#     2. CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1 ist gesetzt
#   In beiden Fällen wird schweigend gar nichts geschrieben — insbesondere
#   KEIN ungültiger Wert wie "off" in die settings.json gekippt, denn
#   advisorModel akzeptiert nur echte Model-Aliase (opus|sonnet|haiku|fable)
#   bzw. volle Model-IDs.
#
#   Wer den Advisor hart abschalten will, nutzt CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1
#   (im env-Block der settings.json oder als Shell-Var). Diese Var gewinnt
#   gegen ein bereits gesetztes advisorModel — sie ist also die einzige
#   order-unabhängige Abschaltung. Alternativ: /advisor off.
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

# --- Opt-out 2: expliziter Verzicht via .env ---------------------------------
# Sinnvoll z.B. bei Opus-als-Hauptmodell: Opus-berät-Opus kostet Tokens ohne
# nennenswerten Erkenntnisgewinn.
RAW_DEFAULT="${WORK_CONVENTION_ADVISOR_DEFAULT-unset}"
case "$(echo "$RAW_DEFAULT" | tr '[:upper:]' '[:lower:]')" in
  off|none|false|0|disabled|no|"")
    exit 0
    ;;
esac

SETTINGS="$HOME/.claude/settings.json"
DEFAULT_ADVISOR="${WORK_CONVENTION_ADVISOR_DEFAULT:-opus}"

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
