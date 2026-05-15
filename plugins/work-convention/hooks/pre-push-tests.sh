#!/usr/bin/env bash
# =============================================================================
# pre-push-tests.sh — git pre-push hook
# Lokale Test-Verifikation vor Push.
# v1.2: läuft als echter git-Hook.
# =============================================================================
set -uo pipefail

APP_DIR="$(pwd)"
[ ! -f "$APP_DIR/package.json" ] && exit 0

if grep -q '"test"' "$APP_DIR/package.json" 2>/dev/null; then
  # pnpm: --if-present existiert NICHT (würde als turbo-task-arg durchgereicht);
  # daher den Check über das grep oben absichern und direkt aufrufen.
  if command -v pnpm &>/dev/null; then
    pnpm test 2>&1 | tail -20 || exit 1
  elif command -v npm &>/dev/null; then
    npm test --if-present 2>&1 | tail -20 || exit 1
  fi
fi
exit 0
