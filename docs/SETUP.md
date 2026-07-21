# SETUP — Plugin in einer App installieren

Dauer: wenige Minuten. v2.0 hat keine Pflicht-Pre-Setups mehr (kein ClickUp,
kein Slack, kein Bootstrap-Skript) — Setup ist Plugin installieren, `.env`
mit drei Identity-Keys anlegen, Session starten.

## 1. Plugin installieren

```bash
cd <app-verzeichnis>
claude plugin marketplace add KornmuellerConsulting/work-convention-plugin
claude plugin install work-convention@kornmueller-empire
```

## 2. `.env` anlegen

```bash
cp .env.example .env
```

Trag die drei Identity-Keys ein (siehe `.env.example` im Plugin-Repo):

```bash
APP_NAME="customer-portal"
APP_PROJECT_PREFIX="CUST"       # Ticket-Prefix + Empire-App-Marker
CURRENT_OPERATOR="justin"        # oder "patrick"
```

`APP_PROJECT_PREFIX` ist doppelt wichtig: es ist das Ticket-Prefix fürs
Commit-Format (`feat(CUST-42): ...`) **und** der Marker, an dem
`session-start-ensure-git-hooks.sh` erkennt, dass dies eine Empire-App ist,
in der die git-Hooks automatisch installiert werden dürfen. Ohne diesen Key
fasst das Plugin fremde Repos nie an.

## 3. Session starten

```bash
claude code
```

Beim ersten Start installiert `session-start-ensure-git-hooks.sh` automatisch
die git-Hooks (`commit-msg`, `pre-commit`, `pre-push`) — kein manueller Schritt
nötig. Bei jedem weiteren Session-Start hält derselbe Hook die Wrapper auf der
aktuellen Plugin-Version, auch nach Plugin-Updates.

## 4. Healthcheck zur Kontrolle

```bash
bash ~/.claude/plugins/cache/kornmueller-empire/work-convention/<version>/scripts/healthcheck.sh
```

Prüft:
- Plugin-Files vollständig (13 Hook-Scripts, hooks.json, 7 Agents mit Model-Pins)
- git-Hooks App-lokal installiert und auf aktueller Plugin-Version
- `.env`: `APP_PROJECT_PREFIX` und `CURRENT_OPERATOR` gesetzt
- Tools: `git`, `jq`, `gitleaks` (optional), `gh` (optional)

Bei `❌`-Output vor dem ersten Tool-Use beheben.

## Optional — Layer-3-Notify

Nur nötig, wenn `/escalate 3` echte Slack/Pushover/WhatsApp-Nachrichten
verschicken soll statt sich nur lokal zu melden. Ohne die folgenden Keys in
`.env` funktioniert alles andere trotzdem — `/escalate 3` meldet sich dann
nur im Chat.

### Slack (optional)

Slack-App erstellen: https://api.slack.com/apps → Create New App → From scratch.

OAuth-Scopes (Bot-Token): `chat:write`, `chat:write.public`, `channels:read`,
`channels:join`.

Bot installieren, Bot-Token → `SLACK_BOT_TOKEN` in `.env`. User-IDs für
Mentions (Slack → Profil → "..." → Member-ID) → `SLACK_USER_PATRICK`,
`SLACK_USER_JUSTIN`.

### Pushover (optional)

https://pushover.net → App registrieren → `PUSHOVER_APP_TOKEN`. User-Keys
aus dem jeweiligen Dashboard → `PUSHOVER_USER_PATRICK`, `PUSHOVER_USER_JUSTIN`.

### WhatsApp via CallMeBot (optional, best-effort)

1. `+34 644 51 95 23` als Kontakt speichern
2. `I allow callmebot to send me messages` an die Nummer senden
3. Auf Antwort mit API-Key warten
4. In `.env`: `CALLMEBOT_PHONE_PATRICK`/`CALLMEBOT_APIKEY_PATRICK` (analog Justin)

Details: [docs/NOTIFICATION.md](./NOTIFICATION.md)

## Häufige Fehler beim Setup

| Fehler | Lösung |
|--------|--------|
| git-Hooks installieren sich nicht | `APP_PROJECT_PREFIX` in `.env` gesetzt? Neue Session starten |
| `chmod +x` fehlt bei App-lokalen Scripts | `find .claude -name "*.sh" -exec chmod +x {} \;` |
| Layer-3-Notify kommt nicht an | Siehe [NOTIFICATION.md](./NOTIFICATION.md) — alle Keys optional, ohne sie nur lokale Meldung |

Detail-Troubleshooting: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
