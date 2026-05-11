---
name: handoff
description: Beendet Session sauber. Stop-Hooks laufen automatisch (Hand-off-Comment + Completeness-Check).
---

1. Status finalisieren — Edits committed?
2. Trigger Stop-Phase:
   - `stop-handoff-comment.sh` postet Comment in aktuellem ClickUp-Task
   - `stop-completeness.sh` warnt bei ungelösten Issues

Sage dem User: "Hand-off durchgeführt. Co-Founder kann übernehmen."
