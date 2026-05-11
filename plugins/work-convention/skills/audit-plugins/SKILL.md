# Plugin-Audit Skill

Dieses Skill ruft `plugin-audit.py` mit dem passenden Mode auf, abhängig vom Trigger.

## Wann nutzen

- Beim ersten App-Bootstrap → `--mode bootstrap`
- Alle 30 Tage → `--mode periodic`
- Wenn User "audit plugins for X" sagt → `--mode targeted --stack X`
- Wenn User "update curated list" sagt → `--mode update-curated`

## Beispiele

```bash
# Bootstrap-Audit beim ersten App-Setup
python3 .claude/scripts/plugin-audit.py --mode bootstrap

# Monatliches Audit (skipt automatisch wenn < 30 Tage her)
python3 .claude/scripts/plugin-audit.py --mode periodic

# Spezifische Recherche
python3 .claude/scripts/plugin-audit.py --mode targeted --stack "supabase"
```

## Output-Verarbeitung

Plugin-Empfehlungen sind nur Vorschläge. **Niemals automatisch installieren.**
User muss bewusst `claude plugin install <name>` aufrufen.

Bei Empfehlungen außerhalb der Curated-List zeigt das Script einen
GitHub-Search-Link statt einer Direkt-Empfehlung.
