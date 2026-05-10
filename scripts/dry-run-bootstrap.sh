#!/usr/bin/env bash
# =============================================================================
# dry-run-bootstrap.sh — Test bootstrap-app.sh ohne externe Calls
# =============================================================================
set -euo pipefail

NAME="${1:-test-app}"
PREFIX="${2:-TEST}"

echo "🧪 Dry-Run: bootstrap-app.sh --name $NAME --prefix $PREFIX --dry-run"
MONOREPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -f "$MONOREPO_ROOT/scripts/bootstrap-app.sh" ]; then
  bash "$MONOREPO_ROOT/scripts/bootstrap-app.sh" --name "$NAME" --prefix "$PREFIX" --dry-run
else
  echo "ℹ️  bootstrap-app.sh nicht gefunden — Plugin nicht im Monorepo-Setup?"
fi
