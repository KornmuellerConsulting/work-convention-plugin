# ClickUp-Integration

## Workspace-Struktur (Variante A)

Pro App eigener Space. Im Space eine "Tasks"-Liste mit Custom-Status-Field.

```
Workspace: Kornmueller Consulting
├── Space: example-web
│   └── List: Tasks
│       Tasks: TODO/IN PROGRESS/READY-TO-DEPLOY/DEPLOYED-STAGE/DONE/BLOCKED
├── Space: customer-portal
│   └── ...
└── Space: ...
```

## Custom-Fields (5)

Audit-Fix #4: einmalig per `bootstrap-clickup-fields.py` angelegt.

| Field | Type | Werte |
|-------|------|-------|
| Layer | dropdown | 1 / 2 / 3 |
| Escalation Count | number | 0..n |
| GitHub PR | url | - |
| Deployment Env | dropdown | stage / production / both / none |
| Decision Block | text | - |

## Status-Workflow

```
TODO → IN PROGRESS → READY-TO-DEPLOY → DEPLOYED-STAGE → DONE
                  ↓
              BLOCKED (manueller Eingriff)
```

`advance_only_from`-Schutz: kein Rückwärtsspringen außer mit `--force`.

## 8 Sync-Trigger

1. **Task-Erstellung** (`/ticket new`) → ClickUp-Task
2. **Status-Change** (`/ticket status`) → mit advance-only-Schutz
3. **Decision-Block** (Edit auf DECISIONS.md) → ClickUp-Comment via Hook
4. **Hand-off** (Stop) → Hand-off-Comment via Hook
5. **Sync-Tasks** (`clickup-spiegel.py sync-tasks`) → TASKS.md aktualisieren
6. **Comment** (`/ticket comment`) → ClickUp-Comment
7. **Fetch** (`/ticket fetch`) → Task-Details lesen
8. **Bootstrap** (`bootstrap-clickup-fields.py`) → Initial Custom-Fields

## Custom-Task-IDs

Format: `<PREFIX>-<n>` z.B. `EXAMPLE-42`. ClickUp resolved via:
```
GET /task/EXAMPLE-42?custom_task_ids=true&team_id=<id>
```

`get_task_id_by_custom_id()` in `clickup-spiegel.py` macht das automatisch.

## Setup pro App

```bash
# 1. Space + Tasks-List anlegen
python3 .claude/scripts/clickup-spiegel.py bootstrap-space --space-name <app-name>

# Output: Space-ID + List-ID → in .env eintragen

# 2. Custom-Fields anlegen (idempotent)
python3 .claude/scripts/bootstrap-clickup-fields.py

# Output: 5 Field-IDs → in .env eintragen

# 3. Healthcheck
bash .claude/scripts/healthcheck.sh
```
