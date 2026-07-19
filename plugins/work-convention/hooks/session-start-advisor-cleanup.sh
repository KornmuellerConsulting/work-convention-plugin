#!/usr/bin/env bash
# =============================================================================
# session-start-advisor-cleanup.sh — SessionStart
#
# EINMALIGE MIGRATION (v1.3.0). Macht rückgängig, was v1.2.4 angerichtet hat:
# dort schrieb session-start-advisor-default.sh auf jeder Maschine still
# `advisorModel: "opus"` in die globale ~/.claude/settings.json. Bei Opus als
# Hauptmodell ist das Opus-berät-Opus — Tokens ohne Erkenntnisgewinn.
#
# Läuft genau EINMAL pro Maschine. Das Marker-File ist nicht Vorsicht, sondern
# Notwendigkeit: ohne es würde der Hook bei jedem Session-Start erneut löschen
# und damit ein späteres, bewusstes `/advisor sonnet` jedes Mal wieder killen.
# Die Migration ist ein Undo, keine Dauer-Durchsetzung.
# =============================================================================
set -uo pipefail

MARKER="$HOME/.claude/.work-convention-advisor-cleanup.done"

[ -f "$MARKER" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

mark_done() {
  mkdir -p "$(dirname "$MARKER")" 2>/dev/null || true
  printf '%s\n' "$1" > "$MARKER" 2>/dev/null || true
}

SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ]; then
  mark_done "skipped: keine settings.json"
  exit 0
fi

if ! jq -e 'has("advisorModel")' "$SETTINGS" >/dev/null 2>&1; then
  mark_done "noop: advisorModel war nicht gesetzt"
  exit 0
fi

PREV="$(jq -r '.advisorModel' "$SETTINGS" 2>/dev/null)"
BACKUP="$SETTINGS.pre-advisor-cleanup.bak"
cp "$SETTINGS" "$BACKUP" 2>/dev/null || true

TMP="$(mktemp)"
if jq 'del(.advisorModel)' "$SETTINGS" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  mv "$TMP" "$SETTINGS"
  mark_done "removed: advisorModel=$PREV"
  cat <<MSG
🧭 Advisor-Migration (einmalig, v1.3.0)
   advisorModel="$PREV" aus ~/.claude/settings.json entfernt — v1.2.4 hatte den
   Wert automatisch gesetzt, bei Opus-Hauptmodell berät sich Opus damit selbst.

   Backup: $BACKUP
   Advisor zurückwollen: /advisor
   Läuft nicht erneut.
MSG
else
  rm -f "$TMP"
  echo "⚠️  Advisor-Migration fehlgeschlagen (jq) — settings.json unverändert." >&2
fi
