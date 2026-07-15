# SETUP — Plugin in einer App installieren

Dauer: 60-90 Min für die erste App, ~20 Min für jede weitere.

## Vorbereitung

Bevor du eine App bootstrappst, brauchst du **einmalig** folgende Setups:

### 1. ClickUp (einmalig pro Workspace)

- ClickUp-Account mit eigenem Workspace
- API-Token: ClickUp → Settings → Apps → API Token → Generate
- `CLICKUP_API_TOKEN` in `.env`
- `CLICKUP_TEAM_ID` (Workspace-ID, in URL sichtbar): in `.env`

### 2. Slack (einmalig)

Slack-App erstellen: https://api.slack.com/apps → Create New App → From scratch

OAuth-Scopes (Bot-Token):
- `chat:write`
- `chat:write.public`
- `channels:read`
- `channels:join`
- `conversations.history`

Bot installieren in Workspace, Bot-Token kopieren → `SLACK_BOT_TOKEN`.

User-IDs für Mentions:
- In Slack → Profil → "..." → Member-ID kopieren
- Patrick → `SLACK_USER_PATRICK`
- Justin → `SLACK_USER_JUSTIN`

Channels einmalig erstellen:
- `#empire-status`
- `#empire-blockers`
- (pro App: `#<app>-build` wird vom Bootstrap erstellt)

### 3. Pushover (einmalig pro Person)

Each: https://pushover.net → $5 einmalig pro Device.

App registrieren → App-Token kopieren → `PUSHOVER_APP_TOKEN` (gleich für beide).

User-Keys:
- Patrick: nach Login auf Dashboard sichtbar → `PUSHOVER_USER_PATRICK`
- Justin: dasselbe → `PUSHOVER_USER_JUSTIN`

### 4. WhatsApp via CallMeBot (einmalig pro Person)

Best-effort, keine SLA. Each:

1. Speichere `+34 644 51 95 23` als Kontakt
2. Sende `I allow callmebot to send me messages` an die Nummer
3. Warte auf Antwort mit API-Key
4. In `.env`:
   - Patrick: `CALLMEBOT_PHONE_PATRICK="+49..."`, `CALLMEBOT_APIKEY_PATRICK="..."`
   - Justin: dasselbe

Details + Limits: [docs/NOTIFICATION.md](./NOTIFICATION.md)

### 5. GitHub PAT (einmalig)

Settings → Developer Settings → Personal Access Tokens → Fine-grained:

Scopes: `repo`, `workflow`, `write:packages`.

Token in `.env`: `GITHUB_PAT`.

### 6. Vercel (einmalig)

Vercel-Account, mit GitHub verbunden. Token erstellen via Account → Tokens.

`VERCEL_TOKEN` in `.env`.

`VERCEL_ORG_ID` und `VERCEL_PROJECT_ID` werden pro App gesetzt (siehe Bootstrap).

### 7. Supabase (optional, je nach App)

Pro App: 2 Projects (Stage + Prod) auf supabase.com → URL Refs in `.env`.

## App-Bootstrap

```bash
cd <monorepo-root>  # apps-Repo
bash scripts/bootstrap-app.sh --name <app-name> --prefix <PREFIX> --stack web
```

Was passiert (10 Steps):
1. Validate args (kebab-case, prefix uppercase, no collision)
2. Folder anlegen: `apps/<name>/`
3. `apps/example-web/` als Skeleton kopieren
4. `package.json` patchen (Name, Workspace-Refs)
5. CLAUDE.md placeholder-replace
6. ClickUp-Space anlegen (Variant A: own Space)
7. ClickUp-Custom-Fields anlegen
8. Slack-Channel erstellen (`#<app>-build`)
9. Vercel-Project anlegen (Mono-Repo-Mode)
10. Supabase Stage + Prod (optional, prompt)

Im Fehlerfall ERR-Trap → cleanup-failed-bootstrap.sh aufrufen.

## Plugin installieren

In der gerade gebootstrappten App:

```bash
cd apps/<app-name>
claude plugin install KornmuellerConsulting/work-convention-plugin
```

Das ruft `post-install.sh` auf:
- Kopiert `.claude/`-Komponenten
- Kopiert CLAUDE.md ins App-Root (falls nicht vorhanden)
- Kopiert `.env.example` ins App-Root
- Setzt Marker

## .env ausfüllen

```bash
cp .env.example .env
# Editieren mit Werten aus den Pre-Setups oben
```

## Healthcheck

```bash
bash .claude/scripts/healthcheck.sh
```

Prüft:
- Plugin-Files vollständig
- Identity (APP_NAME, OPERATOR)
- ClickUp/Slack/Pushover/WhatsApp/Tools

Bei `❌ Fail`-Output: behebe vor erstem Tool-Use.

## Erstes Smoke-Test

```bash
# Notification-Test
bash .claude/scripts/notify-test.sh all

# Status-Generator
python3 .claude/scripts/status-generate.py --mode markdown

# Plugin-Audit (Curated-Empfehlungen)
python3 .claude/scripts/plugin-audit.py --mode bootstrap
```

## Erste Claude-Code-Session

```bash
claude code
```

Beim Start läuft `session-start-briefing.sh`. Du siehst:
- Operator
- App
- Branch
- Eventuelle Reviewer-Findings
- Hard-Trigger-Status

Beispiel-Prompt: `Status zeigen` → führt `/status` aus.

## Advisor-Modell (automatisch, ab Plugin-Version 1.2.4)

Claude Code kann bei unsicheren Entscheidungen automatisch ein zweites, stärkeres
Modell konsultieren ("Advisor", ab Claude Code v2.1.170). Der Hook
`session-start-advisor-default.sh` trägt beim ersten Sessionstart nach
Plugin-Install/-Update `advisorModel: "opus"` in die lokale `~/.claude/settings.json`
ein, **falls dort noch keiner gesetzt ist**. Läuft auf jeder Maschine automatisch,
sobald das Plugin dort installiert/geupdated wird — kein manueller Schritt pro
Person/Gerät nötig. Eine bereits vorhandene, explizite Wahl (auch ein anderes
Modell) wird nie überschrieben.

Gilt **pro Maschine**, nicht pro Account — auf jedem Rechner, auf dem `claude`
läuft (Terminal oder Claude Desktop), muss das Plugin einmal laufen, damit der
Hook feuert. Kein Cloud-Sync über Geräte hinweg, das gibt's in Claude Code nicht.

Ändern/deaktivieren jederzeit selbst:

```bash
# in einer echten Terminal-Session (nicht im Claude-Desktop-Chat-Fenster —
# dort blockt /advisor mit "opens an interactive panel", weil es einen
# Picker öffnet; ist eine Einschränkung der Desktop-Oberfläche, kein Bug):
/advisor sonnet   # oder: opus, fable
/advisor          # Picker mit allen erlaubten Kombinationen
/advisor off      # deaktivieren
```

Oder direkt in `~/.claude/settings.json`. Seit dem Fix an
`pre-edit-plugin-files.sh` (1.2.4) schützt der Hook dort nur noch
`enabledPlugins`/`extraKnownMarketplaces` (echtes Plugin-Wiring), generische
Settings wie `advisorModel` sind frei editierbar.

Anderen Default als `opus`? `WORK_CONVENTION_ADVISOR_DEFAULT` in `.env` setzen,
bevor der Hook zum ersten Mal läuft.

Erlaubte Advisor-Modelle hängen vom Hauptmodell ab (Sonnet-5-Main akzeptiert
`sonnet`, `opus`, `fable` als Advisor; ein Sonnet-4.6-Advisor wird abgelehnt).
Details: [offizielle Advisor-Doku](https://code.claude.com/docs/en/advisor).

## Häufige Fehler beim ersten Setup

| Fehler | Lösung |
|--------|--------|
| `CLICKUP_API_TOKEN nicht gesetzt` | `.env` korrekt geladen? `set -a; source .env; set +a` |
| Slack `auth.test` fail | Token kopiert? Bot ins Workspace installiert? |
| Pushover P0/P1 nicht angekommen | Device-Key korrekt? Pushover-App auf Phone offen? |
| ClickUp 404 bei Custom-Fields | Liste richtig? `bootstrap-clickup-fields.py` zuerst? |
| `chmod +x` fehlt | `find .claude -name "*.sh" -exec chmod +x {} \;` |

Detail-Troubleshooting: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
