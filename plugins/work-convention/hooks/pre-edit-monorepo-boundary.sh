#!/usr/bin/env bash
# =============================================================================
# pre-edit-monorepo-boundary.sh — PreToolUse:Edit/Write
# Blockt Cross-App-Edits.
# v1.2: stdin-JSON.
# =============================================================================
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ -z "${APP_NAME:-}" ] && exit 0

if [[ "$FILE" =~ /apps/([^/]+)/ ]]; then
  TARGET_APP="${BASH_REMATCH[1]}"
  if [ "$TARGET_APP" != "$APP_NAME" ]; then
    cat <<MSG >&2
🚫 BLOCKED: Cross-App-Edit verboten.

Du arbeitest in App "$APP_NAME", willst aber editieren in: $TARGET_APP

Lösung:
  - Geteilter Code → packages/shared-types/ oder neues packages/shared-*/
  - Bewusste Multi-App-Operation → in der jeweiligen App ausführen
MSG
    exit 2
  fi
fi
exit 0
