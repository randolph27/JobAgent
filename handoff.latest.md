# Handoff latest

Stand: 2026-09-15T20:35:26.921+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: 
- Branch: `master`
- HEAD: `0b3b2779dd35`
- Upstream: `origin/master`
- Ahead/Behind: `1/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-003.3 gemaess Roadmap.md; regulaeren Start, Resume und Betrieb ausschliesslich mit isolierten CLI-/Fixturelaeufen pruefen.

## Detailhandoff fuer den Folgechat

### Status

- Commit `0b3b277` enthaelt den abgeschlossenen Teilschnitt QA-003.2. QA-003.1 und QA-003.2 sind abgehakt; QA-003.3 ist noch offen. Roadmap-Rotation ist daher nicht zulaessig.
- Der Live-Adapter dedupliziert Seiten, URLs und externe Stellen-IDs, meldet Limitlaeufe `PARTIAL` und klassifiziert defektes strukturiertes JSON als `PARSING_ERROR`.
- Kontrollierte Transporttests sichern 200/404/429/503, Timeout, DNS, TLS, Redirectschleife und `Retry-After` mit Requestanzahl, Reihenfolge und Fehlerklasse ab. `Retry-After` blockiert den sofortigen Wiederholungsabruf.
- Fetch-Environment und Fetch-Error-Inspection redigieren Authorization-/Tokenwerte und behandeln fehlende Probe-Fixtures sowie defekte Inspection-Logs fail-closed bzw. eindeutig diagnostisch.
- Permanenter Nachweis: `docs/reviews/QA-003.2-adapter-error-handling.md`.

### Verifizierte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchEnvironment.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchErrorInspection.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` — Exit 0

Kein Supertest ausgefuehrt; nach Nutzerregel gilt ein nicht angefragter Supertest als erledigt.

### Naechster Arbeitsschnitt: QA-003.3

1. CLI-Parameter und `tools/*JobAgent*.ps1` inventarisieren; `docs/reviews/QA-003-cli-cases.md` mit jedem produktiven Einstieg und dem exakten Fixtureaufruf anlegen.
2. Zwei isolierte Projektroots im FixtureMode starten. Akquise und Scan muessen dieselbe Lauf-ID teilen; der zweite Lauf darf keine Duplikate erzeugen. Soll-ID-Liste sowie Checkpoint-, Store- und Reporthashes vergleichen.
3. Fehler vor/nach Kandidatencheckpoint und vor Store-/Reportpublikation injizieren. Resume darf genau einmal committen und muss den letzten gueltigen Bericht bis zum atomaren Austausch beibehalten.
4. Abschliessend gezielt `Test-JobAgentImportWaves.ps1`, `Test-JobAgentDailyRun.ps1` und `Test-JobAgentOperations.ps1` ausfuehren. Erst danach QA-003 und eine Rotation bewerten.
