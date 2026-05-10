#!/usr/bin/env bash
# =============================================================================
# gitleaks-precommit.sh — PreCommit
# Scant staged files auf Secrets via gitleaks.
# =============================================================================
set -euo pipefail

if ! command -v gitleaks &>/dev/null; then
  echo "⚠️  gitleaks nicht installiert — überspringe Secret-Scan." >&2
  echo "   Install: brew install gitleaks (macOS) oder via https://github.com/gitleaks/gitleaks" >&2
  exit 0
fi

CONFIG="${CLAUDE_PROJECT_DIR}/.claude/scripts/.gitleaks.toml"
[ -f "$CONFIG" ] || CONFIG=""

if [ -n "$CONFIG" ]; then
  gitleaks protect --staged --config="$CONFIG" --redact -v
else
  gitleaks protect --staged --redact -v
fi
