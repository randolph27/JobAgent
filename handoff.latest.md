# Handoff latest

Stand: 2026-08-26T07:03:27.172+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-025` Arbeitgeberkandidatenbasis weiter skalieren.
- Branch: `master`
- HEAD: `f3c45dc2be83`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.snapshot.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `tests/Test-JobAgentJobBoardDiscovery.ps1`
- `tests/fixtures/jobagent/jobboard-discovery/stepstone-freising-snapshot.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Arbeitsstand fuer neuen Chat

Weitergearbeitet wurde an `JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen`.

Konkretes Ergebnis:

- `source-registry:stepstone_freising` ist in `data/jobagent/company-discovery.snapshot.json` als lokale Jobboersen-Snapshot-Quelle eingetragen.
- Neue Fixture `tests/fixtures/jobagent/jobboard-discovery/stepstone-freising-snapshot.json` erzeugt zwei Freising-Arbeitgeber-Hints:
  - `Texas Instruments Deutschland GmbH`
  - `Fraunhofer IVV`
- Ein Out-of-scope-Treffer in der Fixture wird vom Importer verworfen.
- `tests/Test-JobAgentJobBoardDiscovery.ps1` prueft jetzt StepStone Freising als eigene Quelle, absolute StepStone-URLs, Freising-Zielgebiet, Hint-only-Vertrag, Pflicht zur offiziellen Verifikation und Out-of-scope-Filter.
- Die Snapshot-Lane wurde ausgefuehrt und hat `data/jobagent/company-discovery.hints.json` aktualisiert.
- Die Coverage-Lane wurde ausgefuehrt und hat `data/jobagent/company-candidate-verification.queue.json` sowie `html/jobagent/company-coverage.html` aktualisiert.

Aktuelle Messwerte:

- Snapshot-Lane: `5` Inputs, `7` Quellenlogs, `18` neue Hints, `24` gemergte Hints.
- StepStone Freising: `2` Hints aus `source-registry:stepstone_freising`.
- Produktive Store-Writes: `false`.
- Offizielle Website-/Karriereverifikation: weiter erforderlich.
- SonarQube-Port `9000`: erreichbar.

Roadmap-Status:

- `JA-025` bleibt offen. Es wurden weitere erlaubte Arbeitgeber-Hints operationalisiert, aber die geforderte breite Kandidatenbasis und alle erlaubten Quellen sind noch nicht vollstaendig abgearbeitet.
- `JA-027` bleibt offen und haengt fachlich weiter von `JA-025` ab.
- Keine Roadmap-Rotation ausgefuehrt, weil kein Roadmap-Punkt komplett abgeschlossen ist.

Naechster sinnvoller Schritt:

1. Weitere erlaubte Quellen aus `data/jobagent/company-discovery.sources.json` operationalisieren, bevorzugt noch fehlende erlaubte Jobboersen-/Regional-/Register-Snapshots.
2. Danach erneut `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`.
3. Danach `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`.
4. Fokussierte Funktionstests erneut ausfuehren: Register, JobBoard, Regional, DedupeScale, Coverage.
5. Erst wenn `JA-025` fachlich komplett erledigt ist, Roadmap-Rotation pruefen und danach `JA-027` fortsetzen.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- Supertest: nicht erneut angefragt; gemaess Nutzeranweisung als erledigt gewertet.

## Naechster Anker

Aktive Punkte: JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen #comment: Alle erlaubten Quellen sollen Arbeitgebernamen liefern, nicht Stellenanzeigen; produktiv hinzugefuegt wird erst nach offizieller Karriere-/Jobs-Webseitenverifikation.
