#!/usr/bin/env bash
# =============================================================================
# pre-edit-secret-body.sh — PreToolUse:Edit/Write
# Defense 2nd-line gegen Secret-Patterns in File-Edits.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
# Edit-Tool: new_string. Write-Tool: content.
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)
[ -z "$CONTENT" ] && exit 0

PATTERNS=(
  'sk-[a-zA-Z0-9_-]{20,}'
  'xoxb-[0-9]{10,}-[a-zA-Z0-9]{20,}'
  'ghp_[a-zA-Z0-9]{36}'
  'AIza[0-9A-Za-z_-]{35}'
  'AKIA[0-9A-Z]{16}'
  'sk_(live|test)_[a-zA-Z0-9]{24,}'
  'rk_(live|test)_[a-zA-Z0-9]{24,}'
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -qE "$pattern"; then
    cat <<MSG >&2
🚫 BLOCKED: Secret-Pattern in File-Content erkannt.

Pattern: $pattern

Lösung:
  - Secrets in .env (nicht committed)
  - Code-Referenzen via process.env.VAR_NAME
MSG
    exit 2
  fi
done
exit 0
