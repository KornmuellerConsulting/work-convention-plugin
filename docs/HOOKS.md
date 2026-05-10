# Hooks — Inventar

19+ Hooks in `claude/hooks/`. Wiring in `claude/settings.json`.

## SessionStart
- `session-start-identity-pin.sh` — Pinnt Operator/Branch/HEAD in `.claude/state/session-identity.json`
- `session-start-briefing.sh` — Lädt CLAUDE.md, STATUS.md, BLOCKERS.md, Reviewer-Findings ins Context

## UserPromptSubmit
- `userprompt-context-refresh.sh` — Zeigt Hard-Trigger-Hint und Reviewer-Findings
- `userprompt-todo-reminder.sh` — Erinnert an TodoWrite bei Multi-Step-Prompts
- `userprompt-reviewer-trigger.sh` — Triggert Reviewer-Subagent-Hint alle 30 Min

## PreToolUse:Bash
- `pre-bash-escalation-block.sh` — Hard-Block ab Fail #4 ohne Solver
- `pre-bash-head-drift.sh` — Warnt bei extern verändertem HEAD
- `block-secret-body.sh` — Blockt Secret-Patterns in Bash-Bodies
- `block-prod-destructive.sh` — Blockt destructive SQL gegen Prod
- `pre-bash-migration-slot.sh` — Verhindert parallele Migrations
- `pre-bash-test-pre-push.sh` — Triggert pre-push-tests bei git push

## PreToolUse:Edit/Write
- `pre-edit-plugin-files.sh` — Blockt direkte Edits in `.claude/{hooks,agents,...}`
- `pre-edit-monorepo-boundary.sh` — Blockt Cross-App-Edits
- `pre-edit-secret-body.sh` — Defense 2nd-line gegen Secret-Patterns

## PostToolUse
- `escalation-counter.sh` — Zählt Fails, Auto-Reset bei Success
- `posttooluse-status-refresh.sh` — Aktualisiert STATUS.md (throttled 1×/Min)
- `notification-trigger.sh` — Routet Subagent-Resultate

## PostToolUse:Bash
- `post-bash-head-record.sh` — Speichert HEAD nach jedem Bash

## PostToolUse:Edit/Write
- `posttooluse-decision-markup.sh` — Parsed Decision-Blocks, postet als ClickUp-Comment

## Stop
- `stop-handoff-comment.sh` — Postet Hand-off-Comment im aktiven Task
- `stop-completeness.sh` — Diagnose ungelöster Issues

## PreCommit
- `gitleaks-precommit.sh` — Secret-Scan
- `precommit-ticket-id-required.sh` — Erzwingt Conventional-Commit + Ticket-ID

## PrePush
- `pre-branch-fresh.sh` — Local nicht hinter origin/main
- `pre-push-tests.sh` — Lokale Tests vor Push (Audit-Fix #18)

## Tests

```bash
bash .claude/hooks/tests/test-runner.sh           # alle
bash .claude/hooks/tests/test-runner.sh --verbose # mit Output
bash .claude/hooks/tests/test-runner.sh secret    # nur Secret-Tests
```
