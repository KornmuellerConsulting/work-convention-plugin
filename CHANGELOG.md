# Changelog

Alle bemerkenswerten Änderungen am Plugin werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung folgt [Semver](https://semver.org/lang/de/).

## [1.3.0] — 2026-07-19

> Model-Routing: jeder Subagent bekommt ein explizites Modell. Ohne Pin erbte jeder Agent das Hauptmodell — bei Opus-Main lief damit auch der 30-Minuten-Reviewer auf Opus.

### Added
- **Model-Pins im Frontmatter aller Subagents.** Bis v1.2.4 hatte keiner der sechs Agents ein `model:`, womit `inherit` galt. Neu: `solver` und `deployer` auf `opus` (härtestes Denken bzw. Production-Blast-Radius), `builder` und `debugger` auf `sonnet` mit `effort: high`, `researcher` auf `sonnet`, `reviewer` auf `haiku`. Runtergestuft wird, was häufig läuft, viel liest und wenig kaputtmachen kann — nicht pauschal alles.
- **`agents/scout.md`** (neu) — read-only Such- und Extraktions-Worker auf `haiku`, ohne Edit/Write. Für große mechanische Lese-Jobs ("finde alle Stellen die X nutzen"), die viel lesen und eine kurze Liste zurückgeben. Die `description` grenzt explizit ab, dass sich der Subagent-Overhead bei kleinen Greps *nicht* lohnt.
- **`docs/MODEL_ROUTING.md`** — Routing-Tabelle mit Rationale pro Agent, das Prinzip dahinter, und beide Wege den Advisor abzuschalten.
- **`WORK_CONVENTION_ADVISOR_DEFAULT` in `.env.example` dokumentiert.** Die Variable existierte seit v1.2.4, stand aber in keinem Template.
- **15 neue Hook-Tests** (26 → 41): 8 für den Advisor-Guard (inklusive Precedence von `CLAUDE_CODE_DISABLE_ADVISOR_TOOL` und "bestehende Wahl wird nie überschrieben"), 7 die sicherstellen, dass **jeder** Agent einen Model-Pin hat. Der Regress von v1.2.4 kann damit nicht zurückkehren — ein neuer Agent ohne `model:` failt die Suite.

### Changed
- **`hooks/session-start-advisor-default.sh`** hat einen Opt-out-Guard. Der Hook schreibt nichts mehr, wenn `WORK_CONVENTION_ADVISOR_DEFAULT` auf `off`/`none`/`false`/`0`/`disabled`/leer steht (case-insensitive) oder `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` gesetzt ist. Wichtig: Es wird in dem Fall **kein** Ersatzwert wie `"off"` in die settings.json geschrieben — `advisorModel` akzeptiert nur echte Model-Aliase. Zusätzlich `bash -n`-Syntax-Guard vor dem `.env`-`source` (v1.2.3-Pattern, das hier noch fehlte).

### Notes
- Der Guard hilft nur bei **frischen** Installs. Steht `advisorModel` bereits in `~/.claude/settings.json`, fasst der Hook es grundsätzlich nicht an — dann greift nur `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` im `env`-Block der settings.json (gewinnt gegen jedes gesetzte `advisorModel`) oder `/advisor off`.
- Das Routing verteilt sich strukturell: die Agents liegen im Plugin, nicht in den Apps. Ein `claude plugin update` und die Pins gelten in jeder App auf jeder Maschine — kein Template-Kopieren nötig.

## [1.2.4] — 2026-07-15

> Fix: `pre-edit-plugin-files.sh` blockte die komplette `settings.json`, obwohl nur `enabledPlugins`/`extraKnownMarketplaces` echtes Plugin-Wiring sind.

### Fixed
- **`hooks/pre-edit-plugin-files.sh`** blockte bisher jeden Edit/Write an `.claude/settings.json` pauschal, auch für generische, plugin-unabhängige Settings wie `advisorModel` oder `theme`. Der Hook prüft jetzt bei `settings.json` gezielt, ob der Edit/Write tatsächlich `enabledPlugins` oder `extraKnownMarketplaces` verändert (Plugin-Wiring), statt die ganze Datei zu sperren. Andere Plugin-Pfade (`hooks/`, `agents/`, `skills/`, `commands/`, `scripts/`) bleiben file-scoped geblockt wie zuvor.

### Added
- 4 neue Hook-Tests (`pre-edit-plugin: settings.json ...`) für Edit- und Write-Pfad, je ein Fall der geschützte Keys berührt (blockt) und einer der nur generische Keys ändert (erlaubt). Test-Suite jetzt 26/26 grün.
- **`hooks/session-start-advisor-default.sh`** (neu, SessionStart) — trägt `advisorModel: "opus"` automatisch in `~/.claude/settings.json` ein, falls dort noch keiner gesetzt ist. Macht den Advisor account-weit zum Default auf jeder Maschine, sobald das Plugin dort installiert/geupdated wird, ohne dass jede Person das manuell einträgt. Überschreibt nie eine bereits vorhandene, explizite Wahl. Default per `WORK_CONVENTION_ADVISOR_DEFAULT` in `.env` überschreibbar. Gilt pro Maschine — kein Cloud-Sync über Geräte hinweg.

## [1.2.3] — 2026-05-24

> Patch-Release: Stop-Hook robust gegen `.env`-Quoting-Fehler.

### Fixed
- **`hooks/stop-handoff-comment.sh`** brach unter `set -euo pipefail` komplett ab, wenn `.env` einen Syntax-Fehler hatte (z.B. ein unquoted `)` in einem Passwort-Wert) — der Hand-off-ClickUp-Comment wurde nie gepostet und der Stop-Hook schlug in Schleife fehl. Fix: `bash -n`-Syntax-Guard vor dem `source` plus `source … 2>/dev/null || true`. Ungültiges `.env` wird jetzt übersprungen (`CURRENT_OPERATOR`/`CLICKUP_*` fallen leer zurück), der Hand-off-Comment landet trotzdem. (LAV-559)

## [1.2.2] — 2026-05-15

> Test-Infrastruktur, Doku und CI. Folge-Release zu v1.2.1.

### Fixed
- **`hooks/tests/test-runner.sh`** war auf v1.1-Convention hängengeblieben (env-vars + exit code 1). Komplett neu gegen v1.2-Hook-API: stdin-JSON für `tool_input.*`, exit code 2 für PreToolUse-Blocks, file-path-arg für `precommit-ticket-id-required.sh`. Tests sind jetzt 22/22 grün statt 6/11.
- Secret-like Test-Patterns werden zur Laufzeit aus Fragmenten zusammengebaut, damit `pre-edit-secret-body.sh` das Test-File beim Edit nicht selbst blockt.

### Added
- **`docs/QUICKSTART.md`** — dokumentierter Golden Path für eine neue App (~20 Min), inklusive Plugin-Cache-Resolver-Pattern (`find ~/.claude/plugins/cache/.../scripts -name X | sort -V | tail -1`).
- **`.github/workflows/hook-tests.yml`** — CI-Workflow für jeden Push/PR: JSON-Manifest-Validation, Version-Konsistenz-Check zwischen marketplace.json und plugin.json, Hook-Event-Whitelist (verhindert die hooks.json-Schema-Bombe), 22 Hook-Tests, shellcheck.
- **Test-Coverage** verdoppelt: escalation-counter mit 3-fail-flag und reset-state, precommit mit breaking-marker und merge-skip, pre-edit-plugin mit diag-allowed und agents-blocked.

### Internal
- `.gitignore`: `STATUS.md` (auto-gen) und `.claude/worktrees/` ausgeschlossen.

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
