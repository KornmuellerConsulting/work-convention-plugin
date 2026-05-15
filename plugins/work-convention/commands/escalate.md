---
name: escalate
description: Manuelle Eskalation. Argument bestimmt Layer. /escalate reset clearts den Counter.
---

Args: `<2|3|reset> [reason]`

- `/escalate 2 reason` — Layer-2: Solver-Subagent aktivieren
- `/escalate 3 reason` — Layer-3: beide Co-Founder pingen via notify.sh blocker
- `/escalate reset` — Counter + Flags resetten

Implementation:
```bash
# Layer 2:
touch .claude/state/solver-activated.flag
echo "Aktiviere Solver-Subagent für: $REASON"

# Layer 3:
bash ${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh blocker "Layer-3-Eskalation: $REASON" "..."

# Reset:
rm -f .claude/state/escalation-3fail.flag
rm -f .claude/state/solver-activated.flag
rm -f .claude/state/escalation-counter.state
```
