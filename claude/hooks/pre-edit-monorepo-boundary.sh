#!/usr/bin/env bash
# =============================================================================
# pre-edit-monorepo-boundary.sh — PreToolUse:Edit/Write
# Blockt Cross-App-Edits (apps/<other>/...) wenn man in apps/<this>/ arbeitet.
# =============================================================================
set -euo pipefail

FILE="${CLAUDE_TOOL_INPUT_file_path:-}"
[ -z "$FILE" ] && exit 0
[ -z "${APP_NAME:-}" ] && exit 0

# Match apps/<name>/...
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
    exit 1
  fi
fi
exit 0
