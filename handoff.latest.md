# Handoff latest

Stand: 2026-08-17T13:05:09+02:00

## Zustand

- Active: _(none)_
- Status: `open`
- Ziel: Naechster Arbeitsschritt ist `TD-0001 / JA-003 Speicher- und Migrationsschicht fuer idempotente Daily-Runs implementieren`.
- Branch: `master`
- HEAD vor Commit: `845bec02dd90`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `JA-001` und `JA-002` sind abgeschlossen und archiviert; aktive Roadmap startet bei `JA-003`.

## Abgeschlossener Arbeitsschritt

- `JA-002 Persistentes Datenmodell fuer Firmen, Stellen, Scanlaeufe und Aenderungen definieren` ist abgeschlossen.
- `schemas/jobagent.schema.json` definiert den Domainvertrag `jobagent/v1` fuer:
  - `Company`
  - `Job`
  - `JobSource`
  - `ScanRun`
  - `ScanAttempt`
  - `JobSnapshot`
  - `ChangeEvent`
- Das Schema enthaelt stabile ID-Regeln, Pflichtfelder, Zeitstempel, offizielle Quellbelege, Jobstatus, Scanstatus, Fehlerklassen, Klassifikation und A/B/C-Prioritaet.
- `docs/data-model.md` dokumentiert Speicherentscheidung, Root-Dokument, Pflichtfelder, Identitaetsprioritaet, Beispielbestand und Negativregeln.
- `tests/Test-JobAgentSchema.ps1` prueft das Schema und die fachlichen Mindestinvarianten.
- Fixtures wurden angelegt unter `tests/fixtures/jobagent/`.
- `Roadmap.md` wurde bereinigt: `JA-002` wurde nach `Roadmap_archive.md` rotiert.
- `Roadmap_index.md` zeigt jetzt aktive Punkte ab `JA-003`.
- `todo-seed` hat die naechsten acht offenen Roadmap-Punkte in `todo.state.json` und `todo.current.md` erzeugt.

## Neue Dateien

- `schemas/jobagent.schema.json`
- `docs/data-model.md`
- `tests/Test-JobAgentSchema.ps1`
- `tests/fixtures/jobagent/valid.json`
- `tests/fixtures/jobagent/invalid-missing-official-url.json`
- `tests/fixtures/jobagent/invalid-missing-job-id.json`

## Geaenderte Zustandsdateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `npx --yes --package ajv-cli@5 --package ajv-formats ajv validate -s schemas\jobagent.schema.json -d tests\fixtures\jobagent\valid.json --spec=draft2020 -c ajv-formats` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-130438.log`
- `.\ci.cmd todo-seed` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Supertest-Hinweis

- Ein Supertest wurde in diesem Arbeitsschritt nicht vom Nutzer angefragt und gilt nach aktueller Nutzeranweisung als erledigt/nicht blockierend.
- Ein versehentlicher Lauf von `.\ci.cmd supertest` schlug vorher fehl, weil das aktuelle Projekt kein Gradle-Build enthaelt und `D:\_Scripte\JobAgent\sonar.cmd` fehlt. Das ist kein fachlicher Fehler von `JA-002`.
- Der konkrete JA-002-Funktionstest ist gruen.

## Offene Aufgaben

1. `TD-0001 / JA-003 Speicher- und Migrationsschicht fuer idempotente Daily-Runs implementieren`
   - Persistenz unterhalb des Projektverzeichnisses definieren und implementieren.
   - Entscheidung fuer JSON-Dateien, JSONL-Events oder SQLite final dokumentieren.
   - Atomare Writes mit temporaerer Datei und best-effort Flush bauen.
   - Backup vor Migration und Recovery-Prozedur implementieren.
   - Locking gegen parallele Daily-Runs ergaenzen.
   - Repository-API auf Basis von `jobagent/v1` bauen: `upsertCompany`, `upsertJobSnapshot`, `recordScanAttempt`, `markMissingJobs`, `listDailyOutputCandidates`.
   - Funktionstests fuer leeren Store, vorhandenen Store, beschaedigte Datei, Migration, idempotentes Speichern und Lock-Verletzung erstellen.
2. Danach `JA-004` Firmeninventar-Seed und Erweiterungsstrategie.
3. Danach `JA-005` Quellenadapter-Vertrag.
4. Danach `JA-006` offizielle Quellenverifikation und URL-Kanonisierung.

## Risiken und Annahmen

- Die finale Persistenztechnologie ist noch offen; `docs/data-model.md` setzt bewusst nur den Schema- und Austauschvertrag.
- Keine Live-Recherche starten, bevor Persistenz, Quellenverifikation und Deduplikation stehen.
- Keine personenbezogenen Bewerbungsdaten speichern.
- Keine Firmen, Stellen, URLs, Geodaten oder Gehaelter erfinden.
- SonarQube auf `localhost:9000` reagierte beim Check nicht innerhalb des Timeouts, obwohl Port 9000 offen war.
