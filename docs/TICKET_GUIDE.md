# Ticket-Guide — User-Stories für Claude Code

## Format

Gute Tickets haben 3 Teile:

```markdown
## User-Story

Als <Rolle> möchte ich <Funktion>, damit <Benefit>.

## Acceptance-Criteria

- [ ] <kriterium 1>
- [ ] <kriterium 2>
- [ ] <kriterium 3>

## Out of Scope

- <was explizit NICHT Teil ist>
```

## Beispiel

```markdown
## User-Story

Als User möchte ich mich mit Email + Password einloggen können, damit
ich Zugriff auf meinen geschützten Bereich habe.

## Acceptance-Criteria

- [ ] Login-Form unter /login erreichbar
- [ ] Validation: Email format, Password ≥8 Zeichen
- [ ] Erfolgreicher Login → Redirect zu /dashboard
- [ ] Falsches Passwort → Fehlermeldung "Email oder Passwort falsch" (kein User-Enumeration)
- [ ] Session via Supabase-Auth, JWT-Cookie
- [ ] Logout-Button im Header
- [ ] E2E-Test: Login + Logout-Flow

## Out of Scope

- Password-Reset (separates Ticket)
- 2FA (separates Ticket)
- Social Login (separates Ticket)
```

## Warum strukturiert?

Builder-Subagent kann **Acceptance-Criteria 1:1 zu Tests mappen**. "Out of Scope"
verhindert Scope-Creep. User-Story-Format zwingt zu Benefit-Klarheit.

## Sub-Tasks

Bei größeren Tasks: Sub-Tasks in ClickUp anlegen, jeweils mit eigenen
Acceptance-Criteria. Builder arbeitet sub-task-weise.

## Layer-Indikator

Custom-Field "Layer" pro Task:
- **1** — Routine, autonom
- **2** — Komplex, eventuell Solver
- **3** — Architektur-Entscheidung mit Co-Founder-Diskussion

## Anti-Patterns

❌ "Login-Feature implementieren" (zu vage, keine Acceptance)  
❌ "Make it work" (kein Out-of-Scope)  
❌ Acceptance-Criteria mit > 7 Punkten (zu groß, Sub-Tasks splitten)  
❌ Acceptance ohne testable Outcomes ("UI sieht gut aus")  

## Status-Mapping

| ClickUp-Status   | Bedeutung |
|-------------------|-----------|
| TODO              | Refined, ready for pickup |
| IN PROGRESS       | Aktiv bearbeitet |
| READY-TO-DEPLOY   | Code done, Tests grün, lokal merged |
| DEPLOYED-STAGE    | Stage-Deploy lief, validiert |
| DONE              | Production-Deploy lief, verifiziert |
| BLOCKED           | Manueller Eingriff nötig (siehe Comments/BLOCKERS.md) |
