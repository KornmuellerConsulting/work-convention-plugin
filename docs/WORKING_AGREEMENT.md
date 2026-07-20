# Working Agreement — Patrick + Justin

Co-Founder-Konvention für die Kornmueller-Consulting-Apps.

## Grundprinzip

**Beide gleichberechtigt, beide Admin überall.** Keine Hierarchie. Bei
Layer-3-Eskalationen werden beide parallel gepingt (`broadcast_both`).

## Operator-Identifikation

Pro Worktree wird `CURRENT_OPERATOR` in `.env` gesetzt:
- `CURRENT_OPERATOR="patrick"` oder `CURRENT_OPERATOR="justin"`

Damit weiß Claude wer gerade redet — gelesen z.B. vom Migrations-Slot-Lock.

## Kein Konflikt-Veto

Wenn beide eine andere Meinung haben:
1. 24h Cooldown (kein Push)
2. Asynchrone Diskussion über DECISIONS.md mit beiden Statements
3. Gemeinsame Alternative finden, nicht "Sieger"

Wenn nach 24h kein Konsens: Layer-3-Eskalation an "uns selbst" — beide kommen
zusammen, klären synchron.

## Migration-Slot-Lock

Nur einer migriert pro App gleichzeitig. `pre-bash-guards.sh` setzt bei
DB-Migrations-Commands einen Lock für 30 Min. Override: andere Person löscht
`.claude/state/migration.lock`.

## Hand-off-Protokoll

Wer aufhört committed alles und pflegt `BLOCKERS.md`/`DECISIONS.md` auf den
aktuellen Stand, damit die andere Person beim nächsten Session-Start ohne
Rückfrage einsteigen kann. Kein automatischer Hand-off-Post mehr — der
Zustand steht in den Dateien selbst, nicht in einem externen Kommentar.

## Weekly Sync

Jeden Sonntag 18 Uhr (oder nach Verfügbarkeit):
- Open Blockers (`BLOCKERS.md` je App)
- Strategie für nächste Woche
- Plugin-Improvements
