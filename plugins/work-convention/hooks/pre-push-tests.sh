#!/usr/bin/env bash
# =============================================================================
# pre-push-tests.sh — PrePush
# Audit-Fix #18: Lokale Test-Verifikation vor Push.
# =============================================================================
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
APP_DIR="$PROJECT_DIR"

# Detection: pnpm/npm/yarn?
if [ ! -f "$APP_DIR/package.json" ]; then
  exit 0
fi

# Versuche test-Script
if grep -q '"test"' "$APP_DIR/package.json" 2>/dev/null; then
  cd "$APP_DIR"
  if command -v pnpm &>/dev/null; then
    pnpm run test --if-present 2>&1 | tail -20 || exit 1
  elif command -v npm &>/dev/null; then
    npm test --if-present 2>&1 | tail -20 || exit 1
  fi
fi
exit 0
