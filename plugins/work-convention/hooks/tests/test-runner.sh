#!/usr/bin/env bash
# =============================================================================
# test-runner.sh — Tests für alle Hooks
# v1.2: PreToolUse/PostToolUse-Hooks parsen stdin-JSON statt env-vars.
#       PreToolUse-Blocks geben exit 2 zurück (Claude-Code-Convention).
#       precommit-ticket-id-required ist git-Hook mit MSG-File als $1.
#
# Test-Patterns für Secret-Hooks werden zur Laufzeit aus Fragmenten
# zusammengebaut, damit der pre-edit-secret-body-Hook dieses File selbst
# nicht blockt (würde sonst PreToolUse:Write killen).
# =============================================================================
set -uo pipefail

VERBOSE=0
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1; shift ;;
    --help) echo "Usage: test-runner.sh [--verbose] [hook-name]"; exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

# Secret-like patterns aus Fragmenten — keines der Fragmente matcht alleine
# einen Hook-Pattern. Erst die Konkatenation triggert.
ANTHROPIC_HEAD="s""k-"      # 'sk-'  — alleine matcht NICHT 'sk-[a-z0-9_-]{20,}'
ANTHROPIC_BODY="ant-api03-$(printf 'A%.0s' {1..40})"
ANTHROPIC_FAKE="${ANTHROPIC_HEAD}${ANTHROPIC_BODY}"

SLACK_HEAD="xo""xb-"        # 'xoxb-' alleine — kein Match
SLACK_NUM="1234567890"      # ≥10 digits für [0-9]{10,}
SLACK_TAIL="-abcdefghijklmnopqrstuvwxyz1234"   # '-' + ≥20 [a-zA-Z0-9]
SLACK_FAKE="${SLACK_HEAD}${SLACK_NUM}${SLACK_TAIL}"

GH_HEAD="gh""p_"            # 'ghp_' alleine — kein Match
GH_TAIL="$(printf 'a%.0s' {1..36})"
GH_FAKE="${GH_HEAD}${GH_TAIL}"

run_test_stdin() {
  local name="$1"
  local expected_exit="$2"
  local hook="$3"
  local json="$4"

  if [ -n "$TARGET" ] && [[ "$name" != *"$TARGET"* ]]; then
    return 0
  fi

  local actual_exit
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$json" | bash "$hook"
    actual_exit=$?
  else
    echo "$json" | bash "$hook" >/dev/null 2>&1
    actual_exit=$?
  fi

  if [ "$actual_exit" = "$expected_exit" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected $expected_exit, got $actual_exit)"
    FAIL=$((FAIL+1))
  fi
}

run_test_args() {
  local name="$1"
  local expected_exit="$2"
  shift 2

  if [ -n "$TARGET" ] && [[ "$name" != *"$TARGET"* ]]; then
    return 0
  fi

  local actual_exit
  if [ "$VERBOSE" -eq 1 ]; then
    "$@"
    actual_exit=$?
  else
    "$@" >/dev/null 2>&1
    actual_exit=$?
  fi

  if [ "$actual_exit" = "$expected_exit" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected $expected_exit, got $actual_exit)"
    FAIL=$((FAIL+1))
  fi
}

# Helper für JSON-Tests mit assembled secret strings (komfortabler als Inline-JSON)
emit_cmd_json() {
  printf '{"tool_input":{"command":"%s"}}' "$1"
}
emit_filepath_json() {
  printf '{"tool_input":{"file_path":"%s"}}' "$1"
}
emit_newstr_json() {
  printf '{"tool_input":{"new_string":"%s"}}' "$1"
}
emit_content_json() {
  printf '{"tool_input":{"content":"%s"}}' "$1"
}
emit_edit_json() {
  jq -n --arg fp "$1" --arg old "$2" --arg new "$3" \
    '{tool_name:"Edit", tool_input:{file_path:$fp, old_string:$old, new_string:$new}}'
}
emit_write_json() {
  jq -n --arg fp "$1" --arg content "$2" \
    '{tool_name:"Write", tool_input:{file_path:$fp, content:$content}}'
}

echo "═══ Hook-Tests ═══"

# ---------- block-secret-body (PreToolUse:Bash, exit 2 = block) ----------
run_test_stdin "block-secret-body: clean command" 0 \
  "$HOOK_DIR/block-secret-body.sh" \
  "$(emit_cmd_json 'ls -la')"

run_test_stdin "block-secret-body: anthropic key" 2 \
  "$HOOK_DIR/block-secret-body.sh" \
  "$(emit_cmd_json "echo $ANTHROPIC_FAKE")"

run_test_stdin "block-secret-body: slack xoxb" 2 \
  "$HOOK_DIR/block-secret-body.sh" \
  "$(emit_cmd_json "curl -H Authorization:$SLACK_FAKE")"

run_test_stdin "block-secret-body: github pat" 2 \
  "$HOOK_DIR/block-secret-body.sh" \
  "$(emit_cmd_json "curl -H Authorization:$GH_FAKE")"

# ---------- block-prod-destructive (PreToolUse:Bash, exit 2 = block) ----------
run_test_stdin "block-prod-destructive: clean" 0 \
  "$HOOK_DIR/block-prod-destructive.sh" \
  "$(emit_cmd_json 'echo hello')"

run_test_stdin "block-prod-destructive: drop without prod" 0 \
  "$HOOK_DIR/block-prod-destructive.sh" \
  "$(emit_cmd_json 'DROP TABLE users')"

run_test_stdin "block-prod-destructive: prod drop" 2 \
  "$HOOK_DIR/block-prod-destructive.sh" \
  "$(emit_cmd_json 'psql production -c DROP TABLE users')"

run_test_stdin "block-prod-destructive: live rm-rf" 2 \
  "$HOOK_DIR/block-prod-destructive.sh" \
  "$(emit_cmd_json 'ssh live-host rm -rf /var/data')"

# ---------- escalation-counter (PostToolUse, exit 0 always; check side-effects) ----------
TMPDIR=$(mktemp -d)
export CLAUDE_PROJECT_DIR="$TMPDIR"
# 3 Fails → flag setzen
for i in 1 2 3; do
  echo '{"tool_response":{"is_error":true},"tool_name":"Bash"}' \
    | bash "$HOOK_DIR/escalation-counter.sh" >/dev/null 2>&1
done
if [ -f "$TMPDIR/.claude/state/escalation-3fail.flag" ]; then
  echo "  ✅ escalation-counter: 3 fails → flag set"
  PASS=$((PASS+1))
else
  echo "  ❌ escalation-counter: 3 fails → flag NOT set"
  FAIL=$((FAIL+1))
fi
# Success → counter und flag löschen
echo '{"tool_response":{"exit_code":0},"tool_name":"Bash"}' \
  | bash "$HOOK_DIR/escalation-counter.sh" >/dev/null 2>&1
if [ ! -f "$TMPDIR/.claude/state/escalation-counter.state" ] && \
   [ ! -f "$TMPDIR/.claude/state/escalation-3fail.flag" ]; then
  echo "  ✅ escalation-counter: success clears state"
  PASS=$((PASS+1))
else
  echo "  ❌ escalation-counter: success did NOT clear state"
  FAIL=$((FAIL+1))
fi
unset CLAUDE_PROJECT_DIR
rm -rf "$TMPDIR"

# ---------- precommit-ticket-id-required (git commit-msg hook, $1 = msg-file) ----------
TMPMSG=$(mktemp)
echo "feat(TODO-42): description" > "$TMPMSG"
run_test_args "precommit: valid format" 0 \
  bash "$HOOK_DIR/precommit-ticket-id-required.sh" "$TMPMSG"

echo "feat: description" > "$TMPMSG"
run_test_args "precommit: missing ticket" 1 \
  bash "$HOOK_DIR/precommit-ticket-id-required.sh" "$TMPMSG"

echo "fix(TODO-43)!: breaking change" > "$TMPMSG"
run_test_args "precommit: breaking marker" 0 \
  bash "$HOOK_DIR/precommit-ticket-id-required.sh" "$TMPMSG"

echo "Merge branch 'main'" > "$TMPMSG"
run_test_args "precommit: merge commit skipped" 0 \
  bash "$HOOK_DIR/precommit-ticket-id-required.sh" "$TMPMSG"
rm -f "$TMPMSG"

# ---------- pre-edit-plugin-files (PreToolUse:Edit, exit 2 = block) ----------
run_test_stdin "pre-edit-plugin: settings.local ok" 0 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_filepath_json '/foo/.claude/settings.local.json')"

run_test_stdin "pre-edit-plugin: app.json ok" 0 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_filepath_json '/foo/.claude/app.json')"

run_test_stdin "pre-edit-plugin: hooks blocked" 2 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_filepath_json '/foo/.claude/hooks/test.sh')"

run_test_stdin "pre-edit-plugin: agents blocked" 2 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_filepath_json '/foo/.claude/agents/builder.md')"

run_test_stdin "pre-edit-plugin: diag-hooks allowed" 0 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_filepath_json '/foo/.claude/hooks/diag-trace.sh')"

# settings.json ist key-scoped: nur enabledPlugins/extraKnownMarketplaces
# sind geschützt, generische Settings (advisorModel, theme, ...) sind frei.
SETTINGS_FIXTURE_DIR="$(mktemp -d)/.claude"
mkdir -p "$SETTINGS_FIXTURE_DIR"
SETTINGS_FIXTURE="$SETTINGS_FIXTURE_DIR/settings.json"
cat > "$SETTINGS_FIXTURE" <<'JSON'
{
  "theme": "dark",
  "enabledPlugins": {"work-convention@kornmueller-empire": true},
  "extraKnownMarketplaces": {"kornmueller-empire": {"source": {"source": "github", "repo": "x"}}}
}
JSON

run_test_stdin "pre-edit-plugin: settings.json edit of generic key allowed" 0 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_edit_json "$SETTINGS_FIXTURE" '"theme": "dark"' '"theme": "dark",
  "advisorModel": "opus"')"

run_test_stdin "pre-edit-plugin: settings.json edit touching enabledPlugins blocked" 2 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_edit_json "$SETTINGS_FIXTURE" '"enabledPlugins": {"work-convention@kornmueller-empire": true}' '"enabledPlugins": {}')"

run_test_stdin "pre-edit-plugin: settings.json write with unchanged wiring keys allowed" 0 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_write_json "$SETTINGS_FIXTURE" '{
  "theme": "light",
  "advisorModel": "opus",
  "enabledPlugins": {"work-convention@kornmueller-empire": true},
  "extraKnownMarketplaces": {"kornmueller-empire": {"source": {"source": "github", "repo": "x"}}}
}')"

run_test_stdin "pre-edit-plugin: settings.json write dropping enabledPlugins blocked" 2 \
  "$HOOK_DIR/pre-edit-plugin-files.sh" \
  "$(emit_write_json "$SETTINGS_FIXTURE" '{
  "theme": "dark",
  "extraKnownMarketplaces": {"kornmueller-empire": {"source": {"source": "github", "repo": "x"}}}
}')"

rm -rf "$(dirname "$SETTINGS_FIXTURE_DIR")"

# ---------- pre-edit-secret-body (PreToolUse:Edit/Write, exit 2 = block) ----------
run_test_stdin "pre-edit-secret: clean" 0 \
  "$HOOK_DIR/pre-edit-secret-body.sh" \
  "$(emit_newstr_json 'const x = 1')"

run_test_stdin "pre-edit-secret: blocks anthropic" 2 \
  "$HOOK_DIR/pre-edit-secret-body.sh" \
  "$(emit_newstr_json "key = $ANTHROPIC_FAKE")"

run_test_stdin "pre-edit-secret: Write tool content" 2 \
  "$HOOK_DIR/pre-edit-secret-body.sh" \
  "$(emit_content_json "TOKEN=$GH_FAKE")"

echo ""
echo "Total: $((PASS+FAIL))"
echo "Pass:  $PASS"
echo "Fail:  $FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
