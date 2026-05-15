---
name: blocked
description: Markiert aktuellen Task als BLOCKED in ClickUp + postet in #empire-blockers.
---

1. Frage User nach Blocker-Beschreibung
2. Update Ticket-Status zu BLOCKED:
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/scripts/clickup-spiegel.py status --ticket $TICKET --status BLOCKED
   ```
3. Append zu BLOCKERS.md
4. Slack-Post in #empire-blockers via:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh blocker "[$TICKET] $TITLE" "$DESCRIPTION"
   ```
