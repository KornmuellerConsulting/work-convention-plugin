#!/usr/bin/env bash
# =============================================================================
# pre-bash-guards.sh — PreToolUse:Bash (v2.0: konsolidierter Dispatcher)
#
# Ersetzt fünf Einzel-Hooks (ein Prozess-Spawn statt fünf pro Bash-Call):
#   1. Eskalations-Hard-Block (Fail #4 ohne Solver)
#   2. Secret-Patterns im Command-Body
#   3. Destruktive Befehle mit Prod-Bezug
#   4. Migrations-Slot-Lock zwischen Operatoren
#   5. HEAD-Drift-Warnung (warnt nur, blockt nie)
#
# Blocks geben exit 2 zurück (Claude-Code-Convention: nur 2 blockt).
# v2.0 fixt damit einen Alt-Bug: der Eskalations-Block gab exit 1 zurück
# und hat deshalb nie wirklich geblockt, nur gewarnt.
# =============================================================================
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# --- 1. Eskalations-Hard-Block ----------------------------------------------
COUNTER_FILE="$STATE_DIR/escalation-counter.state"
SOLVER_FLAG="$STATE_DIR/solver-activated.flag"
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
  case "$COUNT" in (*[!0-9]*|"") COUNT=0 ;; esac
  if [ "$COUNT" -ge 4 ] && [ ! -f "$SOLVER_FLAG" ]; then
    cat <<MSG >&2
🚫 HARD-BLOCK: $COUNT aufeinanderfolgende Fails.

Solver-Subagent muss aktiviert werden bevor weitergearbeitet wird.
Aktivierung: "Aktiviere Solver-Subagent für [Problem-Beschreibung]"
Reset (nur wenn bewusst): /escalate reset
MSG
    exit 2
  fi
fi

# --- 2. Secret-Patterns ------------------------------------------------------
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9_-]{20,}'
  'xoxb-[0-9]{10,}-[a-zA-Z0-9]{20,}'
  'ghp_[a-zA-Z0-9]{36}'
  'AIza[0-9A-Za-z_-]{35}'
  'AKIA[0-9A-Z]{16}'
  'pk_(live|test)_[a-zA-Z0-9]{24,}'
  'rk_(live|test)_[a-zA-Z0-9]{24,}'
  'sk_(live|test)_[a-zA-Z0-9]{24,}'
)
for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qE "$pattern"; then
    cat <<MSG >&2
🚫 BLOCKED: Bash-Command enthält Secret-Pattern.

Pattern erkannt: $pattern
Command-Snippet: $(echo "$CMD" | head -c 200)...

Lösung: Secrets via Env-Var (\$VAR_NAME) aus .env — niemals inline.
MSG
    exit 2
  fi
done

# --- 3. Destruktiv + Prod ----------------------------------------------------
if echo "$CMD" | grep -qiE '\b(prod|production|live)\b'; then
  DESTRUCTIVE_PATTERNS=(
    'DROP[[:space:]]+TABLE'
    'DROP[[:space:]]+DATABASE'
    'TRUNCATE[[:space:]]+TABLE'
    'DELETE[[:space:]]+FROM'
    'rm[[:space:]]+-rf'
    'sudo[[:space:]]+rm'
    'mkfs\.'
    'dd[[:space:]]+if='
    'shutdown'
    'reboot'
  )
  for pattern in "${DESTRUCTIVE_PATTERNS[@]}"; do
    if echo "$CMD" | grep -qiE "$pattern"; then
      cat <<MSG >&2
🚫 BLOCKED: Destruktiver Befehl mit Prod-Bezug.

Pattern: $pattern
Command: $(echo "$CMD" | head -c 200)

Hard-Block. Wenn du wirklich willst:
  1. Backup verifizieren
  2. Confirmation in DECISIONS.md dokumentieren
  3. Manuell außerhalb von Claude Code ausführen
MSG
      exit 2
    fi
  done
fi

# --- 4. Migrations-Slot ------------------------------------------------------
if echo "$CMD" | grep -qE 'supabase\s+(db|migration)|prisma\s+migrate|drizzle.*migrate'; then
  # CURRENT_OPERATOR gezielt extrahieren statt sourcen — ein bash -n-Gate
  # sperrte den Operator bei teilinvalider .env von seinem EIGENEN Lock aus
  # (Fallback "unknown") und vergiftete den Slot für den anderen.
  OPERATOR=""
  if [ -f "$PROJECT_DIR/.env" ]; then
    OPERATOR=$(sed -n 's/^CURRENT_OPERATOR=//p' "$PROJECT_DIR/.env" 2>/dev/null | head -1 | tr -d '"'"'")
  fi
  OPERATOR="${OPERATOR:-unknown}"
  LOCK_FILE="$STATE_DIR/migration.lock"
  if [ -f "$LOCK_FILE" ]; then
    HOLDER=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ "$HOLDER" != "$OPERATOR" ]; then
      cat <<MSG >&2
🚫 BLOCKED: Migration-Slot belegt von "$HOLDER".

Wenn der andere Operator wirklich nicht migriert: rm $LOCK_FILE
Sonst: warten bis Slot frei.
MSG
      exit 2
    fi
  fi
  mkdir -p "$STATE_DIR"
  echo "$OPERATOR" > "$LOCK_FILE"
  # TTL-Subshell mit geschlossenen FDs — ein geerbtes stdout würde CI-Steps
  # und Hook-Aufrufer bis zum Ablauf der 30 Minuten am Leben halten.
  ( sleep 1800 && rm -f "$LOCK_FILE" 2>/dev/null ) >/dev/null 2>&1 &
fi

# --- 5. HEAD-Drift (warnt nur) ----------------------------------------------
HEAD_STATE="$STATE_DIR/last-head.txt"
if [ -f "$HEAD_STATE" ]; then
  LAST=$(cat "$HEAD_STATE" 2>/dev/null)
  NOW=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")
  if [ -n "$LAST" ] && [ -n "$NOW" ] && [ "$LAST" != "$NOW" ]; then
    cat <<MSG >&2
⚠️  HEAD-Drift erkannt.
  Letzter Stand: $LAST
  Jetzt:         $NOW
Wahrscheinlich extern ge-rebase'd/-checkout'd/-pullt. Verify: git log --oneline -5
MSG
  fi
fi

exit 0
