---
name: ticket
description: ClickUp-Ticket-Operations. Sub-Commands new, status, comment, fetch.
---

Args: `<new|status|comment|fetch> [args]`

- `/ticket new "Title" "Description"` — neuen Task in aktuellem Space
- `/ticket status TICKET-42 IN_PROGRESS` — Status ändern
- `/ticket comment TICKET-42 "Comment"` — Comment posten
- `/ticket fetch TICKET-42` — Task-Details lesen

Wrapper für `python3 .claude/scripts/clickup-spiegel.py ...`.
