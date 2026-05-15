# Changelog

Alle bemerkenswerten Änderungen am Plugin werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung folgt [Semver](https://semver.org/lang/de/).

## [1.2.1] — 2026-05-15

### Fixed

- **Hooks sourcen `$CLAUDE_PROJECT_DIR/.env`.** Bisher lasen die Hooks `CURRENT_OPERATOR`, `APP_NAME`, `CLICKUP_*`, `SLACK_BOT_TOKEN` etc. direkt aus der Shell-env — was nur funktionierte, wenn der User die Vars selbst exportiert hatte. In Worktrees ohne sourced `.env` zeigte `/where` und das Session-Briefing daher `operator: unknown` und `App: (unbekannt)`. Fix in den fünf betroffenen Hooks:
  - `session-start-identity-pin.sh` (pinnt jetzt korrekten Operator in `session-identity.json`)
  - `session-start-briefing.sh` (Briefing-Box zeigt korrekten Operator + App)
  - `stop-handoff-comment.sh` (Hand-off-ClickUp-Comment hat korrekten Operator)
  - `pre-bash-migration-slot.sh` (Migration-Lock-Holder korrekt)
  - `pre-edit-monorepo-boundary.sh` (Cross-App-Edit-Check greift wieder)

  Pattern in jedem Hook:
  ```bash
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/.env"
    set +a
  fi
  ```

### Note für Worktree-Nutzer

`.env` ist gitignored und kommt daher nicht automatisch ins Worktree mit. Workaround bis v1.3 einen Auto-Setup-Mechanismus bringt:

```bash
ln -sfn ~/path/to/main-repo/.env <worktree>/.env
ln -sfn ~/path/to/main-repo/apps/<app>/.env <worktree>/apps/<app>/.env
```

## [1.2.0] — 2026-05-11

### Critical Fixes (Production-Blocker)

- **Plugin-Hooks feuern endlich.** Root-Cause: invalide Hook-Events `PreCommit` und `PrePush` in `hooks.json` führten dazu dass Claude Code das **gesamte** Plugin-Hook-System ablehnte (Schema-Validierung all-or-nothing). Beide entfernt, alle anderen Hooks (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop) feuern jetzt korrekt.
- **PreToolUse/PostToolUse-Hooks parsen stdin-JSON statt env-vars.** Claude Code übergibt Tool-Input via stdin als JSON (`{"tool_input":{"command":...}}`, `{"tool_input":{"file_path":...}}` etc.), nicht als `CLAUDE_TOOL_INPUT_*` env-vars. Alle Schutz-Hooks umgebaut auf `jq -r '.tool_input.command'` aus stdin.
- **`notify.sh` findet Sub-Scripts wieder.** Lookup-Strategie: `${CLAUDE_PLUGIN_ROOT}/scripts/` wenn gesetzt (z.B. von Hooks), sonst `$(dirname "$0")` (Self-Lookup beim direkten Call). Silent-fail-Modus für status/info/warning ist jetzt warn-loud.

### New: Git-Hooks für Commit/Push-Schutz

- **`install-git-hooks.sh`** als App-lokaler Installer hinzugefügt. Setzt `.git/hooks/commit-msg`, `.git/hooks/pre-commit` und `.git/hooks/pre-push` mit Wrapper-Scripts die auf Plugin-Cache zeigen.
- Bisherige Plugin-Hooks `precommit-ticket-id-required.sh`, `gitleaks-precommit.sh`, `pre-branch-fresh.sh`, `pre-push-tests.sh` jetzt als git-Hooks statt Claude-Code-Hooks (waren keine validen Events).
- Verwendung pro App einmal:
  ```bash
  cd /path/to/your/app
  bash ~/.claude/plugins/cache/kornmueller-empire/work-convention/1.2.0/scripts/install-git-hooks.sh
  ```

### WhatsApp-Notifications

- Cooldown reduziert von 30 Min global auf **5 Min subject-hash-basiert pro Empfänger**. Verschiedene Subjects werden nicht mehr gegenseitig blockiert.
- Bei severity `blocker`/`confirm` kein Cooldown (kritische Notifications immer durch).

### Minor

- `healthcheck.sh` prüft git-Hooks-Installation, `CLICKUP_TASKS_LIST_ID`, sowie `jq` als kritisches Tool.
- `pre-branch-fresh.sh` warnt jetzt auch bei diverged-State (vorher silently durchgelassen).
- `pre-edit-plugin-files.sh` erlaubt `.claude/hooks/diag-*` für lokale Diagnose-Hooks.
- `/status`-Command mit graceful-fallback wenn TASKS.md/STATUS.md fehlen.
- Commands `blocked.md`, `escalate.md`, `newapp.md`, `ticket.md` referenzieren jetzt `${CLAUDE_PLUGIN_ROOT}/scripts/` statt der nicht existenten App-lokalen `.claude/scripts/`.

### Migration auf v1.2.0

```bash
# In jeder App:
claude plugin update work-convention@kornmueller-empire

# Einmalig in jeder App git-Hooks installieren:
bash ~/.claude/plugins/cache/kornmueller-empire/work-convention/1.2.0/scripts/install-git-hooks.sh
```

## [1.1.1] — 2026-05-11

### Fixed
- `notify-test.sh` referenzierte alte App-lokale Pfade (`$PROJECT_DIR/.claude/scripts/`). Sibling-Scripts werden jetzt via `$(dirname "$0")/...` aufgerufen — funktioniert nativ aus dem Plugin-Cache.
- `healthcheck.sh` komplett auf neue Plugin-Architektur umgeschrieben: prüft jetzt Plugin-Cache-Files + App-`.env` getrennt.
- `clickup-spiegel.py` Hint-Text korrigiert (verwies auf alten Plugin-Pfad).

## [1.1.0] — 2026-05-10

### Geändert (Breaking)
- **Plugin-Struktur auf neues Claude-Code-Plugin-Format umgestellt:**
  - `.claude-plugin/marketplace.json` als Marketplace-Manifest
  - `plugins/work-convention/.claude-plugin/plugin.json` als Plugin-Manifest
  - Hook-Wiring nun in `plugins/work-convention/hooks/hooks.json` (war: `claude/settings.json`)
  - Hooks referenzieren via `${CLAUDE_PLUGIN_ROOT}` (war: `${CLAUDE_PROJECT_DIR}/.claude/`)
- **Installations-Workflow:** zwei Schritte statt einer
  - `claude plugin marketplace add KornmuellerConsulting/work-convention-plugin`
  - `claude plugin install work-convention@kornmueller-empire`

### Fixed
- Native `claude plugin install` funktioniert jetzt — v1.0.0 hatte non-standard Layout

## [1.0.0] — 2026-05-10

### Hinzugefügt
- Initial-Release: Pattern D (Plugin + Monorepo)
- 14-Paragraphen-Master-CLAUDE.md
- 25 Hooks (Schutz, Identity, Eskalation, Status, Kontext, Konvention)
- 6 Subagents mit Agent-Teams-Coordination
- 9 Slash-Commands
- 3-Layer-Eskalations-Modell mit Hard-Trigger ab Fail #3
- Reviewer-Subagent läuft via UserPromptSubmit-Hook alle 30min
- ClickUp-Custom-Fields werden einmalig per `bootstrap-clickup-fields.py` erstellt
- Slack-Integration via `chat.postMessage` mit Bot-Token
- GitHub-Pages-Status-Dashboard, Refresh alle 5 Min
- Plugin-Audit mit kuratierter Liste + GitHub-Search
- Cleanup-Failed-Bootstrap-Script
- Pre-Push-Test-Hook
- Plugin-Update-Mechanismus
- MIT-License (public Plugin-Repo)
