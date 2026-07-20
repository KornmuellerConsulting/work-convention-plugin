#!/usr/bin/env bash
# =============================================================================
# test-runner.sh — Tests für alle Hooks
# v2.0: Suite gegen die konsolidierten Dispatcher (pre-bash-guards,
#       pre-edit-guards, post-tool-state) plus ensure-git-hooks.
#       PreToolUse-Blocks geben exit 2 zurück (Claude-Code-Convention) —
#       inklusive Eskalations-Hard-Block, der bis v1.3 fälschlich exit 1 gab.
#
# Test-Patterns für Secret-Hooks werden zur Laufzeit aus Fragmenten
# zusammengebaut, damit pre-edit-guards dieses File selbst nicht blockt.
# =============================================================================
set -uo pipefail

VERBOSE=0
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1; shift ;;
    --help) echo "Usage: test-runner.sh [--verbose] [filter]"; exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$(cd "$HOOK_DIR/.." && pwd)"
PASS=0; FAIL=0

# Secret-like patterns aus Fragmenten — keines matcht alleine einen Hook-Pattern.
ANTHROPIC_HEAD="s""k-"
ANTHROPIC_BODY="ant-api03-$(printf 'A%.0s' {1..40})"
ANTHROPIC_FAKE="${ANTHROPIC_HEAD}${ANTHROPIC_BODY}"

SLACK_HEAD="xo""xb-"
SLACK_NUM="1234567890"
SLACK_TAIL="-abcdefghijklmnopqrstuvwxyz1234"
SLACK_FAKE="${SLACK_HEAD}${SLACK_NUM}${SLACK_TAIL}"

GH_HEAD="gh""p_"
GH_TAIL="$(printf 'a%.0s' {1..36})"
GH_FAKE="${GH_HEAD}${GH_TAIL}"

skip() { [ -n "$TARGET" ] && [[ "$1" != *"$TARGET"* ]]; }

report() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $name"; PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected $expected, got $actual)"; FAIL=$((FAIL+1))
  fi
}

# Hook mit stdin-JSON ausführen; Env-Overrides als VAR=val-Paare nach dem JSON.
run_test_stdin() {
  local name="$1" expected_exit="$2" hook="$3" json="$4"
  shift 4
  skip "$name" && return 0
  local actual
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$json" | env "$@" bash "$hook"; actual=$?
  else
    echo "$json" | env "$@" bash "$hook" >/dev/null 2>&1; actual=$?
  fi
  report "$name" "$expected_exit" "$actual"
}

run_test_args() {
  local name="$1" expected_exit="$2"
  shift 2
  skip "$name" && return 0
  local actual
  if [ "$VERBOSE" -eq 1 ]; then "$@"; actual=$?
  else "$@" >/dev/null 2>&1; actual=$?; fi
  report "$name" "$expected_exit" "$actual"
}

emit_cmd_json()      { printf '{"tool_input":{"command":"%s"}}' "$1"; }
emit_filepath_json() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }
emit_newstr_json()   { jq -n --arg fp "${2:-/tmp/x.ts}" --arg ns "$1" '{tool_name:"Edit", tool_input:{file_path:$fp, new_string:$ns}}'; }
emit_content_json()  { jq -n --arg fp "${2:-/tmp/x.ts}" --arg c "$1" '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}'; }
emit_edit_json() {
  jq -n --arg fp "$1" --arg old "$2" --arg new "$3" \
    '{tool_name:"Edit", tool_input:{file_path:$fp, old_string:$old, new_string:$new}}'
}
emit_write_json() {
  jq -n --arg fp "$1" --arg content "$2" \
    '{tool_name:"Write", tool_input:{file_path:$fp, content:$content}}'
}

echo "═══ Hook-Tests (v2.0) ═══"

# ---------- pre-bash-guards: Secrets (exit 2 = block) ----------
GUARDS="$HOOK_DIR/pre-bash-guards.sh"
T1="$(mktemp -d)"
run_test_stdin "bash-guards: clean command" 0 "$GUARDS" "$(emit_cmd_json 'ls -la')" CLAUDE_PROJECT_DIR="$T1"
run_test_stdin "bash-guards: anthropic key" 2 "$GUARDS" "$(emit_cmd_json "echo $ANTHROPIC_FAKE")" CLAUDE_PROJECT_DIR="$T1"
run_test_stdin "bash-guards: slack xoxb" 2 "$GUARDS" "$(emit_cmd_json "curl -H $SLACK_FAKE")" CLAUDE_PROJECT_DIR="$T1"
run_test_stdin "bash-guards: github pat" 2 "$GUARDS" "$(emit_cmd_json "git push https://$GH_FAKE@github.com/x/y")" CLAUDE_PROJECT_DIR="$T1"

# ---------- pre-bash-guards: Prod-Destructive ----------
run_test_stdin "bash-guards: drop without prod" 0 "$GUARDS" "$(emit_cmd_json 'psql -c \"DROP TABLE foo\"')" CLAUDE_PROJECT_DIR="$T1"
run_test_stdin "bash-guards: prod drop" 2 "$GUARDS" "$(emit_cmd_json 'psql prod -c \"DROP TABLE foo\"')" CLAUDE_PROJECT_DIR="$T1"
run_test_stdin "bash-guards: live rm-rf" 2 "$GUARDS" "$(emit_cmd_json 'ssh live-server rm -rf /data')" CLAUDE_PROJECT_DIR="$T1"
rm -rf "$T1"

# ---------- pre-bash-guards: Eskalations-Hard-Block ----------
T2="$(mktemp -d)"; mkdir -p "$T2/.claude/state"
echo 4 > "$T2/.claude/state/escalation-counter.state"
run_test_stdin "bash-guards: hard-block bei 4 fails ist exit 2 (v1-Bug gefixt)" 2 \
  "$GUARDS" "$(emit_cmd_json 'ls')" CLAUDE_PROJECT_DIR="$T2"
touch "$T2/.claude/state/solver-activated.flag"
run_test_stdin "bash-guards: solver-flag hebt hard-block auf" 0 \
  "$GUARDS" "$(emit_cmd_json 'ls')" CLAUDE_PROJECT_DIR="$T2"
rm -rf "$T2"

# ---------- pre-bash-guards: Migrations-Slot ----------
T3="$(mktemp -d)"; mkdir -p "$T3/.claude/state"
printf 'CURRENT_OPERATOR="justin"\n' > "$T3/.env"
echo "patrick" > "$T3/.claude/state/migration.lock"
run_test_stdin "bash-guards: migration-slot fremder holder blockt" 2 \
  "$GUARDS" "$(emit_cmd_json 'supabase db push')" CLAUDE_PROJECT_DIR="$T3"
run_test_stdin "bash-guards: nicht-migration befehl ignoriert lock" 0 \
  "$GUARDS" "$(emit_cmd_json 'npm test')" CLAUDE_PROJECT_DIR="$T3"
rm -rf "$T3"

# ---------- pre-edit-guards: Plugin-File-Schutz ----------
EDIT="$HOOK_DIR/pre-edit-guards.sh"
run_test_stdin "edit-guards: settings.local ok" 0 "$EDIT" "$(emit_filepath_json '/app/.claude/settings.local.json')"
run_test_stdin "edit-guards: app.json ok" 0 "$EDIT" "$(emit_filepath_json '/app/.claude/app.json')"
run_test_stdin "edit-guards: hooks blocked" 2 "$EDIT" "$(emit_filepath_json '/app/.claude/hooks/foo.sh')"
run_test_stdin "edit-guards: agents blocked" 2 "$EDIT" "$(emit_filepath_json '/app/.claude/agents/foo.md')"
run_test_stdin "edit-guards: diag-hooks allowed" 0 "$EDIT" "$(emit_filepath_json '/app/.claude/hooks/diag-x.sh')"

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

run_test_stdin "edit-guards: settings.json edit generischer key allowed" 0 \
  "$EDIT" "$(emit_edit_json "$SETTINGS_FIXTURE" '"theme": "dark"' '"theme": "light"')"
run_test_stdin "edit-guards: settings.json edit enabledPlugins blocked" 2 \
  "$EDIT" "$(emit_edit_json "$SETTINGS_FIXTURE" '"enabledPlugins": {"work-convention@kornmueller-empire": true}' '"enabledPlugins": {}')"
run_test_stdin "edit-guards: settings.json write unveraenderte wiring keys allowed" 0 \
  "$EDIT" "$(emit_write_json "$SETTINGS_FIXTURE" '{
  "theme": "light",
  "enabledPlugins": {"work-convention@kornmueller-empire": true},
  "extraKnownMarketplaces": {"kornmueller-empire": {"source": {"source": "github", "repo": "x"}}}
}')"
run_test_stdin "edit-guards: settings.json write dropping enabledPlugins blocked" 2 \
  "$EDIT" "$(emit_write_json "$SETTINGS_FIXTURE" '{"theme": "dark"}')"
rm -rf "$(dirname "$SETTINGS_FIXTURE_DIR")"

# ---------- pre-edit-guards: Monorepo-Boundary ----------
T4="$(mktemp -d)"
printf 'APP_NAME="web"\n' > "$T4/.env"
run_test_stdin "edit-guards: cross-app edit blocked" 2 \
  "$EDIT" "$(emit_filepath_json '/mono/apps/other-app/src/x.ts')" CLAUDE_PROJECT_DIR="$T4"
run_test_stdin "edit-guards: same-app edit ok" 0 \
  "$EDIT" "$(emit_filepath_json '/mono/apps/web/src/x.ts')" CLAUDE_PROJECT_DIR="$T4"
rm -rf "$T4"

# ---------- Verify-Pass-Regressionen (v2.0, Skeptiker-Repros als Tests) ----------
# Teilinvalide .env (Syntaxfehler NACH den relevanten Keys) darf die Guards
# weder fail-open (Boundary) noch fail-closed (Migrations-Lock) kippen.
T7="$(mktemp -d)"; mkdir -p "$T7/.claude/state"
printf 'APP_NAME="web"\nBAD=a(b\n' > "$T7/.env"
run_test_stdin "regression: cross-app block trotz teilinvalider .env" 2 \
  "$EDIT" "$(emit_filepath_json '/mono/apps/other-app/src/x.ts')" CLAUDE_PROJECT_DIR="$T7"
rm -rf "$T7"

T8="$(mktemp -d)"; mkdir -p "$T8/.claude/state"
printf 'CURRENT_OPERATOR="justin"\nBAD=a(b\n' > "$T8/.env"
echo "justin" > "$T8/.claude/state/migration.lock"
run_test_stdin "regression: eigener migration-lock trotz teilinvalider .env" 0 \
  "$GUARDS" "$(emit_cmd_json 'npx prisma migrate dev')" CLAUDE_PROJECT_DIR="$T8"
rm -rf "$T8"

# Write, der eine NEUE settings.json mit harmlosem Inhalt anlegt, darf nicht blocken.
T9="$(mktemp -d)"; mkdir -p "$T9/.claude"
run_test_stdin "regression: neuanlage settings.json ohne wiring-keys erlaubt" 0 \
  "$EDIT" "$(emit_write_json "$T9/.claude/settings.json" '{"theme": "dark"}')"
rm -rf "$T9"

# Leeres/kaputtes stdin darf den Fail-Counter nicht hochzählen.
T10="$(mktemp -d)"
echo '' | env CLAUDE_PROJECT_DIR="$T10" bash "$STATE" >/dev/null 2>&1
if ! skip "regression: leeres stdin zaehlt nicht als fail"; then
  [ ! -f "$T10/.claude/state/escalation-counter.state" ] \
    && report "regression: leeres stdin zaehlt nicht als fail" ok ok \
    || report "regression: leeres stdin zaehlt nicht als fail" ok counted
fi
rm -rf "$T10"

# ---------- pre-edit-guards: Secrets im Content ----------
run_test_stdin "edit-guards: content clean" 0 "$EDIT" "$(emit_newstr_json 'const x = 1')"
run_test_stdin "edit-guards: content anthropic key" 2 "$EDIT" "$(emit_newstr_json "key = $ANTHROPIC_FAKE")"
run_test_stdin "edit-guards: write content github pat" 2 "$EDIT" "$(emit_content_json "TOKEN=$GH_FAKE")"

# ---------- post-tool-state: Eskalations-Counter + HEAD-Record ----------
STATE="$HOOK_DIR/post-tool-state.sh"
T5="$(mktemp -d)"
for i in 1 2 3; do
  echo '{"tool_response":{"is_error":true},"tool_name":"Bash"}' \
    | env CLAUDE_PROJECT_DIR="$T5" bash "$STATE" >/dev/null 2>&1
done
if ! skip "post-state: 3 fails setzen flag"; then
  [ -f "$T5/.claude/state/escalation-3fail.flag" ] \
    && report "post-state: 3 fails setzen flag" ok ok \
    || report "post-state: 3 fails setzen flag" ok missing
fi
echo '{"tool_response":{"exit_code":0},"tool_name":"Bash"}' \
  | env CLAUDE_PROJECT_DIR="$T5" bash "$STATE" >/dev/null 2>&1
if ! skip "post-state: success cleart state"; then
  { [ ! -f "$T5/.claude/state/escalation-counter.state" ] && [ ! -f "$T5/.claude/state/escalation-3fail.flag" ]; } \
    && report "post-state: success cleart state" ok ok \
    || report "post-state: success cleart state" ok remained
fi
rm -rf "$T5"

T6="$(mktemp -d)"
( cd "$T6" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
echo '{"tool_response":{"exit_code":0},"tool_name":"Bash"}' \
  | env CLAUDE_PROJECT_DIR="$T6" bash "$STATE" >/dev/null 2>&1
if ! skip "post-state: bash tool recorded HEAD"; then
  [ -s "$T6/.claude/state/last-head.txt" ] \
    && report "post-state: bash tool recorded HEAD" ok ok \
    || report "post-state: bash tool recorded HEAD" ok missing
fi
rm -rf "$T6"

# ---------- session-start-advisor-cleanup (einmalige Migration) ----------
CLEAN_HOOK="$HOOK_DIR/session-start-advisor-cleanup.sh"
cleanup_fixture() {
  local seed="$1" home
  home="$(mktemp -d)"; mkdir -p "$home/.claude"
  echo "$seed" > "$home/.claude/settings.json"
  echo "$home"
}
assert_eq() {
  local name="$1" expected="$2" actual="$3"
  skip "$name" && return 0
  report "$name" "$expected" "$actual"
}

FX="$(cleanup_fixture '{"theme":"dark","advisorModel":"opus"}')"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: entfernt advisorModel" "-" "$(jq -r '.advisorModel // "-"' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: andere keys bleiben" "dark" "$(jq -r '.theme' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: marker gesetzt" "yes" "$([ -f "$FX/.claude/.work-convention-advisor-cleanup.done" ] && echo yes || echo no)"
assert_eq "advisor-cleanup: backup angelegt" "opus" "$(jq -r '.advisorModel' "$FX/.claude/settings.json.pre-advisor-cleanup.bak" 2>/dev/null)"
jq '.advisorModel = "sonnet"' "$FX/.claude/settings.json" > "$FX/tmp" && mv "$FX/tmp" "$FX/.claude/settings.json"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: zweiter lauf laesst spaetere wahl stehen" "sonnet" "$(jq -r '.advisorModel // "-"' "$FX/.claude/settings.json")"
rm -rf "$FX"

FX="$(cleanup_fixture '{"theme":"dark"}')"
HOME="$FX" bash "$CLEAN_HOOK" >/dev/null 2>&1
assert_eq "advisor-cleanup: noop ohne advisorModel" "dark" "$(jq -r '.theme' "$FX/.claude/settings.json")"
assert_eq "advisor-cleanup: marker auch beim noop" "yes" "$([ -f "$FX/.claude/.work-convention-advisor-cleanup.done" ] && echo yes || echo no)"
rm -rf "$FX"

# ---------- session-start-ensure-git-hooks ----------
ENSURE="$HOOK_DIR/session-start-ensure-git-hooks.sh"
mk_repo() {
  local d; d="$(mktemp -d)"
  ( cd "$d" && git init -q )
  echo "$d"
}

# a) Frische Empire-App (.env-Marker) -> installiert
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: empire-app frisch installiert" "yes" \
  "$([ -x "$R/.git/hooks/commit-msg" ] && grep -q 'auto-generated by work-convention' "$R/.git/hooks/commit-msg" && echo yes || echo no)"
# b) Zweiter Lauf: still und idempotent
OUT=$(env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" 2>&1)
assert_eq "ensure-hooks: zweiter lauf still" "" "$OUT"
# c) Stale Pfad -> refresh auf aktuellen PLUGIN_ROOT
sed -i.bak 's|'"$PLUGIN_DIR"'|/old/cache/1.2.4|g' "$R/.git/hooks/commit-msg" && rm -f "$R/.git/hooks/commit-msg.bak"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: stale pfad wird refresht" "yes" \
  "$(grep -q "$PLUGIN_DIR" "$R/.git/hooks/commit-msg" && echo yes || echo no)"
rm -rf "$R"

# d) Fremdes Repo ohne Marker/.env -> nicht angefasst
R="$(mk_repo)"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: fremdes repo unangetastet" "no" \
  "$([ -f "$R/.git/hooks/commit-msg" ] && echo yes || echo no)"
rm -rf "$R"

# e) Fremder existierender Hook -> nie ueberschreiben
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
mkdir -p "$R/.git/hooks"; echo '#!/bin/sh # husky' > "$R/.git/hooks/commit-msg"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: fremder hook bleibt" "husky" \
  "$(grep -o husky "$R/.git/hooks/commit-msg" 2>/dev/null || echo overwritten)"
rm -rf "$R"

# f) Ohne CLAUDE_PLUGIN_ROOT -> exit 0, nichts passiert
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
run_test_args "ensure-hooks: ohne CLAUDE_PLUGIN_ROOT ueberlebt" 0 \
  env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$R" bash "$ENSURE"
rm -rf "$R"

# h) core.hooksPath gesetzt (husky-Style) -> nicht anfassen, warnen
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
( cd "$R" && git config core.hooksPath .husky )
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: core.hooksPath -> keine installation" "no" \
  "$([ -f "$R/.git/hooks/commit-msg" ] && echo yes || echo no)"
rm -rf "$R"

# i) Marker + aktueller Pfad, aber Executable-Bit fehlt -> refresh stellt +x her
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
chmod -x "$R/.git/hooks/pre-push"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: fehlendes exec-bit wird als stale erkannt" "yes" \
  "$([ -x "$R/.git/hooks/pre-push" ] && echo yes || echo no)"
rm -rf "$R"

# j) Substring-Falle: Wrapper zeigt auf <aktueller-pfad>-old -> muss stale sein
R="$(mk_repo)"; printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R/.env"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
sed -i.bak "s|$PLUGIN_DIR|$PLUGIN_DIR-old|g" "$R/.git/hooks/commit-msg" && rm -f "$R/.git/hooks/commit-msg.bak"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: substring-pfad gilt nicht als frisch" "yes" \
  "$(grep -qF "\"$PLUGIN_DIR/" "$R/.git/hooks/commit-msg" && echo yes || echo no)"
rm -rf "$R"

# g) Linked Worktree -> Hooks landen im COMMON dir, nicht im worktrees/-Subdir
#    (git liest Hooks nur aus dem Common Dir; --git-dir dort wäre stiller No-op)
R="$(mk_repo)"
( cd "$R" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && git worktree add -q "$R-wt" -b wt-branch )
printf 'APP_PROJECT_PREFIX="TEST"\n' > "$R-wt/.env"
env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_PROJECT_DIR="$R-wt" bash "$ENSURE" >/dev/null 2>&1
assert_eq "ensure-hooks: worktree installiert ins common dir" "yes" \
  "$([ -x "$R/.git/hooks/commit-msg" ] && grep -q 'auto-generated by work-convention' "$R/.git/hooks/commit-msg" && echo yes || echo no)"
assert_eq "ensure-hooks: nichts im worktrees/-hooks-subdir" "no" \
  "$([ -f "$R/.git/worktrees/$(basename "$R-wt")/hooks/commit-msg" ] && echo yes || echo no)"
( cd "$R" && git worktree remove --force "$R-wt" 2>/dev/null ) || true
rm -rf "$R" "$R-wt"

# ---------- precommit-ticket-id-required (git commit-msg hook) ----------
TICKET="$HOOK_DIR/precommit-ticket-id-required.sh"
MSGF="$(mktemp)"
echo 'feat(TEST-1): valid message' > "$MSGF"
run_test_args "precommit: valid format" 0 bash "$TICKET" "$MSGF"
echo 'fix stuff' > "$MSGF"
run_test_args "precommit: missing ticket" 1 bash "$TICKET" "$MSGF"
echo 'feat(TEST-2)!: breaking change' > "$MSGF"
run_test_args "precommit: breaking marker" 0 bash "$TICKET" "$MSGF"
echo 'Merge branch main into x' > "$MSGF"
run_test_args "precommit: merge commit skipped" 0 bash "$TICKET" "$MSGF"
rm -f "$MSGF"

# ---------- CLAUDE_PLUGIN_ROOT-Härtung: kein Hook stirbt unter set -u ----------
for hookname in pre-bash-guards.sh pre-edit-guards.sh post-tool-state.sh stop-completeness.sh userprompt-context-refresh.sh; do
  name="plugin-root: $hookname ueberlebt ohne CLAUDE_PLUGIN_ROOT"
  skip "$name" && continue
  T="$(mktemp -d)"
  echo '{}' | env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$T" bash "$HOOK_DIR/$hookname" >/dev/null 2>&1
  report "$name" 0 $?
  rm -rf "$T"
done

# ---------- Agent-Frontmatter: jeder Agent MUSS einen Model-Pin haben ----------
AGENT_DIR="$(cd "$HOOK_DIR/../agents" && pwd)"
for agent_file in "$AGENT_DIR"/*.md; do
  agent_name="$(basename "$agent_file" .md)"
  skip "agents: $agent_name" && continue
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
