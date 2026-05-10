# Notification-Routing

## Severity-Matrix

| Severity   | Slack-Channel       | Pushover | WhatsApp | Beispiel |
|------------|---------------------|----------|----------|----------|
| `status`   | #empire-status      | -        | -        | Stage-Deploy ok |
| `info`     | #<app>-build        | -        | -        | Subagent-Report |
| `warning`  | #<app>-build        | P0       | -        | Test-Failure |
| `blocker`  | #empire-blockers    | P1       | beide    | Layer-3 |
| `confirm`  | #empire-blockers    | P2       | beide    | Production-Outage |

P2 = Pushover Acknowledge-required (retry 60s, expire 1h).

## Master-Wrapper

```bash
bash .claude/scripts/notify.sh <severity> <subject> <body> [--no-rate-limit] [--ticket TICKET-ID]
```

## Channels

### Slack (`notify-slack.sh`)

`chat.postMessage`-API mit Bot-Token (Audit-Fix #5). Keine Webhooks.

Bei `blocker`/`confirm` werden beide Co-Founder mentioned (`<@USER_ID>`).

### Pushover (`notify-pushover.sh`)

Sendet an beide User-Keys parallel (broadcast_both).

P0 (warning), P1 (blocker), P2 (confirm — mit Ack-required).

### WhatsApp (`notify-whatsapp.sh`) — best-effort

CallMeBot-Service, keine SLA. **Limits:**
- Rate-Limit pro Empfänger: 30 Min Cooldown
- Service-Outage möglich
- Nicht für kritische Operations als einzige Quelle

Audit-Fix #19: Wenn `blocker`/`confirm` über **keinen** Channel geht → exit 2 + stderr-Warnung.

## Dedup

Default: gleiche `severity|subject` werden 5 Min lang dedupliziert.
Override: `--no-rate-limit`.

`confirm` ist nie dedupliziert.

## Test

```bash
bash .claude/scripts/notify-test.sh all       # alle
bash .claude/scripts/notify-test.sh slack
bash .claude/scripts/notify-test.sh pushover
bash .claude/scripts/notify-test.sh whatsapp
```

## Setup-Voraussetzungen

Siehe [SETUP.md](./SETUP.md) Abschnitte 2-4.
