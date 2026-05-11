# Changelog

Alle bemerkenswerten Änderungen am Plugin werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung folgt [Semver](https://semver.org/lang/de/).

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
