# work-convention-plugin

Claude-Code-Plugin für das Kornmueller-Consulting-App-Empire.

Installiert in jeder App im Monorepo via:

```bash
claude plugin install KornmuellerConsulting/work-convention-plugin
```

## Was das Plugin liefert

- **CLAUDE.md** — 14-Paragraphen-Konstitution (kopiert beim Install in App-Root)
- **19 Hooks** — Schutz, Identity, Eskalation, Status, Kontext, Konvention
- **6 Subagents** — Builder, Solver (Layer 2), Reviewer (30min Drift), Researcher, Debugger, Deployer
- **9 Slash-Commands** — `/status`, `/where`, `/blocked`, `/handoff`, `/escalate`, `/ticket`, `/deploy`, `/decision`, `/newapp`
- **3-Layer-Eskalations-Modell** mit Hard-Trigger ab Fail #3
- **ClickUp-Worker** — Status-Spiegelung, Decision-Markup, Hand-off-Comments
- **Notification-Stack** — Slack (chat.postMessage), Pushover, WhatsApp (CallMeBot)
- **Plugin-Audit-Skill** — kuratierte App-spezifische Plugin-Empfehlungen
- **Tests** — alle 19 Hooks + Healthcheck + Dry-Run-Bootstrap
- **GitHub-Pages-Status-Dashboard** — Live-Empire-Status, alle 5 Min refresht

## Installation in einer App

In `apps/<app-name>/` im Monorepo:

```bash
cd apps/<app-name>
claude plugin install KornmuellerConsulting/work-convention-plugin@latest
cp .env.example .env
# .env ausfüllen (Anleitung in SETUP.md)
bash .claude/scripts/healthcheck.sh
```

## Update einer App

```bash
cd apps/<app-name>
claude plugin update work-convention-plugin
```

Plugin-Updates ändern nur `.claude/`-Files. App-spezifische Configs in `.env`
und `.claude/app.json` bleiben unangetastet.

## Versionierung

Semver via Git-Tags. Breaking-Changes erhöhen Major-Version, neue Features Minor,
Bugfixes Patch.

```bash
git tag v1.0.0
git push --tags
```

Siehe [CHANGELOG.md](./CHANGELOG.md).

## Setup-Voraussetzungen

Pro App:

- GitHub-Repo (im Monorepo `KornmuellerConsulting/apps`, App als Folder)
- ClickUp-Space
- Slack-Channels: `#empire-status`, `#empire-blockers`, `#<app>-build`
- Vercel-Project (Monorepo-Mode mit App-Folder als Root)
- Supabase-Project (Stage + Prod) — optional je nach App
- Pushover-User-Key + App-Tokens (Patrick + Justin)
- CallMeBot-Key (Patrick + Justin)

Vollständige Setup-Anleitung: [SETUP.md](./docs/SETUP.md)

## Co-Founder

| Person  | Rolle        | GitHub               | ClickUp               |
|---------|--------------|----------------------|-----------------------|
| Patrick | Co-Founder   | @patrick-kornmueller | patrick@kornmueller…  |
| Justin  | Co-Founder   | @justin-goermez      | justin@kornmueller…   |

Beide gleichberechtigt, beide Admin überall, beide werden bei Layer-3 parallel
gepingt.

Details: [WORKING_AGREEMENT.md](./docs/WORKING_AGREEMENT.md)

## Lizenz

MIT — siehe [LICENSE](./LICENSE).

Konventionen, Hooks und Conventions können von anderen Teams genutzt werden.
App-spezifischer Code lebt in privaten Apps-Repos und wird hier nie eingecheckt.
