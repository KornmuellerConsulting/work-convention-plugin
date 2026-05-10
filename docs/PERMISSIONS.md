# Permission-Matrix — Kornmueller-Empire

| System            | Patrick | Justin |
|-------------------|---------|--------|
| GitHub Org        | Owner   | Owner  |
| Apps Repo (push)  | ✅      | ✅     |
| Plugin Repo       | ✅      | ✅     |
| ClickUp (alle Spaces) | Admin | Admin |
| Vercel (alle Projects)| Admin | Admin |
| Supabase (alle)   | Admin   | Admin  |
| Slack Workspace   | Admin   | Admin  |
| Pushover          | Owner   | Owner  |
| WhatsApp Bot      | -       | -      |

Beide haben volle Rechte überall. Keine Hierarchie.

## Was Claude darf vs nicht darf

**Layer 1 (autonom):**
- Code, Tests, Migrations schreiben (nicht ausführen gegen Prod)
- Library installieren
- Stage-Deploys (push auf main)
- ClickUp/Slack-Posts
- Decision-Blocks

**Nicht autonom:**
- Production-Deploys (manuell via Tag, 5-Min Abort)
- Destructive SQL gegen Prod
- Plugin-Files editieren
- Cross-App-Imports
- Layer-3-Decisions ohne beide Co-Founder
