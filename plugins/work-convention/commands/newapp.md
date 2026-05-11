---
name: newapp
description: Bootstrappt neue App im Monorepo via scripts/bootstrap-app.sh.
---

Args: `<name> <PREFIX> [--stack=web|mobile]`

```bash
cd $(git rev-parse --show-toplevel)  # Monorepo-Root
bash scripts/bootstrap-app.sh --name <name> --prefix <PREFIX> --stack web
```

Was passiert: siehe scripts/bootstrap-app.sh --help.

Nach Bootstrap:
```bash
cd apps/<name>
claude plugin install KornmuellerConsulting/work-convention-plugin
cp .env.example .env
# .env ausfüllen
bash .claude/scripts/healthcheck.sh
```
