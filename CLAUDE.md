# work-convention-plugin

Claude-Code-Plugin-Marketplace für das Kornmueller-Consulting-Empire (Patrick + Justin). Liefert model-gepinnte Subagents, selbstinstallierende git-Hooks, Secret/Prod-Guards und das 3-Layer-Eskalations-Modell für alle Apps im Empire.

**Lean-Core-Prinzip (v2.0):** Jede Zeile Session-Output und jedes Kontext-Snippet wird in *jeder* Session bezahlt. Hooks sind entweder deterministische Guards (blocken bei Verstoß, schweigen sonst) oder sie existieren nicht. Kein Briefing, keine Hints, kein Auto-Sync zu externen Diensten.

## Architektur (Pattern D)

Public Plugin-Repo + private Apps-Repo. Beide bei `KornmuellerConsulting` auf GitHub.

- **Dieser Repo (work-convention-plugin):** public, MIT, enthält das Plugin
- **Sibling-Repo (apps):** private, enthält die Empire-Apps die das Plugin nutzen
- Plugin wird per Marketplace-System installed: `claude plugin install work-convention@kornmueller-empire`

## Repo-Struktur

```
.claude-plugin/marketplace.json    Marketplace-Katalog (1 Plugin)
plugins/work-convention/
  .claude-plugin/plugin.json       Plugin-Manifest
  hooks/hooks.json                 Hook-Wiring (9 Registrierungen)
  hooks/*.sh                       13 Hook-Scripts (3 Dispatcher + 4 git-Hook-Targets + 6 einzelne)
  agents/*.md                      7 Subagents, alle mit Model-Pin (docs/MODEL_ROUTING.md)
  commands/escalate.md             der einzige Slash-Command (Eskalations-State + Layer-3)
  scripts/                         install-git-hooks.sh, healthcheck.sh, statusline.sh, notify.sh-Familie
templates/                         CLAUDE.md, BLOCKERS/DECISIONS-Templates für Apps
docs/                              MODEL_ROUTING.md, HOOKS.md, STATUSLINE.md, ESCALATION.md, etc.
```

## Hook-Mechanik (kritisch)

Claude Code lädt Hooks aus `hooks/hooks.json`. **Eine einzige invalide Event-Property kills das gesamte Plugin-Hook-System** (Schema-Validierung ist all-or-nothing). Daher dürfen in `hooks.json` ausschließlich diese Events stehen:

```
SessionStart, SessionEnd, UserPromptSubmit, UserPromptExpansion,
PreToolUse, PostToolUse, PostToolUseFailure, PostToolBatch,
Notification, Stop, StopFailure,
SubagentStart, SubagentStop,
PreCompact, PostCompact,
PermissionRequest, PermissionDenied,
Setup, TeammateIdle, TaskCreated, TaskCompleted,
Elicitation, ElicitationResult, ConfigChange,
WorktreeCreate, WorktreeRemove,
InstructionsLoaded, CwdChanged, FileChanged
```

**`PreCommit` und `PrePush` sind KEINE validen Claude-Code-Events.** Diese sind als echte git-Hooks via `scripts/install-git-hooks.sh` zu installieren, nicht in `hooks.json`.

## Tool-Input Mechanik (kritisch)

Claude Code übergibt Tool-Input via **stdin als JSON**, nicht als Env-Vars. Alle Hooks die Tool-Input brauchen parsen via jq:

```bash
INPUT=$(cat 2>/dev/null || echo '{}')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)
EXIT=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
```

**Niemals `${CLAUDE_TOOL_INPUT_*}` env-vars verwenden** — die existieren in der aktuellen Claude Code Version nicht.

## Pfad-Variablen

- `${CLAUDE_PLUGIN_ROOT}` — Plugin-Cache-Pfad, in hooks/commands/skills/agents verfügbar
- `${CLAUDE_PROJECT_DIR}` — App-Verzeichnis, immer verfügbar
- App's `.env` muss bei Bedarf vom Script selbst gesourced werden: `[ -f "$CLAUDE_PROJECT_DIR/.env" ] && { set -a; source "$CLAUDE_PROJECT_DIR/.env"; set +a; }`

## Aktuelle Version

**v2.1.0** (2026-07-21) — Tacho & Selbstversorgung. Statusline-Tacho
(`scripts/statusline.sh`, Opt-in via [docs/STATUSLINE.md](./docs/STATUSLINE.md) —
Claude Code kann keine Plugin-Statusline-Defaults, empirisch verifiziert),
Self-Update-Hook (`session-start-check-update.sh`, 1x/24h detached, Gate
`WORK_CONVENTION_AUTO_UPDATE=off`), Compact-Anker
(`session-start-compact-anchor.sh`, Matcher `compact`: Branch/Ticket/BLOCKERS
nach Compaction). hooks.json: 7 → 9 Registrierungen.

Davor v2.0.0 (2026-07-20) — Lean Core: 27 Hooks → 11 (drei konsolidierte
Dispatcher), 9 Commands → 1, ClickUp/Slack-Spiegel raus, Briefing/Hints raus,
git-Hooks selbstinstallierend. Dabei gefixt: der Eskalations-Hard-Block gab
`exit 1` zurück und hat deshalb nie real geblockt. Davor v1.3.0 —
Model-Routing: jeder Subagent mit explizitem `model:`-Pin
([docs/MODEL_ROUTING.md](./docs/MODEL_ROUTING.md)).

Siehe [CHANGELOG.md](./CHANGELOG.md) für die volle History.

## Plugin-Update-Workflow

```bash
# 1. Änderungen lokal machen
cd ~/Documents/Kornmueller/work-convention-plugin

# 2. Commit (Format unten beachten)
git add -A
git commit -m 'fix(MIGRATE-NNN): kurze Beschreibung'

# 3. Push + Tag
git push origin main
git tag vX.Y.Z
git push --tags

# 4. In jeder App updaten
cd ~/Documents/Kornmueller/apps/apps/<app-name>
claude plugin marketplace update kornmueller-empire
claude plugin update work-convention@kornmueller-empire

# 5. Wenn Hook-Verhalten geändert: Claude Code neu starten oder /reload-plugins
```

## Commit-Format

Conventional Commits + Ticket-ID (vom `precommit-ticket-id-required.sh` enforced via git-Hook):

```
<type>(<PREFIX>-<nr>): <description>
<type>(<PREFIX>-<nr>)!: <description>   (breaking)
```

Plugin-eigene Tickets: `MIGRATE-NNN` (für Plugin-Architektur-Changes) oder `PLUGIN-NNN` (für Plugin-Bugfixes).

## Test-Workflow

Vor jedem Release:

1. **Lokal validieren**: alle Manifest-JSONs müssen valid sein
   ```bash
   python3 -m json.tool .claude-plugin/marketplace.json > /dev/null
   python3 -m json.tool plugins/work-convention/.claude-plugin/plugin.json > /dev/null
   python3 -m json.tool plugins/work-convention/hooks/hooks.json > /dev/null
   ```
2. **Healthcheck in Test-App ausführen**:
   ```bash
   cd ~/Documents/Kornmueller/apps/apps/notification-test
   bash ~/.claude/plugins/cache/kornmueller-empire/work-convention/<version>/scripts/healthcheck.sh
   ```
3. **Hook-Loader-Check**:
   ```bash
   claude -d hooks --debug-file /tmp/claude-debug.log
   # → /exit
   grep -iE "registered.*hooks|hook.*load|sessionstart" /tmp/claude-debug.log
   ```
   Erwartung: `Registered 9 hooks from 1 plugins`. Wenn 0: invalid Event in hooks.json.

## Debugging

**Plugin-Hook feuert nicht?** → `claude -d hooks --debug-file /tmp/claude-debug.log` und nach "Failed to load hooks" suchen. Häufigster Bug: invalide Event-Property in hooks.json.

**Tool-Input ist leer im Hook?** → Hook auf stdin-JSON-Parsing umstellen statt env-vars.

**Sub-Script nicht gefunden?** → `${CLAUDE_PLUGIN_ROOT}` in hooks, `$(dirname "${BASH_SOURCE[0]}")` in scripts die sich selbst aufrufen.

**.env-Variablen nicht in Hook sichtbar?** → Hook muss selbst sourcen: `[ -f "$CLAUDE_PROJECT_DIR/.env" ] && { set -a; source "$CLAUDE_PROJECT_DIR/.env"; set +a; }`.

## Operator-Identitäten

| Person  | Operator-String | GitHub               |
|---------|-----------------|----------------------|
| Patrick | `patrick`       | @patrick-kornmueller |
| Justin  | `justin`        | @JustinGoermez       |

Beide gleichberechtigt, beide Admin im Plugin-Repo + Apps-Repo. Im App-Workflow setzt `CURRENT_OPERATOR=patrick` oder `justin` in der jeweiligen `.env` der App fest wer gerade arbeitet.

## Working Agreement

Siehe `docs/WORKING_AGREEMENT.md`. Kern:

- **Conventional Commits + Ticket-ID** (per git-Hook enforced, installiert sich seit v2.0 selbst)
- **DECISIONS.md ist Append-Only** (keine History-Rewrites; von Claude direkt gepflegt, nicht von Hooks)
- **Layer-Eskalation** (3+ Fails → Solver-Subagent; Fail #4 ohne Solver → echter Hard-Block, exit 2)
- **Plugin-Files nicht direkt in der App editieren** (`pre-edit-guards.sh` blockt)

## Wichtige NICHTs

- ❌ **Nicht** im Plugin-Cache (`~/.claude/plugins/cache/...`) editieren — wird beim nächsten Update überschrieben
- ❌ **Nicht** `PreCommit`/`PrePush` in `hooks.json` einfügen — kills das ganze Hook-System
- ❌ **Nicht** App-spezifische Tokens oder Identifier in den Plugin-Code packen — der Repo ist public
- ❌ **Nicht** `npm run build` o.ä. im Plugin-Repo — es ist kein Build-Tool, nur Konventionen-Distribution
