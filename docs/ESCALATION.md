# Eskalations-Modell — 3 Layer

## Layer 1 — Autonom (Default)

Claude arbeitet selbstständig. Library-Wahl, Refactor, Architecture-Patterns
innerhalb bestehender Konventionen, Tests, Stage-Deploys.

**Decision-Block** für nicht-triviale Entscheidungen (siehe DECISION_MARKUP.md).

**Counter:** wird via `post-tool-state.sh` (PostToolUse) gepflegt. Bei
erfolgreichem Tool-Use: Auto-Reset.

## Layer 2 — Solver-Subagent

**Trigger:** 3 aufeinanderfolgende Fails.

`post-tool-state.sh` schreibt `.claude/state/escalation-3fail.flag`.

`userprompt-context-refresh.sh` zeigt Hint im nächsten Prompt:
```
🚨 [Reminder] Hard-Trigger aktiv — Solver-Subagent erforderlich.
```

**Aktivierung:** im Prompt sagen: `Aktiviere Solver-Subagent für [Problem]`,
oder `/escalate 2 [Problem]`.

Das setzt `.claude/state/solver-activated.flag`. Solver-Modus läuft Diagnose
statt Patch (siehe `plugins/work-convention/agents/solver.md`).

**Hard-Block** ab Fail #4 ohne Solver-Aktivierung — `pre-bash-guards.sh`
verweigert weitere Bash-Tool-Uses bis Solver aktiviert oder `/escalate reset`.
Der Block gibt `exit 2` zurück und blockt damit wirklich (bis v1.3 gab der
damalige Einzel-Hook fälschlich `exit 1` zurück und hat nur gewarnt, ohne
tatsächlich zu blocken — siehe [HOOKS.md](./HOOKS.md)).

## Layer 3 — Co-Founder

**Trigger:** echte architektonische Entscheidung, oder Solver scheitert nach 3
Hypothesen, oder Production-Outage.

**Aktivierung:**
```
/escalate 3 "<Titel/Beschreibung>"
```

Ruft im Hintergrund `notify.sh blocker` auf (siehe [NOTIFICATION.md](./NOTIFICATION.md)).
Ohne konfigurierte Layer-3-Notify-Keys in `.env` meldet sich das nur lokal im
Chat — die Eskalation selbst funktioniert trotzdem, nur der externe Ping
entfällt.

**Decision-Block** in DECISIONS.md mit `LAYER: 3`.

## Reset

Manuell falls etwas hängt:
```
/escalate reset
```
Löscht counter, flags, solver-activated.

## Reviewer-Subagent

Kein automatischer 30-Min-Trigger mehr in v2.0. Manuell anfordern, wenn eine
zweite Meinung zu Drift/Konventionstreue gebraucht wird (siehe
`plugins/work-convention/agents/reviewer.md`).
