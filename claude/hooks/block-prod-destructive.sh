#!/usr/bin/env bash
# =============================================================================
# block-prod-destructive.sh — PreToolUse:Bash
# Blockt destructive SQL/Commands gegen Production-DB.
# =============================================================================
set -euo pipefail
CMD="${CLAUDE_TOOL_INPUT_command:-}"
[ -z "$CMD" ] && exit 0

# Indikatoren für Prod-Targeting
PROD_INDICATORS=(
  "prod"
  "production"
  "live"
  "SUPABASE_PROJECT_REF_PROD"
)

# Destructive keywords
DESTRUCTIVE=(
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE"
  "DELETE FROM"
  "DROP SCHEMA"
)

CMD_UPPER=$(echo "$CMD" | tr '[:lower:]' '[:upper:]')

is_prod=false
for ind in "${PROD_INDICATORS[@]}"; do
  if echo "$CMD_UPPER" | grep -qiE "\b$ind\b"; then
    is_prod=true; break
  fi
done

is_destructive=false
for kw in "${DESTRUCTIVE[@]}"; do
  if echo "$CMD_UPPER" | grep -q "$kw"; then
    is_destructive=true; break
  fi
done

if $is_prod && $is_destructive; then
  cat <<MSG >&2
🚫 BLOCKED: Destructive Command gegen Production erkannt.

Command: $CMD

Production-Operations laufen via:
  - Migrations: CI-Workflow ci-deploy-prod.yaml (5min Abort-Window)
  - Manuelle Eingriffe: Decision-Block + beide Co-Founder confirm
MSG
  exit 1
fi
exit 0
