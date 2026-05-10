# Changelog

Alle bemerkenswerten Änderungen am Plugin werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung folgt [Semver](https://semver.org/lang/de/).

## [Unreleased]

## [1.0.0] — 2026-05-10

### Hinzugefügt
- Initial-Release: Pattern D (Plugin + Monorepo)
- 14-Paragraphen-Master-CLAUDE.md
- 19 Hooks (Schutz, Identity, Eskalation, Status, Kontext, Konvention)
- 6 Subagents mit Agent-Teams-Coordination
- 9 Slash-Commands
- 3-Layer-Eskalations-Modell mit Hard-Trigger ab Fail #3 (Audit-Fix #1)
- Reviewer-Subagent läuft via UserPromptSubmit-Hook alle 30min (Audit-Fix #2)
- ClickUp-Custom-Fields werden einmalig per `bootstrap-clickup-fields.py` erstellt (Audit-Fix #4)
- Slack-Integration via `chat.postMessage` mit Bot-Token (Audit-Fix #5)
- GitHub-Pages-Status-Dashboard, Refresh alle 5 Min (Audit-Fix #6)
- Plugin-Audit mit kuratierter Liste + GitHub-Search (Audit-Fix #7)
- Cleanup-Failed-Bootstrap-Script (Audit-Fix #15)
- Pre-Push-Test-Hook (Audit-Fix #18)
- Fail-loud bei fehlendem Slack-Token (Audit-Fix #19)
- Plugin-Update-Mechanismus via `claude plugin update` (Audit-Fix #20)
- TASKS.md-Generator-Skill (Audit-Fix #21)

## Lizenz-Note

Plugin ist seit v1.0.0 unter MIT-Lizenz public. Apps die das Plugin nutzen
bleiben in privaten Repos — Plugin enthält keine App-spezifischen Daten,
sondern nur generische Conventions.
