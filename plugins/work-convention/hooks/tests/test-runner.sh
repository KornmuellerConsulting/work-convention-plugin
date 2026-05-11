#!/usr/bin/env bash
# =============================================================================
# test-runner.sh — Tests für alle Hooks (Audit-Fix #14)
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

run_test() {
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

echo "═══ Hook-Tests ═══"

# block-secret-body
run_test "block-secret-body: clean command" 0 \
  bash -c "CLAUDE_TOOL_INPUT_command='ls -la' bash $HOOK_DIR/block-secret-body.sh"
run_test "block-secret-body: anthropic key" 1 \
  bash -c "CLAUDE_TOOL_INPUT_command='echo sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' bash $HOOK_DIR/block-secret-body.sh"

# block-prod-destructive
run_test "block-prod-destructive: clean" 0 \
  bash -c "CLAUDE_TOOL_INPUT_command='echo hello' bash $HOOK_DIR/block-prod-destructive.sh"
run_test "block-prod-destructive: prod drop" 1 \
  bash -c "CLAUDE_TOOL_INPUT_command='psql production -c DROP TABLE users' bash $HOOK_DIR/block-prod-destructive.sh"

# escalation-counter
TMPDIR=$(mktemp -d)
run_test "escalation-counter: success resets" 0 \
  env CLAUDE_PROJECT_DIR=$TMPDIR CLAUDE_TOOL_OUTPUT_exit_code=0 bash $HOOK_DIR/escalation-counter.sh
[ ! -f "$TMPDIR/.claude/state/escalation-counter.state" ] || echo "  ⚠️  counter not reset"
rm -rf "$TMPDIR"

# precommit-ticket-id-required
run_test "precommit: valid format" 0 \
  bash -c "CLAUDE_TOOL_INPUT_message='feat(TODO-42): description' bash $HOOK_DIR/precommit-ticket-id-required.sh"
run_test "precommit: missing ticket" 1 \
  bash -c "CLAUDE_TOOL_INPUT_message='feat: description' bash $HOOK_DIR/precommit-ticket-id-required.sh"

# pre-edit-plugin-files
run_test "pre-edit-plugin: settings.local ok" 0 \
  bash -c "CLAUDE_TOOL_INPUT_file_path='/foo/.claude/settings.local.json' bash $HOOK_DIR/pre-edit-plugin-files.sh"
run_test "pre-edit-plugin: hooks blocked" 1 \
  bash -c "CLAUDE_TOOL_INPUT_file_path='/foo/.claude/hooks/test.sh' bash $HOOK_DIR/pre-edit-plugin-files.sh"

# pre-edit-secret-body
run_test "pre-edit-secret: clean" 0 \
  bash -c "CLAUDE_TOOL_INPUT_new_string='const x = 1' bash $HOOK_DIR/pre-edit-secret-body.sh"
run_test "pre-edit-secret: blocks anthropic" 1 \
  bash -c "CLAUDE_TOOL_INPUT_new_string='key = sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' bash $HOOK_DIR/pre-edit-secret-body.sh"

echo ""
echo "Total: $((PASS+FAIL))"
echo "Pass: $PASS"
echo "Fail: $FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
