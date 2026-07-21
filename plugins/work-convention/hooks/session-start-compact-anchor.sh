#!/usr/bin/env bash
# =============================================================================
# session-start-compact-anchor.sh — SessionStart, Matcher "compact" (NEU v2.1)
#
# Nach einer (Auto-)Compaction sind die operativen Anker das Erste, was im
# komprimierten Kontext verblasst: auf welchem Branch wir sind, welches Ticket
# lief, ob offene Blocker existieren. Dieser Hook injiziert genau diese Anker
# EINMALIG direkt nach der Compaction neu — wenige Zeilen, deterministisch.
#
# Kostenbilanz (Lean Core): feuert AUSSCHLIESSLICH bei source=compact — also
# nie beim normalen Session-Start, nie pro Prompt. In Sessions ohne Compaction
# ist er exakt null Kontext. Doppelt abgesichert: Matcher in hooks.json UND
# source-Check hier (fällt der Matcher je einem Claude-Code-Regress zum Opfer,
# bleibt der Hook trotzdem stumm statt jede Session zu bezahlen).
#
# Ticket-Ermittlung: .claude/state/active-ticket.txt falls eine App das pflegt,
# sonst die Ticket-ID aus dem letzten Commit-Subject (die ist dank
# commit-msg-Hook verlässlich vorhanden).
# =============================================================================
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)"
[ "$SOURCE" = "compact" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

TICKET=""
STATE_TICKET="$PROJECT_DIR/.claude/state/active-ticket.txt"
if [ -f "$STATE_TICKET" ]; then
  # Erste Zeile, Control-Chars raus, hart gekappt — State-Files sind Input.
  TICKET="$(head -1 "$STATE_TICKET" 2>/dev/null | LC_ALL=C tr -cd '[:print:]' | cut -c1-60)"
fi
if [ -z "$TICKET" ]; then
  TICKET="$(git -C "$PROJECT_DIR" log -1 --format=%s 2>/dev/null \
    | grep -oE '[A-Z][A-Z0-9]*-[0-9]+' | head -1 || true)"
  [ -n "$TICKET" ] && TICKET="$TICKET (aus letztem Commit)"
fi

BLOCKERS=""
[ -s "$PROJECT_DIR/BLOCKERS.md" ] && BLOCKERS="ja"

# Nichts zu verankern -> Stille.
[ -z "$BRANCH" ] && [ -z "$TICKET" ] && [ -z "$BLOCKERS" ] && exit 0

echo "🧭 Anker nach Compaction:"
[ -n "$BRANCH" ] && echo "   Branch: $BRANCH"
[ -n "$TICKET" ] && echo "   Ticket: $TICKET"
[ -n "$BLOCKERS" ] && echo "   BLOCKERS.md existiert — offene Punkte dort prüfen."
exit 0
