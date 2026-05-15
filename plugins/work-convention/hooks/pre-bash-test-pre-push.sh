#!/usr/bin/env bash
# =============================================================================
# pre-bash-test-pre-push.sh — PreToolUse:Bash
# Triggert pre-push-tests.sh wenn git push ausgeführt wird.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

if echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push' && ! echo "$CMD" | grep -q '\-\-no-verify'; then
  PRE_PUSH_HOOK="${CLAUDE_PLUGIN_ROOT}/hooks/pre-push-tests.sh"
  if [ -x "$PRE_PUSH_HOOK" ]; then
    bash "$PRE_PUSH_HOOK" || {
      cat <<MSG >&2
🚫 BLOCKED: Pre-Push-Tests fehlgeschlagen.

Lokale Tests fixen oder bewusst override mit --no-verify (mit Decision-Block).
MSG
      exit 2
    }
  fi
fi
exit 0
