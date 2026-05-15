# QUICKSTART — Neue App in ~20 Minuten

Voraussetzung: Pre-Setups laut [SETUP.md](./SETUP.md) sind einmalig durch (ClickUp/Slack/Pushover/WhatsApp/GitHub/Vercel-Tokens in `apps/.env`).

## Golden Path

```bash
# 0. Apps-Monorepo
cd ~/Documents/Kornmueller/apps

# 1. Bootstrap — legt apps/<name>/ aus example-web-Skeleton an,
#    erstellt ClickUp-Space + Slack-Channel #<name>-build
bash scripts/bootstrap-app.sh --name customer-portal --prefix CUST

# 2. In die neue App wechseln
cd apps/customer-portal

# 3. Plugin installieren (einmalig pro Maschine: marketplace add zuerst)
claude plugin marketplace add KornmuellerConsulting/work-convention-plugin
claude plugin install work-convention@kornmueller-empire

# 4. App-spezifische .env
cp .env.example .env
# In .env eintragen:
#   APP_NAME=customer-portal
#   APP_PROJECT_PREFIX=CUST
#   CURRENT_OPERATOR=justin    (oder patrick)

# 5. ClickUp-Custom-Fields anlegen (Space-ID + List-ID aus Bootstrap-Output zuerst in .env)
PLUGIN_SCRIPTS=$(find ~/.claude/plugins/cache/kornmueller-empire/work-convention -name scripts -type d | sort -V | tail -1)
python3 "$PLUGIN_SCRIPTS/bootstrap-clickup-fields.py"

# 6. Git-Hooks installieren (einmalig pro Monorepo)
bash "$PLUGIN_SCRIPTS/install-git-hooks.sh"

# 7. Healthcheck — sollte 30/30 grün
CLAUDE_PROJECT_DIR=$(pwd) bash "$PLUGIN_SCRIPTS/healthcheck.sh"

# 8. Dependencies + Dev-Server
pnpm install
pnpm dev
```

## Verifikation

Nach Step 7 sollte der Healthcheck zeigen:

```
═══ Summary ═══
  Total: 30 — ✅ 30 / ⚠️  0 / ❌ 0
```

Wenn nicht: siehe [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Smoke-Test der Notification-Pipeline

```bash
PLUGIN_SCRIPTS=$(find ~/.claude/plugins/cache/kornmueller-empire/work-convention -name scripts -type d | sort -V | tail -1)
bash "$PLUGIN_SCRIPTS/notify-test.sh" all
```

Erwartung:
- Slack-Message in `#<app>-build`
- Pushover-Push P0 (wenn PUSHOVER_* gesetzt)
- WhatsApp an beide (wenn CALLMEBOT_* gesetzt)

## Erste Claude-Session

```bash
claude code
```

Beim Start läuft `session-start-briefing.sh` und zeigt Operator/App/Branch.

Erste Prompts:
- `Status zeigen` → führt `/status` aus
- `Wer bin ich gerade?` → `/where` zeigt Identity
- `Tickets zu CUST anzeigen` → `/ticket fetch CUST`

## CI/CD verifizieren

Erster Push triggert die Workflows in `apps/.github/workflows/`:
- `ci-test.yaml` — lint + test
- `ci-deploy-staging.yaml` — Vercel-Preview
- `ci-deploy-prod.yaml` — wird nur durch Tag `<app>-v1.2.3` getriggert (5-Min-Abort)
- `clickup-spiegel.yaml` — sync Status → ClickUp
- `slack-status-digest.yaml` — Tages-Digest in #empire-status

```bash
git add -A
git commit -m "feat(CUST-1): initial scaffold"
git push origin main
gh run watch
```

## Wenn etwas schief geht

```bash
# Bootstrap rückgängig (löscht App-Folder + ClickUp-Space)
bash scripts/cleanup-failed-bootstrap.sh --name customer-portal

# Plugin-Cache neu pullen
claude plugin marketplace update kornmueller-empire
claude plugin update work-convention@kornmueller-empire

# Hooks-Test (zeigt ob alle 22 Hook-Tests grün sind)
PLUGIN_HOOKS=$(find ~/.claude/plugins/cache/kornmueller-empire/work-convention -name hooks -type d | sort -V | tail -1)
bash "$PLUGIN_HOOKS/tests/test-runner.sh"
```

## Was dann?

Ab hier ist die App im Workflow:
- Tickets in ClickUp, Custom-IDs `CUST-NNN`
- Conventional Commits mit Ticket-ID (per git-Hook enforced)
- Decision-Blocks für nicht-triviale Wahlen → `DECISIONS.md`
- `/handoff` am Session-Ende → postet Stand zu ClickUp
- 3-Layer-Eskalation greift automatisch ab Fail #3

Volle Konstitution: [Master-CLAUDE.md](../templates/CLAUDE.md)
Working-Agreement: [WORKING_AGREEMENT.md](./WORKING_AGREEMENT.md)
Escalation-Modell: [ESCALATION.md](./ESCALATION.md)
