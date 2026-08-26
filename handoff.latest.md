# Handoff latest

Stand: 2026-08-26T06:53:05.553+02:00

## Zustand

- Projekt: `JobAgent`
- Active: ``
- Status: `open`
- Branch: `master`
- HEAD vor Abschluss-Commit: `1e1efade66e7`
- Upstream: `origin/master`
- Ahead/Behind vor Abschluss-Commit: `0/0`
- Route: `True`
- STP: `.\ci.cmd stp` erfolgreich ausgefuehrt.
- Roadmap-Rotation: keine Rotation; `JA-025` und `JA-027` sind fachlich nicht komplett erledigt.

## Aktueller Arbeitsschnitt

Fortgesetzt wurde `JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen`.

Konkretes Ergebnis dieses Schnitts:

- BA-Jobsuche ist als lokale Snapshot-Quelle in `data/jobagent/company-discovery.snapshot.json` aufgenommen.
- Neue Fixture `tests/fixtures/jobagent/jobboard-discovery/ba-jobsuche-muenchen-snapshot.json` erzeugt zwei Zielgebiets-Arbeitgeberhints und einen Out-of-scope-Treffer.
- `tests/Test-JobAgentJobBoardDiscovery.ps1` prueft jetzt BA-Snapshot-Import, absolute Arbeitsagentur-URLs, Hint-only-Vertrag, keine Fremd-Jobboersen-URL und bekannte Firmenzuordnung.
- Snapshot-Lane wurde ausgefuehrt und hat `data/jobagent/company-discovery.hints.json` aktualisiert.
- Coverage-Lane wurde ausgefuehrt und hat `data/jobagent/company-candidate-verification.queue.json` sowie `html/jobagent/company-coverage.html` aktualisiert.

## Aktuelle Messwerte

- Snapshot-Lane: `4` Inputs, `6` Quellenlogs, `16` neue Hints, `22` gemergte Hints.
- BA-Jobsuche: `2` Hints aus `source-registry:ba_jobsuche`, `productive_store_write=false`, `official_verification_required=true`.
- Coverage: `38` produktive Firmen, `58` Zielgebiet-Kandidaten, `942` Luecke bis `1000`, Zielinventar-Gate `failed`.
- Importwellen: `4`; Welle A `12`, B `4`, C `1`, D `12` Kandidaten.

## Geaenderte Dateien

- `data/jobagent/company-discovery.snapshot.json`
- `tests/fixtures/jobagent/jobboard-discovery/ba-jobsuche-muenchen-snapshot.json`
- `tests/Test-JobAgentJobBoardDiscovery.ps1`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.json`
- `handoff.latest.md`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Hinweis: `.\ci.cmd self-check` war vor diesem Schnitt rot wegen bestehendem `immutable_modified: Roadmap.md`.

## Naechster Anker

Weiter mit `JA-025`: fehlende erlaubte Quellen operationalisieren und die Kandidatenbasis weiter skalieren. Naechster sinnvoller Schritt ist ein weiterer lokaler Snapshot-Importer bzw. Snapshot-Fixture fuer noch nicht abgedeckte erlaubte Quellen, danach erneut `Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`, `Measure-JobAgentCompanyCoverage.ps1` und die fokussierten Funktionstests.
