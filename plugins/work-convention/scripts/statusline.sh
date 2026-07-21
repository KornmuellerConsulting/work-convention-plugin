#!/usr/bin/env bash
# =============================================================================
# statusline.sh — Tacho fürs Abo (NEU in v2.1)
#
# Eine Zeile: Modell | Kontext-% | 5h-Limit-% | Wochen-Limit-%.
# Ambiente Anzeige statt Hook: kostet null Kontext-Tokens, weil die Statusline
# nie ins Modell-Kontextfenster eingeht — sie rendert nur im Terminal.
#
# Claude Code kann (Stand 2.1.210) keinen statusLine-Default aus einem Plugin
# laden — settings.json im Plugin-Root unterstützt nur `agent` und
# `subagentStatusLine` (empirisch verifiziert, Plugins-Reference bestätigt).
# Aktivierung ist daher ein einmaliger Opt-in-Eintrag in ~/.claude/settings.json
# (Snippet: docs/STATUSLINE.md). Der healthcheck erinnert daran. Das Plugin
# schreibt NIEMALS selbst in User-Settings.
#
# Robustheit:
#   - Jedes fehlende ODER null-Feld lässt sein Segment stumm weg. API-Sessions
#     haben keine rate_limits; der allererste Render einer Session hat
#     used_percentage=null (real gemessen in 2.1.210).
#   - Feldwerte (z.B. model.display_name) werden in jq per Codepoint-Filter
#     von sämtlichen Control-Chars bereinigt — C0 (inkl. ESC/Tab/Newline), DEL
#     UND der C1-Block U+0080–U+009F (8-Bit-CSI/OSC/DCS/NEL, Verify-Pass-Fund
#     aus v2.1) — und nur via printf '%s' ausgegeben. Kein Wert wird je als
#     printf-Format interpretiert, ANSI-Injection über stdin-Werte ist tot.
#   - Nur jq + Bash-Builtins: kein git, kein Netz, keine BSD-only-Tools.
#     Läuft unter macOS, Linux und Windows/Git-Bash.
# =============================================================================
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

# Ein einziger jq-Pass, vier Ausgabezeilen (Modell, Ctx, 5h, 7d). clean ist
# bewusst regexfrei (explode/implode-Codepoint-Filter) — jq-Regex-Escapes sind
# zwischen Oniguruma-Builds nicht portabel. Nach clean kann kein Wert mehr
# Zeilen vortäuschen, zeilenbasiertes Lesen ist damit sicher.
VALS="$(jq -r '
  def clean: tostring | explode | map(select((. >= 32 and . < 127) or . > 159)) | implode;
  def pct(v): (v | if type == "number" then round | tostring else "NA" end);
  (.model.display_name // "NA" | clean),
  pct(.context_window.used_percentage),
  pct(.rate_limits.five_hour.used_percentage),
  pct(.rate_limits.seven_day.used_percentage)
' 2>/dev/null)" || exit 0
[ -z "$VALS" ] && exit 0

{ IFS= read -r MODEL; IFS= read -r CTX; IFS= read -r FIVE_H; IFS= read -r SEVEN_D; } <<EOF
$VALS
EOF

ESC=$'\033'
RESET="${ESC}[0m"
DIM="${ESC}[2m"

# Farbschwelle nur für den Kontext-Anteil: grün <50, gelb <75, rot ab 75.
ctx_color() {
  if [ "$1" -ge 75 ]; then printf '%s' "${ESC}[31m"
  elif [ "$1" -ge 50 ]; then printf '%s' "${ESC}[33m"
  else printf '%s' "${ESC}[32m"; fi
}

OUT=""
append() { [ -n "$OUT" ] && OUT="${OUT}${DIM} | ${RESET}"; OUT="${OUT}$1"; }

[ "${MODEL:-NA}" != "NA" ] && [ -n "${MODEL:-}" ] && append "$MODEL"
if [ "${CTX:-NA}" != "NA" ] && [ "$CTX" -eq "$CTX" ] 2>/dev/null; then
  append "$(ctx_color "$CTX")Ctx ${CTX}%${RESET}"
fi
[ "${FIVE_H:-NA}" != "NA" ] && append "5h ${FIVE_H}%"
[ "${SEVEN_D:-NA}" != "NA" ] && append "7d ${SEVEN_D}%"

[ -z "$OUT" ] && exit 0
printf '%s\n' "$OUT"
