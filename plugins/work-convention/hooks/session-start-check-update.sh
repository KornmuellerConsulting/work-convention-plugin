#!/usr/bin/env bash
# =============================================================================
# session-start-check-update.sh — SessionStart (NEU in v2.1)
#
# Selbstversorgung: das Plugin hält sich künftig selbst aktuell.
#
# Teil A (offline, sofort): vergleicht die eigene Version mit der höchsten im
#   Plugin-Cache. Liegt dort eine neuere, kommt GENAU EINE Zeile — "vX liegt
#   bereit — Neustart aktiviert sie". Sonst Stille. Das ist der einzige Output,
#   den dieser Hook je produziert, und er ist actionable (Neustart).
#
# Teil B (detached, netzwerkbehaftet): höchstens 1x/24h (Throttle-Marker),
#   feuert `claude plugin marketplace update` + `claude plugin update` als
#   Hintergrund-Job mit geschlossenen File-Descriptors und timeout ab.
#   SessionStart wartet keine Millisekunde auf Netz — der Job läuft der
#   Session davon; das Ergebnis landet im Cache und Teil A meldet es beim
#   NÄCHSTEN Session-Start. `claude plugin update` ist non-interaktiv und
#   versioniert den Cache — eine offene Session läuft ungestört auf ihrem
#   alten Pfad weiter (empirisch verifiziert, 2.1.210).
#
# Gates:
#   - WORK_CONVENTION_AUTO_UPDATE=off (Env oder App-.env) -> kompletter No-op.
#   - Plugin-Source-Checkout -> exit (Entwicklung läuft gegen den Repo-Stand;
#     außerdem würde ein Test via --plugin-dir sonst echte Updates feuern).
#   - Ohne CLAUDE_PLUGIN_ROOT oder ohne claude-Binary -> Stille, exit 0.
#   - Doppelstart-Schutz: mkdir-Lock (atomar); verwaiste Locks älter als
#     60 Minuten werden aufgeräumt (find -mmin, GNU+BSD-portabel).
# =============================================================================
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Plugin-Source-Checkout? Nicht anfassen (Pattern aus ensure-git-hooks).
[ -f "$PROJECT_DIR/plugins/work-convention/.claude-plugin/plugin.json" ] && exit 0

# Gate: WORK_CONVENTION_AUTO_UPDATE=off — aus echter Env oder App-.env.
# Gezielter sed-Extract statt source: teilinvalide .env darf uns nicht killen
# (Verify-Pass-Lektion aus v2.0). "export VAR=off" und führende Leerzeichen
# sind in einer gesourcten .env valide und müssen mitmatchen (Verify-Fund v2.1).
AUTO="${WORK_CONVENTION_AUTO_UPDATE:-}"
if [ -z "$AUTO" ] && [ -f "$PROJECT_DIR/.env" ]; then
  AUTO="$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}WORK_CONVENTION_AUTO_UPDATE=[\"'\'']\{0,1\}\([a-zA-Z]*\).*/\2/p' "$PROJECT_DIR/.env" 2>/dev/null | head -1)"
fi
[ "$AUTO" = "off" ] && exit 0

CACHE_DIR="$HOME/.claude/plugins/cache/kornmueller-empire/work-convention"

# ---------- Teil A: offline, sofort ----------
# Als "bereitliegend" zählt nur ein Versions-Verzeichnis mit echtem
# Plugin-Inhalt (plugin.json) — leere Dirs oder verirrte Dateien im Cache
# würden sonst eine dauerhaft falsche Neustart-Zeile produzieren (Verify-Fund).
SELF_VER="$(jq -r '.version // empty' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)"
if [ -n "$SELF_VER" ] && [ -d "$CACHE_DIR" ]; then
  NEWEST=""
  for d in "$CACHE_DIR"/*/; do
    [ -d "$d" ] || continue
    v="$(basename "$d")"
    printf '%s' "$v" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || continue
    [ -f "$d/.claude-plugin/plugin.json" ] || continue
    if [ -z "$NEWEST" ]; then
      NEWEST="$v"
    else
      NEWEST="$(printf '%s\n%s\n' "$NEWEST" "$v" | sort -V | tail -1)"
    fi
  done
  if [ -n "$NEWEST" ] && [ "$NEWEST" != "$SELF_VER" ]; then
    HIGHER="$(printf '%s\n%s\n' "$SELF_VER" "$NEWEST" | sort -V | tail -1)"
    [ "$HIGHER" = "$NEWEST" ] && echo "⬆️  work-convention v$NEWEST liegt bereit — Neustart aktiviert sie."
  fi
fi

# ---------- Teil B: detached, gedrosselt ----------
command -v claude >/dev/null 2>&1 || exit 0

STAMP="$HOME/.claude/.work-convention-last-update-check"
NOW="$(date +%s)"
LAST=""
[ -f "$STAMP" ] && LAST="$(tr -dc '0-9' 2>/dev/null < "$STAMP" || true)"
[ -z "$LAST" ] && LAST=0
# Zukunfts-Timestamp (zurückgestellte Uhr, korrupter Marker) würde den
# Throttle für immer vergiften — wie fehlend behandeln (Verify-Fund).
[ "$LAST" -gt "$NOW" ] && LAST=0
[ $((NOW - LAST)) -lt 86400 ] && exit 0

# Parent-Verzeichnis VOR dem Lock-mkdir sicherstellen — ohne ~/.claude
# scheiterte sonst der Lock still und Teil B wäre dauerhaft tot (Verify-Fund).
mkdir -p "$(dirname "$STAMP")" 2>/dev/null || true

# Atomarer Doppelstart-Schutz. Verwaiste Locks (Crash mitten im Update)
# nach 60 Minuten aufräumen — rm -rf statt rmdir, denn ein Lock mit Inhalt
# (z.B. .DS_Store) wäre sonst unlöschbar und Teil B für immer tot (Verify-Fund).
LOCK="$STAMP.lock"
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then
  rm -rf "$LOCK" 2>/dev/null || true
fi
mkdir "$LOCK" 2>/dev/null || exit 0

printf '%s\n' "$NOW" > "$STAMP" 2>/dev/null || true

# Geschlossene FDs sind Pflicht: ein geerbtes stdout hält sonst den
# SessionStart (und CI-Steps) am Leben, bis der Netz-Job fertig ist.
(
  run_limited() {
    if command -v timeout >/dev/null 2>&1; then timeout 120 "$@"; else "$@"; fi
  }
  run_limited claude plugin marketplace update kornmueller-empire >/dev/null 2>&1 \
    && run_limited claude plugin update work-convention@kornmueller-empire >/dev/null 2>&1
  rmdir "$LOCK" 2>/dev/null || true
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
