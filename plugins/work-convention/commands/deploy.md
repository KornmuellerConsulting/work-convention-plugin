---
name: deploy
description: Triggert Stage- oder Production-Deploy.
---

Args: `<stage|prod> [version]`

- `/deploy stage` — Stage läuft auto bei push, hier nur Verify
- `/deploy prod 1.2.3` — Aktiviere Deployer-Subagent, schaffe `<app>-v1.2.3`-Tag

Production-Deploy folgt 5-Min-Abort-Window-Pattern.
