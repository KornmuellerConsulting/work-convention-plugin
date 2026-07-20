# QUICKSTART — Golden Path (unter 5 Minuten)

Kein Bootstrap-Skript, kein ClickUp, kein Pre-Setup nötig. v2.0 ist Plugin
installieren, `.env` mit drei Identity-Keys, Session starten.

## Golden Path

```bash
# 1. In die App wechseln
cd apps/customer-portal

# 2. Plugin installieren (einmalig pro Maschine: marketplace add zuerst)
claude plugin marketplace add KornmuellerConsulting/work-convention-plugin
claude plugin install work-convention@kornmueller-empire

# 3. .env anlegen
cp .env.example .env
# In .env eintragen:
#   APP_NAME=customer-portal
#   APP_PROJECT_PREFIX=CUST
#   CURRENT_OPERATOR=justin    (oder patrick)

# 4. Session starten — git-Hooks (commit-msg/pre-commit/pre-push) installieren
#    sich automatisch, weil APP_PROJECT_PREFIX gesetzt ist
claude code
```

Fertig. Kein manueller Hook-Install, kein ClickUp-Space, kein Slack-Channel.

## Verifikation

```bash
bash ~/.claude/plugins/cache/kornmueller-empire/work-convention/<version>/scripts/healthcheck.sh
```

Erwartung: keine `❌`-Zeilen. Details zu Fehlermeldungen:
[TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Erste Prompts

- `Ticket CUST-1 umsetzen` → Builder-Subagent-Workflow
- `/escalate 3 "Beschreibung"` → Layer-3-Eskalation (siehe [ESCALATION.md](./ESCALATION.md))

## Was dann?

Ab hier ist die App im Workflow:
- Conventional Commits mit Ticket-ID (`feat(CUST-42): ...`, per git-Hook enforced)
- Decision-Blocks für nicht-triviale Wahlen → `DECISIONS.md` (Append-Only)
- Offene Issues → `BLOCKERS.md`
- 3-Layer-Eskalation greift automatisch ab Fail #3 (Hard-Block ab Fail #4)

Volle Konstitution: [Master-CLAUDE.md](../templates/CLAUDE.md)
Working-Agreement: [WORKING_AGREEMENT.md](./WORKING_AGREEMENT.md)
Escalation-Modell: [ESCALATION.md](./ESCALATION.md)
