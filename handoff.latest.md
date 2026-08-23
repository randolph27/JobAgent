# Handoff latest

Stand: 2026-08-23T11:46:47+02:00

## Ziel fuer neuen Chat

Direkt mit `TD-0029` / `JA-029` weitermachen. Nicht mit `JA-030` starten: `JA-030` bleibt fachlich nachgelagert, bis `JA-029` komplett abgeschlossen und rotiert ist.

## Aktueller Zustand

- Active: `TD-0029`
- Status: `in-progress`
- Branch: `master`
- HEAD vor diesem Commit: `728f3b9`
- Worktree vor Stage/Commit: dirty
- STP: `./ci.cmd stp` lief am 2026-08-23T11:46:47+02:00 erfolgreich mit Exit 0.
- Roadmap: `JA-029` und `JA-030` sind noch aktiv. `JA-029` ist noch nicht abgeschlossen und wurde nicht nach `Roadmap_archive.md` rotiert.
- Supertest: nicht ausgefuehrt; laut Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt.

## In diesem Arbeitsabschnitt umgesetzt

Teilumsetzung fuer `JA-029`:

- Neue Wellenkonfiguration `data/jobagent/company-import-waves.json` mit Schema `jobagent/company-import-waves/v1`.
- Wellen A-D definieren Zielgroessen, erlaubte Verifikationsstatus, Pflicht-Evidence, Dubletten-/Review-Grenzen und Rollback-Pflicht.
- `src/JobAgent.CompanyInventory.psm1` enthaelt jetzt `Test-JobAgentCompanyImportWaveGate`.
- Gate prueft vor produktivem Wellenimport Schema, definierte Welle, Store-Dokument vor/nach Import, Coverage-Delta, Dublettenrate, Manual-Review-Rate, erlaubte `verification_status`, Pflicht-Evidence, Sperre fuer produktive `DISCOVERY_HINT`-/`MANUAL_REVIEW`-Upserts und vorhandenen Rollback-Backup.
- `tools/Import-JobAgentCompanyDiscovery.ps1` akzeptiert jetzt `-WaveId` und `-WaveConfigPath`.
- Bei `-WaveId` erstellt der Import vor dem Gate einen Backup unter `data/jobagent/backups/`, prueft das Gate und schreibt den Store nur bei `passed`.
- Bei Gate-Fehler wird fail-closed abgebrochen; der Store wird nicht geschrieben.
- Neuer Funktionstest `tests/Test-JobAgentImportWaves.ps1`.
- `docs/test-matrix.json`, `docs/test-matrix.md`, `tests/Test-JobAgentSupertest.ps1` und `tests/Test-JobAgentTestMatrix.ps1` wurden um `JA-029` / `Test-JobAgentImportWaves.ps1` erweitert.

## Verifikation

Gruen:

- `pwsh -NoProfile -File tests\Test-JobAgentImportWaves.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `./ci.cmd stp` -> Exit 0

Nicht ausgefuehrt:

- `./ci.cmd supertest`; nicht angefragt und laut Nutzeranweisung als erledigt zu werten.

## Geaenderte Dateien

- `data/jobagent/company-import-waves.json`
- `docs/test-matrix.json`
- `docs/test-matrix.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.CompanyInventory.psm1`
- `tests/Test-JobAgentImportWaves.ps1`
- `tests/Test-JobAgentSupertest.ps1`
- `tests/Test-JobAgentTestMatrix.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Import-JobAgentCompanyDiscovery.ps1`

## Naechste Aufgabe

`JA-029` weiter abschliessen:

1. Store-/Report-Skalierung fuer tausende Firmen umsetzen: sortierte/segmentierte Ausgaben, grosse HTML-Tabellen bedienbar halten, Coverage-Ausgabe auf Wellenmetriken erweitern.
2. Produktiven Wellenlauf mit vorhandenen verifizierten Feeds vorbereiten, aber keine unverifizierten Kandidaten massenhaft in `data/jobagent/store.json` aufnehmen.
3. Wellenmetriken im Coverage-Report sichtbar machen: Firmen gesamt, verifiziert, nur Hinweis, Review, Dublettenquote, Akzeptanzquote, Scanfaehigkeit, Coverage-Delta und Backup-Pfad.
4. Funktionstests erneut fokussiert ausfuehren: `tests\Test-JobAgentImportWaves.ps1`, `tests\Test-JobAgentCoverage.ps1`, bei Report-Aenderungen `tests\Test-JobAgentReport.ps1`.
5. Erst wenn `JA-029` vollstaendig ist: `./ci.cmd supertest`, Roadmap-Rotation nach `Roadmap_archive.md`, Todo-Abschluss und finaler Commit.

## Harte Grenzen fuer Folgeagent

- Keine Massenaufnahme unverifizierter Kandidaten.
- Keine Loeschung bestehender Firmen ohne expliziten Auftrag.
- Keine riesigen Rohdaten-Dumps committen.
- Keine Behauptung "alle Firmen", solange die Quellenabdeckung nicht definiert und messbar ist.
- `JA-030` erst beginnen, wenn `JA-029` abgeschlossen und rotiert ist.
