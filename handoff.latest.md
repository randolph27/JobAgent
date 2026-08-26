# Handoff latest

Stand: 2026-08-26T07:09:10.141+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-025` Arbeitgeberkandidatenbasis aus erlaubten Discovery-Quellen weiter skalieren.
- Branch: `master`
- HEAD vor Commit: `cfc575c53732`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `True`

## Arbeitsstand fuer neuen Chat

Weitergearbeitet wurde an `JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen`.

Konkretes Ergebnis:

- BA-Jobsuche Freising wurde als weitere lokale Arbeitgeber-Hint-Quelle operationalisiert.
- Neue Fixture `tests/fixtures/jobagent/jobboard-discovery/ba-jobsuche-freising-snapshot.json` erzeugt zwei Freising-Arbeitgeber-Hints:
  - `Texas Instruments Deutschland GmbH`
  - `Fraunhofer IVV`
- Ein Out-of-scope-Treffer `Outside BA Freising Search AG` wird vom Importer verworfen.
- `data/jobagent/company-discovery.snapshot.json` enthaelt jetzt `6` Snapshot-Inputs.
- Snapshot-Lane erzeugte `8` Quellenlogs, `20` neue Hints und `26` gemergte Hints.
- `data/jobagent/company-candidate-verification.queue.json` enthaelt aktuell `10` Queue-Eintraege.
- Produktive Store-Writes: `false`.
- Offizielle Website-/Karriere-/ATS-Verifikation: weiter erforderlich.

## Geaenderte Dateien

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.snapshot.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `tests/Test-JobAgentJobBoardDiscovery.ps1`
- `tests/fixtures/jobagent/jobboard-discovery/ba-jobsuche-freising-snapshot.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- Supertest: nicht erneut ausgefuehrt; gemaess Nutzeranweisung als erledigt gewertet.

## Roadmap-Status

- `JA-025` bleibt offen. Es wurde eine weitere erlaubte Arbeitgeber-Hint-Quelle operationalisiert, aber die geforderte breite Kandidatenbasis aus allen erlaubten Quellen ist noch nicht vollstaendig erreicht.
- `JA-027` bleibt offen und haengt fachlich weiter von `JA-025` ab.
- Keine Roadmap-Rotation ausgefuehrt, weil kein Roadmap-Punkt komplett abgeschlossen ist.

## Naechster sinnvoller Schritt

1. Fehlende erlaubte Quellen aus `data/jobagent/company-discovery.sources.json` weiter operationalisieren, bevorzugt weitere Regional-/Register-Snapshots oder erlaubte BA-/Jobboersen-Suchmatrizen.
2. Danach erneut ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`.
3. Danach Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`.
4. Fokussierte Funktionstests erneut ausfuehren: Register, JobBoard, Regional, DedupeScale, Coverage.
5. Erst wenn `JA-025` fachlich komplett erledigt ist: Roadmap-Rotation pruefen, dann `JA-027` fortsetzen.

## Naechster Anker

Aktive Punkte: JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen #comment: Alle erlaubten Quellen sollen Arbeitgebernamen liefern, nicht Stellenanzeigen; produktiv hinzugefuegt wird erst nach offizieller Karriere-/Jobs-Webseitenverifikation.
