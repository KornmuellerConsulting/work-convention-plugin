# work-convention-plugin

Claude-Code-Plugin-Marketplace für das Kornmueller-Consulting-Empire (Patrick + Justin). Liefert Hooks, Subagents, Slash-Commands, ClickUp/Slack-Integration und das 3-Layer-Eskalations-Modell für alle Apps im Empire.

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
  hooks/hooks.json                 Hook-Wiring (Claude-Code-Events)
  hooks/*.sh                       25 Hook-Scripts
  agents/*.md                      6 Subagents (builder/solver/reviewer/researcher/debugger/deployer)
  commands/*.md                    9 Slash-Commands
  skills/audit-plugins/SKILL.md    Plugin-Audit-Skill
  scripts/*.sh,*.py                notify.sh, clickup-spiegel.py, healthcheck.sh, install-git-hooks.sh, etc.
templates/                         CLAUDE.md, STATUS.md.template etc. die in jede App kopiert werden
docs/                              SETUP.md, ESCALATION.md, HOOKS.md, etc.
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

**v1.2.0** (2026-05-15) — Production-fit nach mehrtägiger Diagnose. Wichtige Fixes:
- PreCommit/PrePush aus hooks.json raus → Plugin-Hooks feuern endlich
- Alle PreToolUse/PostToolUse-Hooks auf stdin-JSON umgestellt
- notify.sh-Pfade auf ${CLAUDE_PLUGIN_ROOT}
- Neuer install-git-hooks.sh für commit-msg/pre-commit/pre-push
- WhatsApp 5-Min subject-hash-dedup statt 30-Min global cooldown

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
   Erwartung: `Registered N hooks from 1 plugins` (N≥10). Wenn 0: invalid Event in hooks.json.

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

- **Conventional Commits + Ticket-ID** (per git-Hook enforced)
- **DECISIONS.md ist Append-Only** (keine History-Rewrites)
- **Operator-Wechsel via Stop-Hook** (postet Hand-off zu ClickUp)
- **Layer-3-Eskalation** (3+ Fails → Solver-Subagent, sonst Hard-Block)
- **Plugin-Files nicht direkt in der App editieren** (`pre-edit-plugin-files.sh` blockt)

## Wichtige NICHTs

- ❌ **Nicht** im Plugin-Cache (`~/.claude/plugins/cache/...`) editieren — wird beim nächsten Update überschrieben
- ❌ **Nicht** `PreCommit`/`PrePush` in `hooks.json` einfügen — kills das ganze Hook-System
- ❌ **Nicht** App-spezifische Tokens oder Identifier in den Plugin-Code packen — der Repo ist public
- ❌ **Nicht** `npm run build` o.ä. im Plugin-Repo — es ist kein Build-Tool, nur Konventionen-Distribution
