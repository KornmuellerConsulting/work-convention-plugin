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

## Verifizieren

Die Test-Suite prüft nur, dass `model:` **dasteht**. Ob Claude Code den Pin auch
*anwendet*, ist eine andere Frage — und `/agents` beantwortet sie nicht mehr, der
Wizard wurde entfernt (bestätigt in Claude Code 2.1.210).

Der Weg, der funktioniert: das Plugin per `--plugin-dir` aus dem lokalen Repo
laden, mit `--agent` einen bestimmten Subagent als Session-Agent fahren, und im
Debug-Log nachsehen, welches Modell die Requests tatsächlich benutzt haben. Das
geht **vor** Merge und Tag, ohne irgendwas zu installieren.

```bash
PLUGIN=~/Documents/Kornmueller/work-convention-plugin/plugins/work-convention
WORK=$(mktemp -d) && cd "$WORK"

for pair in scout:haiku reviewer:haiku builder:sonnet \
            researcher:sonnet debugger:sonnet solver:opus deployer:opus; do
  a="${pair%%:*}"; want="${pair##*:}"
  claude --plugin-dir "$PLUGIN" --agent "$a" --debug-file "/tmp/m-$a.log" \
    -p "Antworte nur: OK" < /dev/null >/dev/null 2>&1
  got=$(grep -oE 'model=claude-[a-z0-9.-]+' "/tmp/m-$a.log" | head -1 | sed 's/model=//')
  printf "%-12s %-8s %s\n" "$a" "$want" "${got:-NICHT GEFUNDEN}"
done
```

Referenz-Ausgabe (gemessen bei v1.3.0):

```
scout        haiku    claude-haiku-4-5-20251001
reviewer     haiku    claude-haiku-4-5-20251001
builder      sonnet   claude-sonnet-5
researcher   sonnet   claude-sonnet-5
solver       opus     claude-opus-4-8
deployer     opus     claude-opus-4-8
```

Der Test ist bewusst **differenziell**: mehrere Agents mit unterschiedlichen Pins
in einem Durchlauf. Landen alle auf demselben Modell, werden die Pins ignoriert —
ein einzelner Agent allein beweist nichts, weil man den gemessenen Wert nicht vom
Default unterscheiden kann.

Im selben Log stehen zwei weitere Antworten:

```bash
grep -iE "registered.*hook|loaded .* agents" /tmp/m-scout.log
# Registered 26 hooks from 1 plugins
# Loaded 7 agents from plugin work-convention default directory
```

Das ist zugleich der Hook-Loader-Check aus der CLAUDE.md. Steht dort `0`, ist ein
invalides Event in der `hooks.json` — dann ist das gesamte Hook-System tot, nicht
nur der eine Hook.

> **Achtung, echte Nebenwirkungen.** Das ist eine vollwertige Claude-Code-Session:
> die SessionStart-Hooks des Plugins feuern gegen deine **echte** globale
> `~/.claude/settings.json`. Genau so hat der Advisor-Cleanup bei der v1.3.0-
> Verifikation seine einmalige Migration ausgelöst. Vorher sichern:
>
> ```bash
> cp ~/.claude/settings.json /tmp/settings.PRE-TEST
> ```
>
> Und `cd` in ein Wegwerf-Verzeichnis, nicht in eine App — sonst schreiben die
> Hooks in deren `.claude/state/`.

> **Schlimmer noch: das Rezept kann eine Einmal-Migration verbrennen.**
>
> Genau das ist bei der v1.3.0-Verifikation passiert. Ablauf:
>
> 1. Das Rezept lädt die **neue** Version per `--plugin-dir`. Deren
>    `session-start-advisor-cleanup.sh` läuft, entfernt `advisorModel` und setzt
>    seinen Marker.
> 2. Installiert ist aber noch die **alte** Version. Deren Setter schreibt
>    `advisorModel` beim nächsten Session-Start ungefragt wieder rein.
> 3. Nach dem echten `claude plugin update` sieht die Migration ihren Marker,
>    überspringt sich — und die Altlast bleibt für immer liegen.
>
> Die Migration hat also stattgefunden, ohne etwas zu bewirken. Und weil sie sich
> selbst als erledigt markiert hat, holt sie es nie nach. Symptom: nach dem
> Update ist alles „grün", aber der Wert steht noch da.
>
> **Gegenmittel:** vor dem echten Update den Marker löschen, den der Testlauf
> gesetzt hat.
>
> ```bash
> rm -f ~/.claude/.work-convention-advisor-cleanup.done
> ```
>
> **Als Regel:** Wer per `--plugin-dir` eine Version testet, die Einmal-
> Migrationen mitbringt, muss deren Marker danach aufräumen. Sonst laufen sie
> im Testlauf leer und nie wieder. Beim Bauen künftiger Migrationen mitdenken —
> das Marker-Pattern ist richtig, aber es verträgt sich schlecht mit einem
> Vorab-Test gegen eine ältere Installation.
