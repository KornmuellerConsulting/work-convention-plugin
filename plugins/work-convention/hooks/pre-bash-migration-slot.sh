#!/usr/bin/env bash
# =============================================================================
# pre-bash-migration-slot.sh — PreToolUse:Bash
# Verhindert parallele Migrations zwischen Operatoren.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

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
    exit 2
  fi
fi

mkdir -p "$(dirname "$LOCK_FILE")"
echo "$OPERATOR" > "$LOCK_FILE"
( sleep 1800 && rm -f "$LOCK_FILE" 2>/dev/null ) &
exit 0
