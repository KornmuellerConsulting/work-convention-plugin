# Notification — Layer-3-only

v2.0 hat kein automatisches Notification-Routing mehr (kein CI-Digest, kein
Auto-Post bei jedem Subagent-Ergebnis). Die `notify.sh`-Familie existiert nur
noch als Transport für `/escalate 3` — sie läuft ausschließlich bei einer
bewussten, manuellen Layer-3-Eskalation.

## Wann läuft das

```
/escalate 3 "<Titel/Beschreibung>"
```

Das ruft intern auf:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh blocker "Layer-3-Eskalation: <Titel>" "<Beschreibung>"
```

Sonst nirgends. Kein Stage-Deploy-Ping, kein Subagent-Report, kein
Test-Failure-Push.

## Master-Wrapper

```bash
bash <plugin>/scripts/notify.sh <severity> <subject> <body> [--no-rate-limit] [--ticket TICKET-ID]
```

`severity` bestimmt Kanal/Priorität (`blocker` ist der für `/escalate 3`
relevante Fall; die anderen Stufen existieren im Script, werden aber von
keinem Hook mehr automatisch aufgerufen):

| Severity   | Slack-Channel       | Pushover | WhatsApp |
|------------|---------------------|----------|----------|
| `blocker`  | #empire-blockers    | P1       | beide    |
| `confirm`  | #empire-blockers    | P2       | beide    |

`blocker`/`confirm` mentionen beide Co-Founder (`broadcast_both`).

## Channels — alle optional

Ohne konfigurierte Keys in `.env` (siehe [SETUP.md](./SETUP.md), Abschnitt
"Optional — Layer-3-Notify") meldet sich `/escalate 3` nur lokal im Chat.
Die Eskalation selbst (Flags, Decision-Block-Pflicht) funktioniert
unabhängig davon.

### Slack (`notify-slack.sh`)
`chat.postMessage`-API mit Bot-Token, keine Webhooks.

### Pushover (`notify-pushover.sh`)
Sendet an beide User-Keys parallel. P1 (`blocker`), P2 (`confirm`, mit
Acknowledge-required).

### WhatsApp (`notify-whatsapp.sh`) — best-effort
CallMeBot-Service, keine SLA. Rate-Limit pro Empfänger: 30 Min Cooldown.
Nicht als einzige Quelle für kritische Operationen verlassen.

## Dedup

Gleiche `severity|subject` werden 5 Min lang dedupliziert (`--no-rate-limit`
zum Überschreiben). `confirm` ist nie dedupliziert.

## Fail-loud

Wenn `blocker`/`confirm` über **keinen** Channel zugestellt werden kann →
`notify.sh` gibt `exit 2` und schreibt eine Warnung nach stderr.

## Test

```bash
bash <plugin>/scripts/notify-test.sh all       # alle
bash <plugin>/scripts/notify-test.sh slack
bash <plugin>/scripts/notify-test.sh pushover
bash <plugin>/scripts/notify-test.sh whatsapp
```

## Setup-Voraussetzungen

Siehe [SETUP.md](./SETUP.md), Abschnitt "Optional — Layer-3-Notify".
