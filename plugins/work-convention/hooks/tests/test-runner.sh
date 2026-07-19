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

# ---------- session-start-advisor-default (SessionStart, side-effect auf settings.json) ----------
# Der Hook schreibt in $HOME/.claude/settings.json — wird daher mit isoliertem
# HOME in einer Subshell getestet. Erwartung ist der advisorModel-Wert nachher
# ('-' = Key darf gar nicht existieren).
assert_advisor() {
  local name="$1" expected="$2" seed="$3"
  shift 3   # Rest: VAR=wert-Paare für die Hook-Umgebung

  if [ -n "$TARGET" ] && [[ "$name" != *"$TARGET"* ]]; then
    return 0
  fi

  local fixture actual
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/.claude"
  echo "$seed" > "$fixture/.claude/settings.json"

  # Isoliertes HOME + leeres PROJECT_DIR (kein .env), damit nur die explizit
  # übergebenen Vars wirken.
  env -u WORK_CONVENTION_ADVISOR_DEFAULT -u CLAUDE_CODE_DISABLE_ADVISOR_TOOL \
    HOME="$fixture" CLAUDE_PROJECT_DIR="$fixture" "$@" \
    bash "$HOOK_DIR/session-start-advisor-default.sh" >/dev/null 2>&1

  actual="$(jq -r '.advisorModel // "-"' "$fixture/.claude/settings.json" 2>/dev/null)"
  rm -rf "$fixture"

  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected advisorModel=$expected, got $actual)"
    FAIL=$((FAIL+1))
  fi
}

assert_advisor "advisor-default: ohne Opt-in wird NICHT geschrieben (v1.3.0-Default)" \
  "-" '{"theme":"dark"}'

assert_advisor "advisor-default: =off schreibt nicht" \
  "-" '{"theme":"dark"}' WORK_CONVENTION_ADVISOR_DEFAULT=off

assert_advisor "advisor-default: =OFF case-insensitive" \
  "-" '{"theme":"dark"}' WORK_CONVENTION_ADVISOR_DEFAULT=OFF

assert_advisor "advisor-default: leerer Wert schreibt nicht" \
  "-" '{"theme":"dark"}' WORK_CONVENTION_ADVISOR_DEFAULT=

assert_advisor "advisor-default: DISABLE_ADVISOR_TOOL=1 schreibt nicht" \
  "-" '{"theme":"dark"}' CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1

assert_advisor "advisor-default: DISABLE gewinnt gegen expliziten Wert" \
  "-" '{"theme":"dark"}' CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1 WORK_CONVENTION_ADVISOR_DEFAULT=opus

assert_advisor "advisor-default: =sonnet schreibt sonnet" \
  "sonnet" '{"theme":"dark"}' WORK_CONVENTION_ADVISOR_DEFAULT=sonnet

assert_advisor "advisor-default: bestehende Wahl wird nie überschrieben" \
  "haiku" '{"advisorModel":"haiku"}' WORK_CONVENTION_ADVISOR_DEFAULT=opus

# ---------- session-start-advisor-cleanup (einmalige v1.2.4-Migration) ----------
# Isoliertes HOME: der Hook liest settings.json UND schreibt sein Marker-File
# beides unter $HOME/.claude/.
CLEAN_HOOK="$HOOK_DIR/session-start-advisor-cleanup.sh"

cleanup_fixture() {
  local seed="$1" home
  home="$(mktemp -d)"
  mkdir -p "$home/.claude"
  echo "$seed" > "$home/.claude/settings.json"
  echo "$home"
}
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ -n "$TARGET" ] && [[ "$name" != *"$TARGET"* ]]; then return 0; fi
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"; PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected '$expected', got '$actual')"; FAIL=$((FAIL+1))
  fi
}

# 1. advisorModel=opus wird entfernt
FX="$(cleanup_fixture '{"theme":"dark","advisorModel":"opus"}')"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: entfernt advisorModel" \
  "-" "$(jq -r '.advisorModel // "-"' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: andere Keys bleiben unberührt" \
  "dark" "$(jq -r '.theme' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: Marker gesetzt" \
  "yes" "$([ -f "$FX/.claude/.work-convention-advisor-cleanup.done" ] && echo yes || echo no)"
assert_eq "advisor-cleanup: Backup angelegt" \
  "opus" "$(jq -r '.advisorModel' "$FX/.claude/settings.json.pre-advisor-cleanup.bak" 2>/dev/null)"

# 2. Zweiter Lauf fasst eine neue, bewusste Wahl NICHT mehr an — das ist der
#    ganze Zweck des Markers. Ohne ihn wäre die Migration eine Zwangsjacke.
jq '.advisorModel = "sonnet"' "$FX/.claude/settings.json" > "$FX/tmp" && mv "$FX/tmp" "$FX/.claude/settings.json"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: zweiter Lauf lässt spätere Wahl stehen" \
  "sonnet" "$(jq -r '.advisorModel // "-"' "$FX/.claude/settings.json")"
rm -rf "$FX"

# 3. Nichts zu tun, wenn kein advisorModel da ist
FX="$(cleanup_fixture '{"theme":"dark"}')"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: noop ohne advisorModel" \
  "dark" "$(jq -r '.theme' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: Marker auch beim noop" \
  "yes" "$([ -f "$FX/.claude/.work-convention-advisor-cleanup.done" ] && echo yes || echo no)"
rm -rf "$FX"

# 4. Cleanup + Setter zusammen: der Setter darf nicht sofort wieder schreiben
#    (das war der Ordering-Bug beim Umbau).
FX="$(cleanup_fixture '{"advisorModel":"opus"}')"
env -u WORK_CONVENTION_ADVISOR_DEFAULT -u CLAUDE_CODE_DISABLE_ADVISOR_TOOL \
  HOME="$FX" CLAUDE_PROJECT_DIR="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
env -u WORK_CONVENTION_ADVISOR_DEFAULT -u CLAUDE_CODE_DISABLE_ADVISOR_TOOL \
  HOME="$FX" CLAUDE_PROJECT_DIR="$FX" bash "$HOOK_DIR/session-start-advisor-default.sh" >/dev/null 2>&1
assert_eq "advisor-cleanup: Setter schreibt danach nicht zurück" \
  "-" "$(jq -r '.advisorModel // "-"' "$FX/.claude/settings.json")"
rm -rf "$FX"

# ---------- CLAUDE_PLUGIN_ROOT-Härtung ----------
# Claude Code setzt die Variable im Normalbetrieb. Ist sie es mal nicht, darf
# kein Hook unter `set -u` an der Zuweisung sterben — die [ -f ]/[ -x ]-Guards
# direkt darunter sollen greifen können. Kritisch bei pre-bash-test-pre-push:
# stirbt der mit exit 1, blockt er NICHT (nur exit 2 blockt) und der Push geht
# ungetestet durch. Fail-open statt fail-closed.
assert_no_plugin_root() {
  local name="$1" hook="$2" json="$3" setup="$4"

  if [ -n "$TARGET" ] && [[ "$name" != *"$TARGET"* ]]; then return 0; fi

  local sb code
  sb="$(mktemp -d)"
  mkdir -p "$sb/.claude/state"
  [ -n "$setup" ] && ( cd "$sb" && eval "$setup" )

  echo "$json" | timeout 5 env -u CLAUDE_PLUGIN_ROOT \
    HOME="$sb" CLAUDE_PROJECT_DIR="$sb" bash "$HOOK_DIR/$hook" >/dev/null 2>&1
  code=$?
  rm -rf "$sb"

  if [ "$code" -eq 0 ]; then
    echo "  ✅ $name"; PASS=$((PASS+1))
  else
    echo "  ❌ $name (exit $code — vermutlich unbound variable unter set -u)"
    FAIL=$((FAIL+1))
  fi
}

assert_no_plugin_root "plugin-root: status-refresh überlebt ohne CLAUDE_PLUGIN_ROOT" \
  "posttooluse-status-refresh.sh" '{}' ""

assert_no_plugin_root "plugin-root: pre-push-Guard überlebt (sonst fail-open!)" \
  "pre-bash-test-pre-push.sh" '{"tool_input":{"command":"git push origin main"}}' ""

assert_no_plugin_root "plugin-root: notification-trigger überlebt mit Subagent-Output" \
  "notification-trigger.sh" '{}' 'echo "{\"severity\":\"info\"}" > .claude/state/last-subagent.json'

assert_no_plugin_root "plugin-root: stop-handoff überlebt mit aktivem Ticket" \
  "stop-handoff-comment.sh" '{}' 'echo "LAV-999" > .claude/state/active-ticket.txt'

# ---------- Agent-Frontmatter (Model-Routing v1.3.0) ----------
# Jeder Agent MUSS ein explizites model: haben — ohne Pin erbt er das
# Hauptmodell, und bei Opus-Main läuft dann z.B. der 30-Min-Reviewer auf Opus.
AGENT_DIR="$(cd "$HOOK_DIR/../agents" && pwd)"
for agent_file in "$AGENT_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  if [ -n "$TARGET" ] && [[ "agents: $agent_name" != *"$TARGET"* ]]; then
    continue
  fi
  model_line="$(awk '/^---$/{n++; next} n==1 && /^model:/{print; exit}' "$agent_file")"
  if [ -n "$model_line" ]; then
    echo "  ✅ agents: $agent_name hat expliziten Model-Pin (${model_line#model: })"
    PASS=$((PASS+1))
  else
    echo "  ❌ agents: $agent_name ohne model: — erbt Hauptmodell"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "Total: $((PASS+FAIL))"
echo "Pass:  $PASS"
echo "Fail:  $FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
