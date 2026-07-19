# Model-Routing

Seit v1.3.0 hat **jeder** Subagent im Plugin ein explizites `model:` im Frontmatter.

## Warum das nötig war

Ohne `model:` gilt `inherit` — der Subagent läuft auf dem Hauptmodell. Bis v1.2.4
hatte keiner der sechs Agents einen Pin. Bei Opus als Hauptmodell hieß das: jeder
Drift-Check des Reviewers (angestoßen alle 30 Minuten via `userprompt-reviewer-trigger.sh`)
und jede Websuche des Researchers lief auf Opus. Genau die zwei Agents, die am
häufigsten und am lese-lastigsten arbeiten, waren am teuersten.

Der Pin kostet zur Laufzeit nichts und verteilt sich über `claude plugin update`
automatisch auf alle Apps und alle Maschinen — die Agents liegen im Plugin, nicht
in den Apps.

## Die Tabelle

| Agent | Modell | Effort | Rationale |
|---|---|---|---|
| `solver` | `opus` | high | Layer-2-Eskalation nach 3+ Fails. Härtestes Denken im System — wird nie runtergestuft. |
| `deployer` | `opus` | high | Production-Deploys. Läuft selten und kurz, ein Downgrade spart kaum Tokens, riskiert aber viel. |
| `builder` | `sonnet` | high | Implementiert ein Ticket mit definierten Acceptance-Criteria. Hohes Effort gleicht die Denkarbeit aus. |
| `debugger` | `sonnet` | high | Repro, Isolation und Bisect sind mechanisch; die Root-Cause-Hypothese braucht Effort, nicht das größte Modell. |
| `researcher` | `sonnet` | medium | Lese-lastigster Agent. Viele Quellen sichten und zu einer Tradeoff-Tabelle kondensieren ist Zusammenfassung, nicht Erfindung. |
| `reviewer` | `haiku` | medium | Checklisten-Drift-Detection, läuft im 30-Min-Takt, Blast-Radius null (schreibt nur ein Finding-File). |
| `scout` | `haiku` | low | Read-only Such-Worker. Liest viel, gibt wenig zurück. |

## Das Prinzip dahinter

Runtergestuft wird, was **häufig** läuft, **viel liest** und **wenig kaputtmachen**
kann. Auf Opus bleibt, was **Urteilsvermögen** braucht oder einen **großen
Blast-Radius** hat.

Das ist bewusst nicht „alles billig". `solver` und `deployer` stehen fest auf Opus,
weil dort ein schlechteres Ergebnis teurer ist als die gesparten Tokens.

## Der `scout` — und wann er sich NICHT lohnt

`scout` ist der Worker für große mechanische Lese-Jobs: „finde alle Stellen die X
nutzen", „welche Files hängen an Y". Er hat kein Edit/Write, gibt `path:line` plus
maximal drei Zeilen Kontext pro Treffer zurück und interpretiert nichts.

**Ein Subagent hat Spawn-Overhead.** Eine kleine Grep-Aufgabe an `scout` zu geben
kostet mehr, als sie inline zu erledigen. Er lohnt sich erst, wenn viele Files
gelesen werden müssen, das Ergebnis aber eine kurze Liste ist. Die `description`
im Frontmatter sagt das explizit, damit der Hauptthread nicht reflexhaft delegiert.

## Advisor

Der Advisor ist eine zweite Meinung *innerhalb* eines Requests — kein Subagent.

Bei **Opus als Hauptmodell** ist ein Advisor auf `opus` redundant: Opus berät Opus.
Das kostet Tokens ohne Erkenntnisgewinn.

### Was v1.2.4 angerichtet hat

`session-start-advisor-default.sh` schrieb ungefragt `advisorModel: "opus"` in die
globale `~/.claude/settings.json` — auf jeder Maschine, auf der das Plugin
installiert war, ohne dass jemand danach gefragt hatte.

v1.3.0 dreht das um und räumt auf:

| | v1.2.4 | v1.3.0 |
|---|---|---|
| Variable fehlt | schreibt `opus` | schreibt nichts |
| `WORK_CONVENTION_ADVISOR_DEFAULT=sonnet` | schreibt `sonnet` | schreibt `sonnet` |
| Altlast in settings.json | bleibt liegen | wird einmalig entfernt |

### Die Migration

`session-start-advisor-cleanup.sh` entfernt `advisorModel` beim nächsten
Session-Start aus der globalen settings.json — mit Backup unter
`settings.json.pre-advisor-cleanup.bak` und einer sichtbaren Meldung.

Sie läuft **genau einmal pro Maschine**, gesichert über
`~/.claude/.work-convention-advisor-cleanup.done`. Das ist keine Vorsicht, sondern
Notwendigkeit: ohne Marker würde jeder Session-Start erneut löschen und damit ein
späteres, bewusstes `/advisor sonnet` jedes Mal wieder killen. Die Migration ist
ein Undo, keine Dauer-Durchsetzung.

Advisor danach wieder anschalten: `/advisor`. Die Migration kommt nicht zurück.

### Hart abschalten

```jsonc
// ~/.claude/settings.json — gewinnt gegen jedes gesetzte advisorModel
{ "env": { "CLAUDE_CODE_DISABLE_ADVISOR_TOOL": "1" } }
```

Nur nötig, wenn der Advisor auch nicht *versehentlich* wieder angehen soll.
**Nebenwirkung:** damit wird auch der `/advisor`-Command unverfügbar — du kannst
ihn dann nicht mehr eben zurückholen. Für den Normalfall reicht die Migration.

## Ändern

Modelle stehen im Frontmatter unter `plugins/work-convention/agents/*.md`:

```yaml
---
name: reviewer
description: ...
tools: Read, Bash, Grep, Glob
model: haiku
effort: medium
---
```

Gültige `model:`-Werte: `opus`, `sonnet`, `haiku`, `fable`, `inherit` oder eine
volle Model-ID. Gültige `effort:`-Werte: `low`, `medium`, `high`, `xhigh`, `max`.

Nach dem Ändern: committen, taggen, pushen, dann in jeder App
`claude plugin update work-convention@kornmueller-empire`.

Die Test-Suite (`hooks/tests/test-runner.sh`) failt, sobald ein Agent **ohne**
`model:` dazukommt — der Regress von v1.2.4 kann so nicht zurückkehren.
