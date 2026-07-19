# work-convention-plugin

Claude-Code-Plugin-Marketplace für das Kornmueller-Consulting-Empire.

## Installation

Aus jeder App im Monorepo:

```bash
# Marketplace einmal hinzufügen (pro User-Maschine)
claude plugin marketplace add KornmuellerConsulting/work-convention-plugin

# Plugin installieren (pro App)
claude plugin install work-convention@kornmueller-empire
```

## Was das Plugin liefert

- **14-Paragraphen-Konstitution** als `CLAUDE.md`-Template (in `templates/`)
- **25 Hooks** — Schutz, Identity, Eskalation, Status, Kontext, Konvention
- **7 Subagents** — Builder, Solver (Layer 2), Reviewer (30min Drift), Researcher, Debugger, Deployer, Scout — jeder mit festem Modell ([Routing](docs/MODEL_ROUTING.md))
- **9 Slash-Commands** — `/status`, `/where`, `/blocked`, `/handoff`, `/escalate`, `/ticket`, `/deploy`, `/decision`, `/newapp`
- **3-Layer-Eskalations-Modell** mit Hard-Trigger ab Fail #3
- **ClickUp-Worker** — Status-Spiegelung, Decision-Markup, Hand-off-Comments
- **Notification-Stack** — Slack (chat.postMessage), Pushover, WhatsApp (CallMeBot)
- **Plugin-Audit-Skill** — kuratierte App-spezifische Plugin-Empfehlungen
- **Tests** — alle Hooks + Healthcheck + Dry-Run-Bootstrap

## Update einer App

```bash
claude plugin update work-convention@kornmueller-empire
```

## Versionierung

Semver via Git-Tags. Breaking-Changes erhöhen Major-Version, neue Features Minor, Bugfixes Patch.

Siehe [CHANGELOG.md](./CHANGELOG.md).

## Repo-Struktur

```
work-convention-plugin/
├── .claude-plugin/
│   └── marketplace.json      ← Marketplace-Katalog
├── plugins/
│   └── work-convention/      ← Das eigentliche Plugin
│       ├── .claude-plugin/plugin.json
│       ├── agents/           ← 7 Subagents
│       ├── commands/         ← 9 Slash-Commands
│       ├── hooks/            ← 25 Hooks + hooks.json (Wiring)
│       ├── skills/           ← Plugin-Audit-Skill
│       └── scripts/          ← notify.sh, clickup-spiegel.py, etc.
├── templates/                ← CLAUDE.md, STATUS.md.template, etc.
├── docs/                     ← SETUP.md, ESCALATION.md, HOOKS.md, etc.
├── README.md
├── LICENSE                   ← MIT
└── CHANGELOG.md
```

## Setup pro App

- **Quickstart (~20 Min)**: [docs/QUICKSTART.md](./docs/QUICKSTART.md) — Golden Path mit Bootstrap-Skript
- **Vollständige Setup-Anleitung**: [docs/SETUP.md](./docs/SETUP.md) — alle Pre-Setups (ClickUp/Slack/Pushover/WhatsApp/Vercel/Supabase)

## Co-Founder

| Person  | Rolle        | GitHub               |
|---------|--------------|----------------------|
| Patrick | Co-Founder   | @patrick-kornmueller |
| Justin  | Co-Founder   | @JustinGoermez       |

Beide gleichberechtigt, beide Admin überall, beide werden bei Layer-3 parallel gepingt.

Details: [docs/WORKING_AGREEMENT.md](./docs/WORKING_AGREEMENT.md)

## Lizenz

MIT — siehe [LICENSE](./LICENSE).

Plugin-Conventions sind public. Apps die das Plugin nutzen bleiben in privaten Repos — Plugin enthält keine App-spezifischen Daten.
