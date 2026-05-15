#!/usr/bin/env bash
# =============================================================================
# block-prod-destructive.sh — PreToolUse:Bash
# Blockt destruktive Operationen mit Produktions-Bezug.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Prod-Indikator + Destructive-Keyword muss BEIDES vorhanden sein
HAS_PROD=0
echo "$CMD" | grep -qiE '\b(prod|production|live)\b' && HAS_PROD=1
[ "$HAS_PROD" -eq 0 ] && exit 0

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
exit 0
