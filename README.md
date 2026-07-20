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

## Was das Plugin liefert (v2.0 — Lean Core)

- **7 Subagents mit Model-Pins** — Builder, Solver (Layer 2), Reviewer, Researcher, Debugger, Deployer, Scout. Der direkteste Hebel auf Abo-Limits: Lese- und Review-Arbeit läuft auf haiku/sonnet, nur Solver/Deployer auf opus ([Routing + Rationale](docs/MODEL_ROUTING.md))
- **Selbstinstallierende git-Hooks** — Ticket-ID-Zwang, gitleaks-Secret-Scan, Branch-Fresh + Tests vor Push. Installieren und aktualisieren sich pro Session-Start selbst (nur in Empire-Apps, fremde Repos bleiben unberührt)
- **3 konsolidierte Guard-Dispatcher** — Secrets/Prod-Destructive/Migrations-Lock/Eskalations-Block (Bash), Plugin-File-Schutz/Monorepo-Boundary/Secrets (Edit/Write), Fail-Counter/HEAD-Record (PostToolUse). Blocken bei Verstoß, schweigen sonst
- **3-Layer-Eskalations-Modell** — Hard-Trigger ab Fail #3, echter Hard-Block ab Fail #4, `/escalate` für Layer-Wechsel und Reset, Layer-3-Notify via Slack/Pushover/WhatsApp
- **Tests** — 57 Hook-Tests + Healthcheck, CI-enforced

**Bewusst NICHT enthalten:** Auto-Sync zu externen Diensten, Session-Briefings, Hint-Hooks, Plugin-Kataloge. Jede Zeile Idle-Kontext wird in jeder Session bezahlt — Install-Skepsis vor jedem neuen Tool: *Läuft es ohne API-Key gegen Plan-Limits? Was kostet es idle im Kontext? Dupliziert es, was wir haben?*

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
│       ├── agents/           ← 7 Subagents (alle model-gepinnt)
│       ├── commands/         ← /escalate
│       ├── hooks/            ← 11 Hook-Scripts + hooks.json (7 Registrierungen)
│       └── scripts/          ← install-git-hooks.sh, healthcheck.sh, notify.sh
├── templates/                ← CLAUDE.md, BLOCKERS/DECISIONS-Templates
├── docs/                     ← MODEL_ROUTING.md, HOOKS.md, ESCALATION.md, etc.
├── README.md
├── LICENSE                   ← MIT
└── CHANGELOG.md
```

## Setup pro App

- **Quickstart (wenige Minuten)**: [docs/QUICKSTART.md](./docs/QUICKSTART.md) — install, `.env`, Session starten; git-Hooks kommen von selbst
- **Vollständige Setup-Anleitung**: [docs/SETUP.md](./docs/SETUP.md)

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
