---
name: status
description: Zeigt aktuellen Empire-Status (Operator, Branch, Tasks, Open Blockers).
---

Zeige dem User den aktuellen Status kompakt auf einem Bildschirm:

1. **Identity:** Operator + Branch + HEAD aus `.claude/state/session-identity.json` (falls fehlt: "Session noch nicht initialisiert")
2. **STATUS.md:** Top 10 Zeilen oder kompletten Inhalt wenn kürzer (falls fehlt: "Keine STATUS.md angelegt")
3. **Top Tasks:** aus `TASKS.md` Top 5 (falls fehlt: nicht anzeigen)
4. **Open Blockers:** aus `BLOCKERS.md` Top 5 (falls fehlt oder leer: "Keine offenen Blockers")
5. **Eskalation:** aus `.claude/state/escalation-counter.state` falls existiert ("X Fails — Solver erforderlich" wenn Flag gesetzt)

Format kompakt mit klaren Section-Headern. Keine Warning-Spam bei fehlenden optionalen Files.
