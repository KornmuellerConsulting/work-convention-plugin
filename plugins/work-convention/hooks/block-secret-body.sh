#!/usr/bin/env bash
# =============================================================================
# block-secret-body.sh — PreToolUse:Bash
# Verhindert dass Secrets in Bash-Bodies landen (Logs, Pipes, Redirects).
# =============================================================================
set -euo pipefail
CMD="${CLAUDE_TOOL_INPUT_command:-}"
[ -z "$CMD" ] && exit 0

# Pattern für gängige Secret-Formate
PATTERNS=(
  'sk-[a-zA-Z0-9_-]{20,}'         # Anthropic, OpenAI etc.
  'xoxb-[0-9]{10,}-[a-zA-Z0-9]{20,}'  # Slack Bot-Token
  'ghp_[a-zA-Z0-9]{36}'           # GitHub PAT
  'AIza[0-9A-Za-z_-]{35}'         # Google API
  'AKIA[0-9A-Z]{16}'              # AWS Access Key
  'pk_(live|test)_[a-zA-Z0-9]{24,}' # Stripe public
  'rk_(live|test)_[a-zA-Z0-9]{24,}' # Stripe restricted
  'sk_(live|test)_[a-zA-Z0-9]{24,}' # Stripe secret
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
    exit 1
  fi
done
exit 0
