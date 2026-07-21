# Statusline — Tacho fürs Abo (v2.1)

Eine Zeile im Claude-Code-Footer: **Modell | Kontext-% | 5h-Limit-% |
Wochen-Limit-%**. Kontext-% mit Farbschwellen (grün < 50, gelb < 75, rot ab 75).

Das ist die Lean-Core-konforme Antwort auf „wie voll ist mein Abo": eine
**ambiente Anzeige**. Die Statusline geht nie ins Kontextfenster des Modells
ein — sie rendert nur im Terminal und kostet damit exakt null Tokens pro
Session, egal wie oft sie aktualisiert.

## Aktivieren (einmalig pro Maschine, Opt-in)

Claude Code kann keinen Statusline-Default aus einem Plugin laden — deshalb
ist das ein bewusster Ein-Zeilen-Opt-in in der eigenen `~/.claude/settings.json`
(das Plugin schreibt **niemals** selbst in User-Settings):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$(ls -d \"$HOME\"/.claude/plugins/cache/kornmueller-empire/work-convention/*/scripts/statusline.sh 2>/dev/null | sort -V | tail -1)\""
  }
}
```

Der `sort -V`-Resolver zeigt immer auf die höchste installierte Plugin-Version
(Cache-Resolver-Pattern aus QUICKSTART) — die Statusline überlebt also jedes
Plugin-Update ohne dass der Eintrag angefasst werden muss. Voraussetzung:
Plugin ≥ 2.1.0 installiert (ältere Versionen haben das Script nicht).

`scripts/healthcheck.sh` erinnert mit einer Warnung, solange keine Statusline
konfiguriert ist.

## Verhalten

- **Fehlende Felder = stumme Segmente.** API-Key-Sessions haben keine
  `rate_limits` → die zwei Limit-Segmente entfallen ohne Fehler. Der
  allererste Render einer Session hat `used_percentage=null` → nur das
  Modell erscheint, der Rest kommt nach dem ersten Turn.
- **Injection-fest:** Feldwerte werden per jq-Codepoint-Filter von sämtlichen
  Control-Chars (inkl. ESC) bereinigt und nie als printf-Format interpretiert.
- **Portabel:** nur `jq` + Bash-Builtins. Kein git, kein Netz, keine
  BSD-only-Tools — läuft auf macOS, Linux und Windows/Git-Bash. Laufzeit
  gemessen ~5 ms.

## Warum kein Plugin-Default? (Phase-0-Befund, 2026-07-21)

Empirisch gegen Claude Code 2.1.210 verifiziert (`--plugin-dir`-Testplugin,
dessen Hook feuerte, dessen `settings.json`-Statusline aber tot blieb) und von
der Plugins-Reference bestätigt: eine `settings.json` im Plugin-Root
unterstützt nur die Keys `agent` und `subagentStatusLine` — **nicht**
`statusLine`. Die Settings-Precedence (managed > CLI > local > project > user)
kennt keinen Plugin-Layer. Sollte eine spätere Claude-Code-Version
Plugin-Statusline-Defaults lernen, kann der Opt-in entfallen; die
User-Settings würden ihn dann ohnehin überstimmen.

## Verwandt: Auto-Compact früher triggern (optional)

Der Auto-Compact-Schwellwert ist **nicht** über `settings.json` konfigurierbar,
sondern nur über eine Env-Var (dokumentiert in „Manage costs", im Binary
2.1.210 verifiziert):

```bash
# z.B. in ~/.zshrc — kompaktiert bei 70 % statt ~90 %
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70
```

Das Plugin setzt das bewusst **nicht** automatisch (kein Schreiben in
User-Umgebungen); wer nach der Statusline regelmäßig rot sieht, kann es
pro Maschine selbst setzen. Nach einer Compaction injiziert
`session-start-compact-anchor.sh` die Kern-Anker (Branch, Ticket,
BLOCKERS-Pointer) automatisch neu — siehe [HOOKS.md](./HOOKS.md).
