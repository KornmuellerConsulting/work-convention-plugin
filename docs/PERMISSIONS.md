# Permission-Matrix — Kornmueller-Empire

| System            | Patrick | Justin |
|-------------------|---------|--------|
| GitHub Org        | Owner   | Owner  |
| Apps Repo (push)  | ✅      | ✅     |
| Plugin Repo       | ✅      | ✅     |
| Vercel (alle Projects)| Admin | Admin |
| Supabase (alle)   | Admin   | Admin  |
| Slack Workspace (optional, Layer-3-Notify) | Admin | Admin |
| Pushover (optional, Layer-3-Notify) | Owner | Owner |
| WhatsApp Bot (optional, Layer-3-Notify) | - | - |

Beide haben volle Rechte überall. Keine Hierarchie.

## Was Claude darf vs nicht darf

**Layer 1 (autonom):**
- Code, Tests, Migrations schreiben (nicht ausführen gegen Prod)
- Library installieren
- Stage-Deploys (push auf main)
- Decision-Blocks in DECISIONS.md

**Nicht autonom:**
- Production-Deploys (manuell via Tag, 5-Min Abort)
- Destructive SQL gegen Prod (Hook blockt, siehe `pre-bash-guards.sh`)
- Plugin-Files editieren (Hook blockt, siehe `pre-edit-guards.sh`)
- Cross-App-Imports (Hook blockt)
- Layer-3-Decisions ohne beide Co-Founder
