# Eskalations-Modell — 3 Layer

## Layer 1 — Autonom (Default)

Claude arbeitet selbstständig. Library-Wahl, Refactor, Architecture-Patterns
innerhalb bestehender Konventionen, Tests, Stage-Deploys.

**Decision-Block** für nicht-triviale Entscheidungen (siehe DECISION_MARKUP.md).

**Counter:** wird via `escalation-counter.sh` (PostToolUse) gepflegt.
Bei Erfolgreichem Tool-Use: Auto-Reset (Audit-Fix #16).

## Layer 2 — Solver-Subagent

**Trigger:** 3 aufeinanderfolgende Fails (Audit-Fix #1).

`escalation-counter.sh` schreibt `.claude/state/escalation-3fail.flag`.

`userprompt-context-refresh.sh` zeigt Hint im nächsten Prompt:
```
🚨 [Reminder] Hard-Trigger aktiv — Solver-Subagent erforderlich.
```

**Aktivierung:** im Prompt sagen: `Aktiviere Solver-Subagent für [Problem]`.

Das setzt `.claude/state/solver-activated.flag`. Solver-Modus läuft Diagnose
statt Patch (siehe `claude/agents/solver.md`).

**Hard-Block** ab Fail #4 ohne Solver-Aktivierung — `pre-bash-escalation-block.sh`
verweigert weitere Bash-Tool-Uses bis Solver aktiviert oder `/escalate reset`.

## Layer 3 — Co-Founder

**Trigger:** echte architektonische Entscheidung, oder Solver scheitert nach 3
Hypothesen, oder Production-Outage.

**Aktivierung:**
```bash
bash .claude/scripts/notify.sh blocker "Layer-3: <Titel>" "<Beschreibung>"
```

`notify.sh` sendet:
- Slack #empire-blockers mit @Patrick + @Justin (broadcast_both)
- Pushover P1 an beide
- WhatsApp an beide (best-effort)

**Decision-Block** in DECISIONS.md mit `LAYER: 3`.

## Reset

Manuell falls etwas hängt:
```
/escalate reset
```
Löscht counter, flags, solver-activated.

## Reviewer-Subagent

Läuft alle 30 Min via UserPromptSubmit-Hint (Audit-Fix #2). Detektiert Drift,
fixt nicht. Schreibt `.claude/state/reviewer-finding.md`.
