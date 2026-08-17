# Handoff latest

Stand: 2026-08-17T15:05:00+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `88eb213`
- Upstream: `origin/master`
- Worktree: `dirty`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-009` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`

## Abgeschlossener Punkt

`JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen` ist abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. `TD-0007` wurde aus `todo.current.md` entfernt und im Todo-Index auf `done` gesetzt.

Implementiert:

- `src/JobAgent.StatusMachine.psm1`
  - `Invoke-JobAgentStatusMachine`: verarbeitet AdapterResults pro ScanRun, schreibt ScanAttempts, Jobs, Snapshots und ChangeEvents.
  - Statusuebergaenge: erster Treffer `NEW`, unveraenderter Folgelauf `ACTIVE`, Feldwechsel `UPDATED`, autoritativer leerer Erfolgs-Scan `REMOVED`.
  - Fehlgeschlagene Scans loesen keine Entfernung aus.
  - Invalide Rohjobs ohne Titel oder absolute Detail-URL werden nicht gespeichert und als `JOB_INVALIDATED` protokolliert.
- `tests/Test-JobAgentStatusMachine.ps1`
  - Deckt ersten Lauf, zweiten unveraenderten Lauf, Update-Lauf, fehlgeschlagenen Firmen-Scan, erfolgreiche Entfernung und invaliden Treffer ab.
- `tests/Test-JobAgentSupertest.ps1`
  - Buendelt die Statusmaschine mit den abgeschlossenen JobAgent-Funktionstests.
- `docs/data-model.md`
  - Abschnitt `Statusmaschine` mit Regeln und Funktionstest ergaenzt.
- `.ci/pins/immutable.hashes.json`, `.ci/pins/immutable.snapshot/Roadmap.md`
  - Nach Roadmap-Rotation per `.\ci.cmd repin-immutables` aktualisiert.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd repin-immutables` -> Exit `0`

## Offene Aufgaben

1. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`
   - Adapter, Klassifikation, Deduplikation, Statusmaschine und Persistenz in eine transaktionale Laufsequenz verbinden.
   - Firmen priorisieren und pro Firma isolierte ScanAttempt-Ausfuehrung mit Timeout, Fehlerklasse und Fortsetzung des Gesamtlaufs implementieren.
   - Finales Ergebnisartefakt unter `logs/jobagent/` erzeugen.

## Bekannte Risiken

- SonarQube aus diesem Projekt heraus bleibt blockiert, solange `D:\_Scripte\JobAgent\sonar.cmd` fehlt oder `localhost:9000` nicht antwortet.
- Sonar-Pruefung am 2026-08-17T15:05+02:00: `http://localhost:9000/api/system/status` lief in 5s in ein Timeout; lokales `.\sonar.cmd` und `sonar.cmd` im PATH wurden nicht gefunden.
- Der historische CI-Command `.\ci.cmd supertest` ist nicht identisch mit `tests\Test-JobAgentSupertest.ps1`; der fachliche JobAgent-Supertest ist gruen.
