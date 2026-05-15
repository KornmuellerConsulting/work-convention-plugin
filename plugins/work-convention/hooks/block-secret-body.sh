#!/usr/bin/env bash
# =============================================================================
# block-secret-body.sh — PreToolUse:Bash
# Verhindert dass Secrets in Bash-Bodies landen (Logs, Pipes, Redirects).
# v1.2: liest tool_input über stdin-JSON statt env-var.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

PATTERNS=(
  'sk-[a-zA-Z0-9_-]{20,}'
  'xoxb-[0-9]{10,}-[a-zA-Z0-9]{20,}'
  'ghp_[a-zA-Z0-9]{36}'
  'AIza[0-9A-Za-z_-]{35}'
  'AKIA[0-9A-Z]{16}'
  'pk_(live|test)_[a-zA-Z0-9]{24,}'
  'rk_(live|test)_[a-zA-Z0-9]{24,}'
  'sk_(live|test)_[a-zA-Z0-9]{24,}'
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$CMD" | grep -qE "$pattern"; then
    cat <<MSG >&2
🚫 BLOCKED: Bash-Command enthält Secret-Pattern.

Pattern erkannt: $pattern
Command-Snippet: $(echo "$CMD" | head -c 200)...

Lösung:
  - Secrets via Env-Var: \$VAR_NAME
  - In .env (nicht committed)
  - Niemals inline im Bash-Body
MSG
    exit 2
  fi
done
exit 0
