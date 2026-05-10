# Working Agreement — Patrick + Justin

Co-Founder-Konvention für die Kornmueller-Consulting-Apps.

## Grundprinzip

**Beide gleichberechtigt, beide Admin überall.** Keine Hierarchie. Bei
Layer-3-Eskalationen werden beide parallel gepingt (`broadcast_both`).

## Operator-Identifikation

Pro Worktree wird `CURRENT_OPERATOR` in `.env` gesetzt:
- `CURRENT_OPERATOR="patrick"` oder `CURRENT_OPERATOR="justin"`

Damit weiß Claude wer gerade redet. `session-start-identity-pin.sh` schreibt
das in `.claude/state/session-identity.json`.

## Kein Konflikt-Veto

Wenn beide eine andere Meinung haben:
1. 24h Cooldown (kein Push)
2. Asynchrone Diskussion über DECISIONS.md mit beiden Statements
3. Gemeinsame Alternative finden, nicht "Sieger"

Wenn nach 24h kein Konsens: Layer-3-Eskalation an "uns selbst" — beide kommen
zusammen, klären synchron.

## Migration-Slot-Lock

Nur einer migriert pro App gleichzeitig. `pre-bash-migration-slot.sh` setzt Lock
für 30 Min. Override: andere Person löscht `.claude/state/migration.lock`.

## Hand-off-Protokoll

Wer aufhört committed alles und ruft `/handoff` → postet Comment im aktiven
ClickUp-Task mit Branch, HEAD, Status. Andere Person kann nahtlos einsteigen.

## ClickUp-Variante A

Pro App eigener Space. Beide haben Vollzugriff auf alle Spaces. Custom-Task-IDs
mit Prefix (z.B. `EXAMPLE-42`).

## Weekly Sync

Jeden Sonntag 18 Uhr (oder nach Verfügbarkeit):
- Empire-Status review (Dashboard auf GitHub-Pages)
- Open Blockers
- Strategie für nächste Woche
- Plugin-Improvements
