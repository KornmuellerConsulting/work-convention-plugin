#!/usr/bin/env bash
# =============================================================================
# pre-bash-test-pre-push.sh — PreToolUse:Bash
# Triggert pre-push-tests.sh wenn git push ausgeführt wird.
# =============================================================================
set -euo pipefail

CMD="${CLAUDE_TOOL_INPUT_command:-}"
[ -z "$CMD" ] && exit 0

# Match git push (nicht push --no-verify)
if echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+push' && ! echo "$CMD" | grep -q '\-\-no-verify'; then
  PRE_PUSH_HOOK="${CLAUDE_PLUGIN_ROOT}/hooks/pre-push-tests.sh"
  if [ -x "$PRE_PUSH_HOOK" ]; then
    bash "$PRE_PUSH_HOOK" || {
      cat <<MSG >&2
🚫 BLOCKED: Pre-Push-Tests fehlgeschlagen.

Lokale Tests fixen oder bewusst override mit --no-verify (mit Decision-Block).
MSG
      exit 1
    }
  fi
fi
exit 0
