# Troubleshooting

## Hooks

### "Hooks laufen nicht"
- `chmod +x .claude/hooks/*.sh`
- `claude/settings.json` korrekt gewiret? → `cat .claude/settings.json | jq .hooks`

### "Hard-Trigger lässt sich nicht aufheben"
- Aktiviere Solver: `Aktiviere Solver-Subagent für [Problem]`
- Oder: `/escalate reset`

### "HEAD-Drift-Warnung trotz keiner externen Änderung"
- Vermutlich Pre-Tool-Use vor Post-Tool-Use mit unterschiedlichen HEADs
- Reset: `rm .claude/state/last-head.txt`

## ClickUp

### "401 Unauthorized"
- `CLICKUP_API_TOKEN` korrekt? Token enthält keine Anführungszeichen
- Token Scopes prüfen

### "404 Task not found"
- Custom-ID muss `<PREFIX>-<n>` sein, exact case
- `CLICKUP_TEAM_ID` korrekt gesetzt
- Alternativ Internal-ID verwenden

### "Status-Transition not allowed"
- Workflow erlaubt kein Rückwärts. Override: `--force`

### "Custom-Fields fehlen"
- Run: `python3 .claude/scripts/bootstrap-clickup-fields.py`
- Field-IDs aus Output in `.env` eintragen

## Slack

### `auth.test` schlägt fehl
- Bot-Token (`xoxb-...`) statt User-Token (`xoxp-...`)?
- Bot ins Workspace installiert?
- App-Settings → "Install App" geprüft?

### "channel_not_found" bei Post
- Bot ist Channel-Member? `conversations.join` benötigt `channels:join`-Scope
- Channel-Name ohne `#`-Prefix übergeben

### Mentions funktionieren nicht
- `SLACK_USER_PATRICK` = Member-ID (z.B. `U12ABC...`), nicht Username

## Pushover

### "P0 Push kommt nicht an"
- App auf Phone gestartet?
- App-Token korrekt (eine pro App, gleich für beide)?
- User-Key pro Person individuell

### "P2 Push kommt 1×, dann Ruhe"
- P2 = Acknowledge-required. User muss in Pushover-App acken
- Retry/Expire: 60s/3600s konfiguriert

## WhatsApp

### "Message queued but not delivered"
- WhatsApp-Initialisierung gemacht? (`I allow callmebot to send me messages`)
- API-Key korrekt aus CallMeBot-Antwort?
- Telefonnummer mit Ländercode (`+49...`)

### "Rate-Limit-Skip"
- 30 Min Cooldown pro Empfänger
- Reset: `rm .claude/state/wa-rate-PATRICK.timestamp`

## Bootstrap

### "Scheitert mitten drin"
- Cleanup: `bash .claude/scripts/cleanup-failed-bootstrap.sh --name <app>`
- Manuell: Vercel-Project, Supabase-Projects via Dashboard

### "Plugin nicht installiert"
- Manuell: `claude plugin install KornmuellerConsulting/work-convention-plugin`
- Oder: `bash <path-to-plugin>/scripts/post-install.sh`

## Migration-Lock hängt

```bash
rm .claude/state/migration.lock
```

Auto-Cleanup nach 30 Min, aber falls Process tot: manuell.

## Notification-Spam

Dedup-Window 5 Min. Bei wiederkehrenden Spam-Events:
- Severity zu hoch gewählt? → `info` statt `warning`
- Hook-Logik fehlerhaft? → `notify.log` checken in `.claude/state/`

## Plugin-Update bricht

Backup ist da: `.claude.backup-<timestamp>/`. Rollback:
```bash
rm -rf .claude
mv .claude.backup-* .claude
```
