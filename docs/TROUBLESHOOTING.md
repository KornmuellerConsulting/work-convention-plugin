# Troubleshooting

## Hooks

### "Hooks laufen nicht"
- `chmod +x plugins/work-convention/hooks/*.sh` (im Plugin-Cache: `~/.claude/plugins/cache/kornmueller-empire/work-convention/<version>/hooks/*.sh`)
- Registrierung prüfen: `claude -d hooks --debug-file /tmp/claude-debug.log` → `/exit` →
  `grep -iE "registered.*hooks|hook.*load" /tmp/claude-debug.log`. Erwartung:
  `Registered 9 hooks from 1 plugins`. Bei 0: invalides Event in `hooks.json`
  (siehe [HOOKS.md](./HOOKS.md)).

### "Hard-Trigger lässt sich nicht aufheben"
- Aktiviere Solver: `Aktiviere Solver-Subagent für [Problem]` oder `/escalate 2 [Problem]`
- Oder: `/escalate reset`

### "HEAD-Drift-Warnung trotz keiner externen Änderung"
- Vermutlich Pre-Tool-Use vor Post-Tool-Use mit unterschiedlichen HEADs
- Reset: `rm .claude/state/last-head.txt`

### "Eskalations-Hard-Block blockt nicht wirklich"
- Historischer Bug bis v1.3: der damalige Einzel-Hook gab `exit 1` statt
  `exit 2` zurück. Seit v2.0 (`pre-bash-guards.sh`) korrigiert. Wenn ein
  App-lokaler `.claude/settings.local.json`-Override noch den alten Hook
  verdrahtet: entfernen, Plugin-Wiring greifen lassen.

## git-Hooks (commit-msg / pre-commit / pre-push)

### "git-Hooks installieren sich nicht automatisch"
- `APP_PROJECT_PREFIX` in `.env` gesetzt? Ohne diesen Marker fasst
  `session-start-ensure-git-hooks.sh` das Repo nicht an.
- Neue Claude-Code-Session starten (der Hook läuft bei `SessionStart`).
- Manueller Fallback: `bash <plugin>/scripts/install-git-hooks.sh`

### "git-Hooks zeigen auf alte Plugin-Version"
- Nächster Session-Start zieht automatisch nach. Sofort: erneut
  `install-git-hooks.sh` laufen lassen.

### "Commit wird wegen Ticket-ID abgelehnt"
- Format: `<type>(<PREFIX>-<nr>): <description>`, `<type>` aus
  `feat|fix|chore|docs|refactor|test|perf|style`.

### "pre-commit bricht wegen gitleaks"
- `gitleaks` nicht installiert → Scan wird übersprungen, keine Blockade.
  Installieren: `brew install gitleaks`.
- Bei echtem Secret-Fund: Secret aus dem Diff entfernen, in `.env` auslagern.

### "pre-push bricht wegen Tests"
- `pnpm test`/`npm test` lokal ausführen und Fehler beheben, bevor erneut
  gepusht wird. Kein Override außer bewusstem `--no-verify` (dokumentiere das
  in DECISIONS.md, falls wirklich nötig).

## Migration-Lock hängt

```bash
rm .claude/state/migration.lock
```

Auto-Cleanup nach 30 Min, aber falls der Prozess tot ist: manuell.

## Layer-3-Notify (`/escalate 3`)

Alle Channels sind optional — ohne konfigurierte Keys meldet sich
`/escalate 3` nur lokal im Chat, die Eskalation selbst funktioniert trotzdem.

### Slack `auth.test` schlägt fehl
- Bot-Token (`xoxb-...`) statt User-Token (`xoxp-...`)?
- Bot ins Workspace installiert?

### "channel_not_found" bei Post
- Bot ist Channel-Member? `conversations.join` benötigt `channels:join`-Scope

### Pushover kommt nicht an
- App auf Phone gestartet?
- App-Token korrekt, User-Key pro Person individuell?

### WhatsApp "Message queued but not delivered"
- Initialisierung gemacht? (`I allow callmebot to send me messages`)
- API-Key korrekt aus CallMeBot-Antwort? Telefonnummer mit Ländercode?

### "Rate-Limit-Skip"
- 30 Min Cooldown pro Empfänger. Reset: `rm .claude/state/wa-rate-PATRICK.timestamp`

## Plugin-Update bricht

Das Plugin liegt nur im Marketplace-Cache (`~/.claude/plugins/cache/...`),
keine App-lokale Kopie mehr — nichts zu reparieren auf App-Seite. Erneut
ziehen und Session neu starten:
```bash
claude plugin marketplace update kornmueller-empire
claude plugin update work-convention@kornmueller-empire
```
