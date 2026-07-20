# Changelog

Alle bemerkenswerten Änderungen am Plugin werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung folgt [Semver](https://semver.org/lang/de/).

## [2.0.0] — 2026-07-20

> **Lean Core.** Radikaler Schnitt auf Basis einer verifizierten Community-Recherche (21 Agenten, Skeptiker-geprüft): Behalten wurde nur, was sich auf Merit rechtfertigt — Model-Pins, deterministische git-Hooks, Eskalation, Secret/Prod-Guards. Alles, was pro Session Kontext kostet ohne pro Session Wert zu liefern, ist raus. Kern-Erkenntnis der Recherche: Jede Zeile Session-Start-Output und jeder Hint-Hook wird in *jeder* Session bezahlt; auf 2× Max-Abo ohne API-Budget ist Idle-Kontext der teuerste Posten des Plugins gewesen.

### Breaking / Removed
- **ClickUp/Slack-Spiegel komplett entfernt:** `clickup-spiegel.py`, `bootstrap-clickup-fields.py`, `status-generate.py`, `stop-handoff-comment.sh`, `posttooluse-decision-markup.sh`, `posttooluse-status-refresh.sh`, `notification-trigger.sh`, Docs (`CLICKUP_INTEGRATION.md`, `TICKET_GUIDE.md`), Templates (`STATUS.md.template`, `TASKS.md.template`) und alle `CLICKUP_*`-Env-Keys. DECISIONS.md/BLOCKERS.md bleiben als Konvention — gepflegt von Claude direkt, nicht von Hooks.
- **8 von 9 Slash-Commands entfernt** (`/where`, `/ticket`, `/blocked`, `/deploy`, `/decision`, `/handoff`, `/newapp`, `/status`). Übrig: `/escalate` — der einzige, der echten State verwaltet (Eskalations-Counter-Reset, Layer-3-Notify).
- **Session-Start-Briefing und Identity-Pin entfernt.** Beide produzierten Kontext-Output in jeder Session; CLAUDE.md wird von Claude Code ohnehin geladen, Operator steht in der .env.
- **Hint-Hooks entfernt** (`userprompt-todo-reminder.sh`, `userprompt-reviewer-trigger.sh`). Der 30-Minuten-Reviewer-Hint hat in einer einzigen langen Session ~10× gefeuert, ohne je eine Aktion auszulösen — das ist das Token-Adder-Muster, das die Recherche bei Fremd-Plugins verurteilt; bei eigenen gilt es genauso. Der Reviewer-Agent selbst bleibt (haiku) und wird bewusst gerufen statt automatisch angemahnt.
- **`session-start-advisor-default.sh` entfernt.** Seit v1.3.0 Opt-in ohne bekannten Nutzer; `/advisor` deckt den Fall. Die einmalige Cleanup-Migration (`session-start-advisor-cleanup.sh`) bleibt, bis alle Maschinen auf ≥v1.3.0 waren.
- **`pre-bash-test-pre-push.sh` entfernt** — Doppelmoppel: der echte git-`pre-push`-Hook fuhr dieselben Tests danach nochmal. Jetzt laufen sie einmal, deterministisch, in git.
- **Skill `audit-plugins` und `plugin-audit.py` entfernt** — ersetzt durch die dokumentierte Install-Skepsis-Checkliste (drei Fragen) in der README.
- **`secret.sh` entfernt** (nur noch von gelöschten Scripts referenziert).

### Changed
- **19 Event-Hooks → 3 konsolidierte Dispatcher.** `pre-bash-guards.sh` (Eskalations-Block, Secrets, Prod-Destructive, Migrations-Slot, HEAD-Drift), `pre-edit-guards.sh` (Plugin-File-Schutz key-scoped, Monorepo-Boundary, Secrets) und `post-tool-state.sh` (Fail-Counter, HEAD-Record). Gleiche Block-Logik, aber ein Prozess-Spawn statt bis zu sechs pro Tool-Call. `hooks.json` schrumpft von 26 auf 7 Registrierungen.
- **Migrations-Slot-TTL-Subshell schließt jetzt ihre File-Descriptors** — ein geerbtes stdout konnte CI-Steps bis zu 30 Minuten am Leben halten.

### Fixed
- **13 Funde aus dem adversarialen Verify-Pass** (18 Skeptiker-Agenten, jeder Fund mit Sandbox-Repro bestätigt), darunter drei beim Konsolidieren selbst eingeführte Regressionen: das `bash -n`-Gate vor dem `.env`-Sourcen machte den Monorepo-Boundary-Guard bei teilinvalider `.env` **fail-open** und den Migrations-Lock **fail-closed** (Operator von eigenem Lock ausgesperrt, Slot-Poisoning als „unknown") — beide Guards extrahieren ihre Keys jetzt gezielt per `sed` statt zu sourcen. Dazu: Neuanlage einer `settings.json` ohne Wiring-Keys wurde fälschlich geblockt (jq-Leerstring ≠ null, Alt-Bug aus v1.2.4), leeres stdin zählte als Tool-Fail, und der ensure-Hook installierte bei gesetztem `core.hooksPath` (husky) an eine von git ignorierte Stelle, prüfte das Executable-Bit nicht und fiel auf Substring-Pfade als „frisch" rein. Sechs weitere Funde waren Doku-Leichen (solver/reviewer-Agent-Texte, MODEL_ROUTING, README, .gitignore). Alle mit Regressionstests abgedeckt; Suite 57 → 66.
- **Der Eskalations-Hard-Block hat nie geblockt** (PLUGIN-002). `pre-bash-escalation-block.sh` gab seit jeher `exit 1` zurück — PreToolUse blockt aber ausschließlich bei `exit 2`. Der „HARD-BLOCK" bei Fail #4 war in Wahrheit nur eine Warnmeldung; Claude konnte ungebremst weiterbrute-forcen. Im konsolidierten Dispatcher gibt er jetzt `exit 2` zurück. Aufgefallen beim Zeile-für-Zeile-Port — ein Argument mehr, warum Konsolidierung Reviews erzwingt.

### Added
- **`session-start-ensure-git-hooks.sh`** — macht die git-Hooks „plug and active" und schließt die zwei dokumentierten Rollout-Lücken: (1) `install-git-hooks.sh` musste manuell pro App laufen, (2) die Wrapper pinnten den Cache-Pfad der Installations-Version und liefen nach jedem Update auf altem Stand weiter. Jetzt: pro Session-Start still geprüft, bei Bedarf installiert/nachgezogen. Bewusst konservativ — aktiv nur bei vorhandenem Marker („auto-generated by work-convention") oder Empire-App-Kennung (`APP_PROJECT_PREFIX` in `.env`); fremde Repos und fremde Hooks (z.B. husky) werden nie angefasst; im Plugin-Source-Checkout deaktiviert.
- **Test-Suite v2: 57 Tests** gegen die neue Struktur, inklusive Hard-Block-ist-exit-2, Migrations-Slot-Fixtures, sechs ensure-git-hooks-Szenarien (frisch/still/stale/fremd/ohne-Root/Source-Checkout) und der CLAUDE_PLUGIN_ROOT-Härtungsklasse aus PLUGIN-001.

### Unverändert (bewusst)
- **Alle 7 Agents mit Model-Pins** (v1.3.0) — laut Recherche der direkteste messbare Hebel auf Abo-Limits; kein verifiziertes Community-Tool liefert Vergleichbares, die großen Frameworks unterlaufen es sogar (inherit → Opus).
- Die vier git-Hook-Scripts (`precommit-ticket-id-required.sh`, `gitleaks-precommit.sh`, `pre-branch-fresh.sh`, `pre-push-tests.sh`), `/escalate`, `notify.sh`-Familie (Layer-3), `userprompt-context-refresh.sh` (still, solange kein Eskalations-State existiert), `stop-completeness.sh`, `docs/MODEL_ROUTING.md`.

## [1.3.0] — 2026-07-19

> Model-Routing: jeder Subagent bekommt ein explizites Modell. Ohne Pin erbte jeder Agent das Hauptmodell — bei Opus-Main lief damit auch der 30-Minuten-Reviewer auf Opus.

### Added
- **Model-Pins im Frontmatter aller Subagents.** Bis v1.2.4 hatte keiner der sechs Agents ein `model:`, womit `inherit` galt. Neu: `solver` und `deployer` auf `opus` (härtestes Denken bzw. Production-Blast-Radius), `builder` und `debugger` auf `sonnet` mit `effort: high`, `researcher` auf `sonnet`, `reviewer` auf `haiku`. Runtergestuft wird, was häufig läuft, viel liest und wenig kaputtmachen kann — nicht pauschal alles.
- **`agents/scout.md`** (neu) — read-only Such- und Extraktions-Worker auf `haiku`, ohne Edit/Write. Für große mechanische Lese-Jobs ("finde alle Stellen die X nutzen"), die viel lesen und eine kurze Liste zurückgeben. Die `description` grenzt explizit ab, dass sich der Subagent-Overhead bei kleinen Greps *nicht* lohnt.
- **`docs/MODEL_ROUTING.md`** — Routing-Tabelle mit Rationale pro Agent, das Prinzip dahinter, und beide Wege den Advisor abzuschalten.
- **`WORK_CONVENTION_ADVISOR_DEFAULT` in `.env.example` dokumentiert.** Die Variable existierte seit v1.2.4, stand aber in keinem Template.
- **15 neue Hook-Tests** (26 → 41): 8 für den Advisor-Guard (inklusive Precedence von `CLAUDE_CODE_DISABLE_ADVISOR_TOOL` und "bestehende Wahl wird nie überschrieben"), 7 die sicherstellen, dass **jeder** Agent einen Model-Pin hat. Der Regress von v1.2.4 kann damit nicht zurückkehren — ein neuer Agent ohne `model:` failt die Suite.

- **`hooks/session-start-advisor-cleanup.sh`** (neu, SessionStart) — einmalige Migration, die die v1.2.4-Altlast wieder einsammelt: entfernt `advisorModel` aus `~/.claude/settings.json`, legt vorher ein Backup unter `settings.json.pre-advisor-cleanup.bak` an und meldet sichtbar, was passiert ist. Läuft **genau einmal pro Maschine**, gesichert über `~/.claude/.work-convention-advisor-cleanup.done`. Der Marker ist funktional notwendig, nicht bloß vorsichtig: ohne ihn würde jeder Session-Start erneut löschen und ein späteres, bewusstes `/advisor sonnet` jedes Mal wieder killen. Die Migration ist ein Undo, keine Dauer-Durchsetzung.

### Fixed
- **Vier Hooks starben unter `set -u`, wenn `CLAUDE_PLUGIN_ROOT` nicht gesetzt war** (PLUGIN-001). Betroffen: `posttooluse-status-refresh.sh`, `pre-bash-test-pre-push.sh`, `notification-trigger.sh`, `stop-handoff-comment.sh`. Alle vier wiesen die Variable ohne Default zu und sicherten erst *danach* mit `[ -f ]`/`[ -x ]` ab — der Guard kam nie zum Zug, weil die Zuweisung schon fatal war. Fix: `${CLAUDE_PLUGIN_ROOT:-}`, damit der vorhandene Guard greifen kann.

  Der gefährlichste Fall war `pre-bash-test-pre-push.sh`: der Hook erzwingt Tests vor jedem `git push`. Stirbt er, gibt er exit 1 zurück — was in Claude Code **nicht** blockt (nur exit 2 tut das). Der Push wäre also ungetestet durchgegangen, fail-open statt fail-closed. Bei `stop-handoff-comment.sh` wäre es dieselbe Symptomatik wie LAV-559 gewesen: Hand-off-Comment wird still nicht gepostet.

  Claude Code setzt die Variable im Normalbetrieb, akut gefeuert hat es also nicht — es war latent. Vier neue Tests decken jetzt genau diesen Fall ab.

### Changed
- **`hooks/session-start-advisor-default.sh` ist jetzt OPT-IN statt Opt-out.** Bis v1.2.4 galt: fehlt `WORK_CONVENTION_ADVISOR_DEFAULT`, schreibe `"opus"` — womit das Plugin auf jeder Maschine des Empire ungefragt einen Advisor aktivierte, den niemand bestellt hatte. Jetzt fasst der Hook die globale settings.json nur noch an, wenn die Variable ausdrücklich auf ein Modell gesetzt ist. Zusätzlich: schweigt komplett bei `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1`, schreibt nie einen Pseudo-Wert wie `"off"` (`advisorModel` akzeptiert nur echte Model-Aliase), und `bash -n`-Syntax-Guard vor dem `.env`-`source` (v1.2.3-Pattern, das hier noch fehlte).
- Reihenfolge in `hooks.json`: Cleanup läuft vor dem Setter. Mit dem umgedrehten Default schreibt der Setter danach nichts zurück — ein Test deckt genau dieses Zusammenspiel ab.

### Notes
- **Für Patrick und Justin heißt das konkret:** beim ersten Session-Start nach `claude plugin update` verschwindet `advisorModel` aus der globalen settings.json, mit Meldung und Backup. Advisor zurückholen geht jederzeit per `/advisor` — die Migration kommt nicht wieder.
- Rückwirkend war nicht unterscheidbar, ob `advisorModel` vom v1.2.4-Hook oder von Hand stammte — der alte Hook hat keinen Marker gesetzt. Da das Plugin nur intern von zwei Personen genutzt wird, entfernt die Migration den Wert unabhängig davon und verlässt sich auf Backup plus Marker statt auf Rateheuristiken.
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
