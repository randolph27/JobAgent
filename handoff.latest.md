# Handoff latest

Stand: 2026-09-15T20:34:42.698+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: 
- Branch: `master`
- HEAD: `963e2416c54a`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentFetchEnvironment.ps1`
- `tests/Test-JobAgentFetchErrorInspection.ps1`
- `tests/Test-JobAgentLiveScan.ps1`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Inspect-JobAgentFetchErrors.ps1`
- `tools/Test-JobAgentFetchEnvironment.ps1`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-003.3 gemaess Roadmap.md; regulaeren Start, Resume und Betrieb ausschliesslich mit isolierten CLI-/Fixturelaeufen pruefen.

## Detailhandoff fuer den Folgechat

### Abgeschlossener Teilschnitt

- QA-003.1 und QA-003.2 sind abgeschlossen. QA-003 bleibt offen, weil QA-003.3 den regulaeren CLI-Start, Resume und Betrieb noch pruefen muss. Deshalb keine Roadmap-Rotation.
- `JobAgent.LiveScan.psm1` dedupliziert Paginierungs-URLs, Kandidaten-URLs und externe Stellen-IDs innerhalb eines Scans. Erreichte Ergebnislimits bleiben `PARTIAL`; nicht budgetierte Detailseiten werden nicht abgerufen.
- Defektes JSON wird als `PARSING_ERROR` statt als vollstaendiger Leerbestand behandelt. 404, TLS- und Redirectschleifen sind terminal; 503, Timeout und DNS duerfen das Retrybudget nutzen. Ein positives `Retry-After` verhindert den sofortigen Wiederholungsabruf.
- `FetchEnvironment` und `FetchErrorInspection` redigieren Authorization-/Tokenwerte. Fehlende Probe-Fixtures liefern einen Fehlerexit; defekte oder fehlende Inspection-Logs ergeben einen leeren, eindeutigen Diagnosezustand.
- Dauerhafter Nachweis: `docs/reviews/QA-003.2-adapter-error-handling.md`.

### Verifizierte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchEnvironment.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchErrorInspection.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` — Exit 0

Kein Supertest erforderlich: Der Nutzer hat festgelegt, dass ein nicht angefragter Supertest als erledigt gilt.

### Naechster Arbeitsschnitt: QA-003.3

1. Vorhandene CLI-Parameter und `tools/*JobAgent*.ps1` read-only inventarisieren; dann `docs/reviews/QA-003-cli-cases.md` mit jedem produktiven Einstieg und dem exakten Fixtureaufruf anlegen.
2. Zwei isolierte Projektroots im FixtureMode ausfuehren. Akquise und Scan muessen dieselbe Lauf-ID teilen; der zweite Lauf darf keine Duplikate erzeugen. Checkpoint-, Store- und Reporthashes sowie die Soll-ID-Liste vergleichen.
3. Fehler vor/nach Kandidatencheckpoint sowie vor Store-/Reportpublikation injizieren. Resume darf genau einmal committen und muss den letzten gueltigen Bericht bis zum atomaren Austausch erhalten.
4. Danach gezielt `Test-JobAgentImportWaves.ps1`, `Test-JobAgentDailyRun.ps1` und `Test-JobAgentOperations.ps1` ausfuehren. Erst bei Abschluss von QA-003.3 QA-003 als Ganzes bewerten und Roadmap-Rotation pruefen.
