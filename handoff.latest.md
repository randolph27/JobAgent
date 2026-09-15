# Handoff latest

Stand: 2026-09-15T18:44:32.432+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: _(keines)_
- Branch: `master`
- HEAD: `82eb49afb998`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-001 Funktionsinventar und verbindliche Testfallmatrix vervollstaendigen #comment: Jede spaetere Vollstaendigkeitsaussage muss gegen ein reproduzierbares Inventar statt gegen eine manuell gepflegte Testliste geprueft werden.

## Fortsetzung im neuen Chat

### Verbindlicher Arbeitsstand

- Der Planungsschnitt ist abgeschlossen. Es wurde keine Produkt-, Test- oder Roadmap-Implementierung fuer QA-001 bis QA-006 begonnen.
- Alle sechs QA-Punkte stehen offen und bleiben deshalb in `Roadmap.md`; es gab keinen vollstaendig erledigten aktiven Roadmap-Punkt und folglich keine Roadmap-Rotation.
- `Active` bleibt leer. Der neue Chat beginnt seriell mit `TD-0058` / `QA-001.1`; `TD-0059` bis `TD-0063` folgen in der dokumentierten Abhaengigkeitsreihenfolge.
- Der aktuelle bekannte CI-Befund ist `TD-0056`: `immutable_modified: manual\PROGRAM.md`. Er ist unveraendert, nicht mit Pins zu verdecken und ausserhalb des QA-Planungsschnitts separat zu behandeln.
- Der aktuelle verifizierte Funktionstest ist `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` mit Exit 0. Sonar ist in `.ci/ci.config.json` bewusst `not-supported`; ein laufender Server auf Port 9000 ist keine Sonar-Analyse.
- Fuer diesen Handoff war kein Supertest angefragt und er wurde nicht ausgefuehrt. Er gilt damit fuer diesen Handoff als erledigt/nicht geschuldet. Die in den einzelnen QA-Punkten festgelegten Abschluss-Supertests bleiben erst nach deren jeweiligem fachlichen Abschluss faellig.

### Priorisierte Arbeitsfolge

1. `QA-001` / `TD-0058` — Testvollstaendigkeit als pruefbare Grundlage herstellen.
   - PowerShell-AST sowie HTML-/JavaScript-Controls inventarisieren und ein kanonisches, gehashtes Inventar unter `docs/reviews/QA-001-function-inventory.json` erzeugen.
   - `docs/test-matrix.json` und `docs/test-matrix.md` um stabile Fall-IDs, Funktionsbezug, Fixtures, Sollwerte, Lanes, Abhaengigkeiten und Status erweitern; Uhr, Locale, Seeds, IDs und Toolversionen deterministisch festlegen.
   - `tests/Test-JobAgentTestMatrix.ps1` gegen isolierte defekte Matrixfixtures erweitern: fehlende Funktion/Datei, doppelte Fall-ID, unbekannte Lane, produktiver Pfad, Liveaufruf, Zyklus und Aggregator-Selbstaufnahme muessen gezielt fehlschlagen.
   - Abschluss nur nach gruenem `Test-JobAgentTestMatrix.ps1` und `Test-JobAgentCiContracts.ps1`; verbleibende Luecken mit Besitzer QA-002 bis QA-006 in `docs/reviews/QA-001-gap-register.md` festhalten.

2. `QA-002` / `TD-0059` — Daten-, Identitaets-, Status- und Berichtsvertraege absichern; abhaengig von QA-001.
   - Schema, atomare Persistenz, Backups, Locks, Fremdpfade und Traversal mit isolierten Fehlerpunkten pruefen.
   - Identitaetsprioritaet, regionale Grenzen, Statusfolgen (`NEW -> ACTIVE -> UPDATED -> CLOSED`, `REMOVED`, Wiederauftauchen) und PARTIAL-/Fehlerquellen als feste Sequenzen testen.
   - JSON-, Markdown-, Daily-HTML- und Coverage-Berichte gegen explizite IDs, Mengen, Escaping, Links und deterministische Wiederholung pruefen.

3. `QA-003` / `TD-0060` — Discovery, Quellenverifikation, Wiederanlauf und CLI-Betrieb; abhaengig von QA-001 sowie den Datenorakeln aus QA-002.
   - Discovery-/Verifikationsfixtures fuer leere, doppelte, veraltete, ungueltige und widerspruechliche Kandidaten vervollstaendigen.
   - Adapter-, Transport- und Retry-Faelle nur per kontrollierten Responses pruefen; keine Live-Firmenwellen oder externen Kontakte.
   - Daily-/Operations-CLI mit Resume, Checkpoint, atomarer Publikation, Abbruch und deterministischer Worker-Reihenfolge abnehmen.

4. `QA-004` / `TD-0061` — jede sichtbare UI-Aktion mit exakter Zustands- und Ergebnisassertion pruefen; nach stabilen Daten- und Discoveryvertraegen.
   - Firmen, Stellen, Tabs, Filter, Suche, Pagination, Reset und Ausgabelinks gegen feste Fixture-Sollwerte abdecken.
   - Browser-Evidence pro Fall mit URL, Requestliste, IDs, Vor-/Nachzustand und Datenhash unter `logs/jobagent/QA-004/` erzeugen.
   - Fehler zuerst im konkreten Browserfall reproduzieren; kein pauschaler Supertest zur Lokalisierung.

5. `QA-005` / `TD-0062` — Geometrie, Lesbarkeit und Tastaturbedienung abnehmen; abhaengig von QA-004.
   - Fixe Browserbedingungen fuer 390x844, 800x1024, 1366x768 und 1920x1080 sowie Pflichtzustaende festlegen und Boundingboxes, Overflow und Mindestgroessen messen.
   - Fokusreise, semantische Namen/Rollen, Kontrast und sichtbaren Fokus ohne Tastaturfalle pruefen.
   - Negative Rendererfixtures fuer Clipping, Overlap, zu kleine Controls und unsichtbaren Fokus nachweisen; Screenshots erst nach Sichtung und Assertion versionieren.

6. `QA-006` / `TD-0063` — den Aggregator erst nach QA-001 bis QA-005 erweitern und seine Fehlerbehandlung pruefen.
   - Testauswahl zentral aus der Matrix ableiten, topologisch validieren und Selbstaufnahme, Luecken, Zyklen und doppelte Ausfuehrung sperren.
   - Isolierte Child-Skripte fuer Erfolg, Fehlerexit, Exception, ungueltige Resultate, Timeout und Abbruch verwenden; Gesamtbericht atomar auch bei Teilfehlern schreiben.
   - Erst dann zwei begruendete vollstaendige `./ci.cmd supertest`-Laeufe mit Vergleich normalisierter Evidence ausfuehren.

### Ausfuehrungsregeln fuer die Fortsetzung

- Zuerst die vier Steuerdateien `Roadmap.md`, `Roadmap_archive.md`, `Roadmap_index.md` und den aktuellen Todo-/Handoff-Zustand lesen; aktive Roadmap-Punkte niemals vor belegtem Abschluss rotieren.
- Ausschliesslich fokussierte Funktionstests waehrend der Umsetzung. Der jeweilige Supertest ist erst am in seinem Roadmap-Punkt genannten Abschlusszeitpunkt zulaess; bei Fehlschlag zuerst den konkreten Einzeltest reparieren.
- Devserver ausschliesslich ueber `./ci.cmd devserver-status` und `./ci.cmd devserver-start` auf Port 8500 verwalten; keine fremden Listener beenden.
- Jede abgeschlossene Einheit mit Evidence, Todo, Checkpoint und `./ci.cmd stp` synchronisieren. Vor Commit Diff, `git diff --check` und die betroffenen Funktionstests pruefen.
