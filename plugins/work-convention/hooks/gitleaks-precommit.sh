#!/usr/bin/env bash
# =============================================================================
# gitleaks-precommit.sh — git pre-commit hook
# Scant staged files auf Secrets via gitleaks.
# v1.2: läuft als echter git-Hook via core.hooksPath.
# =============================================================================
set -uo pipefail

if ! command -v gitleaks &>/dev/null; then
  echo "⚠️  gitleaks nicht installiert — überspringe Secret-Scan." >&2
  echo "   Install: brew install gitleaks (macOS) oder via https://github.com/gitleaks/gitleaks" >&2
  exit 0
fi

# Plugin-Root: entweder env-var (von wrapper-script gesetzt) oder relativ zum Script
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG="$PLUGIN_ROOT/scripts/.gitleaks.toml"
[ -f "$CONFIG" ] || CONFIG=""

if [ -n "$CONFIG" ]; then
  gitleaks protect --staged --config="$CONFIG" --redact -v
else
  gitleaks protect --staged --redact -v
fi
