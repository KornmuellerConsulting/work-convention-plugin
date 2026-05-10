#!/usr/bin/env bash
# =============================================================================
# pre-bash-migration-slot.sh — PreToolUse:Bash
# Verhindert parallele Migrations zwischen Operatoren.
# =============================================================================
set -euo pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"
[ -z "$CMD" ] && exit 0

# Nur bei Migration-Commands
if ! echo "$CMD" | grep -qE 'supabase\s+(db|migration)|prisma\s+migrate|drizzle.*migrate'; then
  exit 0
fi

LOCK_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/state/migration.lock"
OPERATOR="${CURRENT_OPERATOR:-unknown}"

if [ -f "$LOCK_FILE" ]; then
  HOLDER=$(cat "$LOCK_FILE" 2>/dev/null)
  if [ "$HOLDER" != "$OPERATOR" ]; then
    cat <<MSG >&2
🚫 BLOCKED: Migration-Slot belegt von "$HOLDER".

Wenn der andere Operator wirklich nicht migriert:
  rm $LOCK_FILE

Sonst: warten bis Slot frei.
MSG
    exit 1
  fi
fi

# Slot belegen
mkdir -p "$(dirname "$LOCK_FILE")"
echo "$OPERATOR" > "$LOCK_FILE"

# Auto-cleanup nach 30min
( sleep 1800 && rm -f "$LOCK_FILE" 2>/dev/null ) &
exit 0
