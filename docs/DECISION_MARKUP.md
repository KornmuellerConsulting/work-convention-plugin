# Decision-Markup-Spec

## Format

```
DECISION: <Kurztitel, max 60 Zeichen>
TICKET: <PREFIX-NR>
PROBLEM: <was war das Problem>
ALTERNATIVES:
  A) <Option A>
  B) <Option B>
DECISION: <gewählt: A oder B>
RATIONALE: <warum>
DATE: <YYYY-MM-DD>
OPERATOR: <patrick|justin|builder-subagent|solver-subagent|...>
LAYER: <1|2|3>
```

Optionale Felder:

- `EXPIRY: <YYYY-MM-DD>` — Workaround-Decisions: Datum bis wann re-evaluieren
- `ROLLBACK: <Plan>` — bei Production-Decisions
- `REVIEWED-BY: <name>` — bei Layer-3 die Co-Founder-Bestätigung

## Persistenz

**DECISIONS.md** im App-Repo (Append-Only, git-versioniert) — sonst nichts.
v2.0 hat keinen Auto-Post-Hook mehr, der Blocks aus Edits parsed und
irgendwo spiegelt. Claude schreibt den Block direkt und vollständig in
`DECISIONS.md`, in derselben Aktion, die die Entscheidung trifft. Kein
zweiter Persistenz-Pfad, keine Signatur-Datei, kein Throttle — der Block
existiert erst, wenn er im Append-Only-Log steht.

## Wann Decision-Block schreiben

✅ Library-Wahl (zod vs yup, etc.)  
✅ Architecture-Pattern-Wahl  
✅ Workaround statt sauberer Fix (mit EXPIRY)  
✅ Performance-Optimierung mit Tradeoff  
✅ Layer-2-Solver-Diagnose-Ergebnis  
✅ Layer-3-Co-Founder-Decision  
✅ Production-Deploy

❌ Trivialer Refactor  
❌ Type-Fix ohne Pattern-Auswirkung  
❌ Test-Hinzufügung  
❌ Doku-Update

## Beispiele

### Layer 1 — Library-Wahl

```
DECISION: zod gewählt für API-Validation
TICKET: EXAMPLE-42
PROBLEM: API-Endpoints brauchen Input-Validation
ALTERNATIVES:
  A) zod (TypeScript-first, ~12kb)
  B) yup (~28kb, älter)
  C) joi (~145kb, Node-fokussiert)
DECISION: A
RATIONALE: Bundle-Size, TS-Inference, Empire-Konsistenz mit anderen Apps
DATE: 2026-05-10
OPERATOR: justin
LAYER: 1
```

### Layer 2 — Solver

```
DECISION: Race-Condition in Login-Flow gefixt via Mutex
TICKET: EXAMPLE-43
PROBLEM: 3× Test-Fail, Login-State racet zwischen useEffect-Runs
ALTERNATIVES:
  A) Mutex via useRef
  B) Debounce
  C) Refactor zu State-Machine
DECISION: A
RATIONALE: Minimal-invasiv, B verzögert UX, C zu aufwändig für aktuellen Sprint
DATE: 2026-05-10
OPERATOR: solver-subagent
LAYER: 2
EXPIRY: 2026-08-10
```

### Layer 3 — Co-Founder

```
DECISION: Stripe statt Paddle für Billing
TICKET: EXAMPLE-44
PROBLEM: Payment-Provider-Wahl mit langfristigen Lock-In-Folgen
ALTERNATIVES:
  A) Stripe — ausgereift, dev-friendly, höhere Fees
  B) Paddle — MoR, EU-Steuern automatisch, Lock-In stärker
DECISION: A
RATIONALE: Empire-Konsistenz mit anderen Apps, Lock-In bei Paddle riskant
DATE: 2026-05-10
OPERATOR: patrick + justin
LAYER: 3
REVIEWED-BY: both
```
