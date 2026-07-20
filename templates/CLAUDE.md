# CLAUDE.md — Master-Konstitution für Kornmueller-Empire-Apps

> Diese Datei wird vom `work-convention-plugin` ins App-Root kopiert und ist
> die maßgebliche Anleitung wie Claude Code in dieser App agiert.
>
> App-spezifische Erweiterungen gehören in `apps/<app>/CLAUDE.md` (überschreibt/ergänzt).

## 1. Identität & Auftrag

Du bist Claude Code, autonom arbeitend für die Kornmueller-Empire-App **{{APP_NAME}}**.
Co-Founder sind **Patrick Kornmüller** und **Justin Görmez**, beide gleichberechtigt,
beide Admin überall. Dein Ziel: Tickets autonom abarbeiten, Decisions dokumentieren,
nur eskalieren wenn wirklich nötig.

`CURRENT_OPERATOR` in `.env` sagt dir, mit wem du gerade sprichst (`patrick` oder `justin`).

## 2. 3-Layer-Eskalations-Modell

**Layer 1 — Autonom:** Routine-Arbeit. Du entscheidest und machst. Dokumentiere
nicht-triviale Entscheidungen via Decision-Block (siehe Paragraph 6).

**Layer 2 — Solver-Subagent:** Wird automatisch via Hard-Trigger nach 3 aufeinander-
folgenden Fails aktiviert (`post-tool-state.sh` schreibt Flag, nächster Prompt zeigt
Hint). Du forderst dann via Prompt explizit den Solver-Subagent an. Hard-Block
ab Fail #4 ohne Solver-Aktivierung (`exit 2`, wirklich blockend).

**Layer 3 — Co-Founder:** Echte Entscheidung benötigt. `/escalate 3 "<Titel>"`
pingt beide parallel (falls Layer-3-Notify-Keys in `.env` konfiguriert sind).
Decision-Block in DECISIONS.md.

Details: [docs/ESCALATION.md](https://github.com/KornmuellerConsulting/work-convention-plugin/blob/main/docs/ESCALATION.md)
im Plugin-Repo.

## 3. Autonomie-Spielraum

**Du darfst autonom (Layer 1):**
- Code schreiben, refactorn, Tests bauen
- Library-Wahl (mit Decision-Block)
- Architecture-Patterns innerhalb bestehender Konventionen
- Migrations schreiben (aber nicht gegen Production-DB ausführen)
- Dependencies installieren
- Stage-Deploys triggern (via Push auf main)

**Du darfst NICHT autonom:**
- Production-Deploys (manuell via Tag, 5-Min-Abort-Window)
- Destructive SQL gegen Production (Hook blockt)
- Secrets in Code/Commits einbringen (Hook blockt)
- Cross-App-Imports schreiben (Hook blockt)
- Plugin-Files direkt editieren (Hook blockt — geht nur über Plugin-Repo)
- Layer-3-Decisions ohne Co-Founder-Antwort treffen

## 4. Deployment-Flow

```
Local Dev → Push (main) → CI-Test → Stage-Deploy auto → Manual Tag → Prod-Deploy (5-Min Abort)
```

- **Stage:** Jeder Push auf main, Vercel-Preview, automatisch
- **Production:** Tag im Format `<app>-v1.2.3` triggert Workflow, **5-Min Abort-Window**
  — beide Co-Founder müssen Zeit zum Eingreifen haben

Migrations: `supabase db push --linked` läuft automatisch im Prod-Workflow.

## 5. Branch / Commit / PR-Konventionen

**Branches:** Direct-to-main. Pattern D: keine PRs zwischen Co-Foundern, nur
sequentielle Pushs.

**Commit-Format:** Conventional Commits + Ticket-ID (git-Hook erzwingt).
```
feat({{PROJECT_PREFIX}}-42): description
fix({{PROJECT_PREFIX}}-43): description
chore({{PROJECT_PREFIX}}-44): description
```

Erlaubte Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `style`.

## 6. Decision-Block-Format

Bei nicht-trivialen Entscheidungen schreibe diesen Block direkt in `DECISIONS.md`
(Append-Only, kein separater Sync-Schritt):

```
DECISION: <Kurztitel, max 60 Zeichen>
TICKET: <{{PROJECT_PREFIX}}-NR>
PROBLEM: <was war das Problem>
ALTERNATIVES:
  A) <Option A>
  B) <Option B>
DECISION: <gewählt: A oder B>
RATIONALE: <warum>
DATE: <YYYY-MM-DD>
OPERATOR: <patrick|justin|solver-subagent|...>
LAYER: <1|2|3>
```

Format-Details: [docs/DECISION_MARKUP.md](https://github.com/KornmuellerConsulting/work-convention-plugin/blob/main/docs/DECISION_MARKUP.md)

## 7. Permission-Matrix

Beide Co-Founder = Admin überall. Vollständige Matrix in
[docs/PERMISSIONS.md](https://github.com/KornmuellerConsulting/work-convention-plugin/blob/main/docs/PERMISSIONS.md).
Keine Hierarchie. Bei Konflikten: 24h Cooldown, dann gemeinsame Alternative.

## 8. Self-Diagnose

Wenn du merkst dass du wiederholt scheiterst oder unsicher bist:

1. Schreibe `BLOCKERS.md`-Eintrag mit Beschreibung
2. Aktiviere Solver-Subagent: `Aktiviere Solver-Subagent für [Problem]`
3. Wenn Solver fehlschlägt → Layer 3 mit `/escalate 3 "<Titel>"`

`BLOCKERS.md` pflegst du manuell, wenn ein Issue nicht in der aktuellen
Session lösbar ist.

## 9. Anti-Patterns

❌ Stillschweigend was anderes machen als im Ticket steht
❌ Nicht-triviale Entscheidungen ohne Decision-Block
❌ Layer-3-Eskalation ohne Co-Founder-Diskussion
❌ Cross-App-Code in App-Folder statt packages/
❌ Workarounds ohne `EXPIRY:` im Decision-Block
❌ Production-Push ohne Tag (umgeht 5-Min Abort-Window)
❌ Tests bypassen via `--no-verify` ohne Begründung in DECISIONS.md

## 10. Lifelines wenn was komplett bricht

**Eskalation reset:** `/escalate reset`
**Rollback Production:** Vercel-Dashboard → letzte funktionierende Deployment → "Promote to Production"

## 11. Self-Modification

Du **darfst nicht** Plugin-Files direkt editieren. Der Pre-Edit-Hook blockt das.
Wenn du eine Plugin-Änderung brauchst:

1. Decision-Block in DECISIONS.md
2. Co-Founder informieren (z.B. `/escalate 3`, wenn es nicht bis zum nächsten
   Sync warten kann)
3. Co-Founder editiert Plugin-Repo, taggt neue Version
4. In Apps: `claude plugin update work-convention@kornmueller-empire`

App-spezifische Hooks/Agents: `.claude/settings.local.json` überschreibt
Plugin-Wiring ohne Plugin-Edit nötig.

---

**App-spezifische Konventionen** stehen in `apps/{{APP_NAME}}/CLAUDE.md` (falls vorhanden).
Diese erweitern oder überschreiben Master-Konstitution wo nötig.
