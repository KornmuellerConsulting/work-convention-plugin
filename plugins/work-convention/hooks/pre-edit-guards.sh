#!/usr/bin/env bash
# =============================================================================
# pre-edit-guards.sh — PreToolUse:Edit|Write (v2.0: konsolidierter Dispatcher)
#
# Ersetzt drei Einzel-Hooks (ein Prozess-Spawn statt drei pro Edit/Write):
#   1. Plugin-File-Schutz (App-lokale .claude/-Plugin-Folders, key-scoped
#      settings.json — Logik unverändert aus v1.2.4/PLUGIN-Fix übernommen)
#   2. Monorepo-Boundary (Cross-App-Edits)
#   3. Secret-Patterns im File-Content
# =============================================================================
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

INPUT=$(cat 2>/dev/null || echo '{}')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

# --- 1. Plugin-File-Schutz ---------------------------------------------------
plugin_file_guard() {
  case "$FILE" in
    *.claude/settings.local.json) return 0 ;;
    *.claude/state/*) return 0 ;;
    *.claude/app.json) return 0 ;;
    *.claude/hooks/diag-*) return 0 ;;
  esac

  if [[ "$FILE" == *".claude/settings.json"* ]]; then
    local PROTECTED_KEYS=("enabledPlugins" "extraKnownMarketplaces")
    local TOOL_NAME BLOCK_REASON=""
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

    if [ "$TOOL_NAME" = "Write" ]; then
      local NEW_CONTENT OLD_VAL NEW_VAL
      NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
      for key in "${PROTECTED_KEYS[@]}"; do
        # Fehlende/invalide Zieldatei = "Key nicht gesetzt" (null), sonst blockt
        # die Neuanlage einer settings.json mit harmlosem Inhalt fälschlich.
        OLD_VAL=$(jq -c ".${key} // null" "$FILE" 2>/dev/null) || OLD_VAL=null
        [ -z "$OLD_VAL" ] && OLD_VAL=null
        NEW_VAL=$(echo "$NEW_CONTENT" | jq -c ".${key} // null" 2>/dev/null)
        [ -z "$NEW_VAL" ] && NEW_VAL=null
        if [ "$OLD_VAL" != "$NEW_VAL" ]; then
          BLOCK_REASON="Write ändert geschützten Key '$key'"
          break
        fi
      done
    else
      local OLD_STR NEW_STR
      OLD_STR=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
      NEW_STR=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
      for key in "${PROTECTED_KEYS[@]}"; do
        if echo "${OLD_STR}${NEW_STR}" | grep -q "\"$key\""; then
          BLOCK_REASON="Edit berührt geschützten Key '$key'"
          break
        fi
      done
    fi

    if [ -n "$BLOCK_REASON" ]; then
      cat <<MSG >&2
🚫 BLOCKED: $BLOCK_REASON ($FILE)

Plugin-Wiring-Keys (enabledPlugins, extraKnownMarketplaces) werden über
offizielle Plugin-Commands gepflegt (claude plugin install/enable/marketplace),
nicht per Hand editiert. Generische Settings (theme, ...) sind frei editierbar.
MSG
      return 2
    fi
    return 0
  fi

  local BLOCKED_PATTERNS=(
    ".claude/hooks/"
    ".claude/agents/"
    ".claude/skills/"
    ".claude/commands/"
    ".claude/scripts/"
  )
  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$FILE" == *"$pattern"* ]]; then
      cat <<MSG >&2
🚫 BLOCKED: Direkter Edit von Plugin-File: $FILE

Plugin-Files werden über das Plugin-Repo gepflegt:
  https://github.com/KornmuellerConsulting/work-convention-plugin

App-lokale Anpassungen:
  - Settings: .claude/settings.local.json
  - App-Config: .claude/app.json
  - Plugin-PR: editiere Plugin-Repo, dann claude plugin update
MSG
      return 2
    fi
  done
  return 0
}

plugin_file_guard || exit 2

# --- 2. Monorepo-Boundary ----------------------------------------------------
# APP_NAME gezielt extrahieren statt die .env zu sourcen. Verifiziert: ein
# bash -n-Gate vor dem Sourcen schaltete den Guard bei teilinvalider .env
# (z.B. MSG=don't) komplett fail-open — der alte Hook blockte da noch, weil
# beim Sourcen die Variablen VOR dem Parse-Error gesetzt wurden. Extraktion
# ist gegen beides immun.
APP_NAME_ENV=""
if [ -f "$PROJECT_DIR/.env" ]; then
  APP_NAME_ENV=$(sed -n 's/^APP_NAME=//p' "$PROJECT_DIR/.env" 2>/dev/null | head -1 | tr -d '"'"'")
fi

if [ -n "$APP_NAME_ENV" ] && [[ "$FILE" =~ /apps/([^/]+)/ ]]; then
  TARGET_APP="${BASH_REMATCH[1]}"
  if [ "$TARGET_APP" != "$APP_NAME_ENV" ]; then
    cat <<MSG >&2
🚫 BLOCKED: Cross-App-Edit verboten.

Du arbeitest in App "$APP_NAME_ENV", willst aber editieren in: $TARGET_APP

Lösung:
  - Geteilter Code → packages/shared-types/ oder neues packages/shared-*/
  - Bewusste Multi-App-Operation → in der jeweiligen App ausführen
MSG
    exit 2
  fi
fi

# --- 3. Secret-Patterns im Content ------------------------------------------
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)
if [ -n "$CONTENT" ]; then
  SECRET_PATTERNS=(
    'sk-[a-zA-Z0-9_-]{20,}'
    'xoxb-[0-9]{10,}-[a-zA-Z0-9]{20,}'
    'ghp_[a-zA-Z0-9]{36}'
    'AIza[0-9A-Za-z_-]{35}'
    'AKIA[0-9A-Z]{16}'
    'sk_(live|test)_[a-zA-Z0-9]{24,}'
    'rk_(live|test)_[a-zA-Z0-9]{24,}'
  )
  for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qE "$pattern"; then
      cat <<MSG >&2
🚫 BLOCKED: Secret-Pattern in File-Content erkannt.

Pattern: $pattern

Lösung: Secrets in .env (nicht committed), Code via process.env.VAR_NAME.
MSG
      exit 2
    fi
  done
fi

exit 0
