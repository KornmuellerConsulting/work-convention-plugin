#!/usr/bin/env bash
# =============================================================================
# secret.sh — Hilfsscript um Werte aus .env zu lesen ohne sie auszugeben
# =============================================================================
set -euo pipefail

KEY="${1:?Usage: secret.sh VAR_NAME}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "" >&2
  exit 1
fi

VALUE=$(grep -E "^${KEY}=" "$PROJECT_DIR/.env" | head -1 | cut -d= -f2- | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
[ -z "$VALUE" ] && exit 1
printf '%s' "$VALUE"
