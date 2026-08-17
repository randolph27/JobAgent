# Handoff latest

Stand: 2026-08-17T16:46:00.000+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-017 abgeschlossen und archiviert; naechster fachlicher Einstieg ist TD-0014 / JA-018.`
- Branch: `master`
- HEAD: `16bc75c80ee5`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Schritt

- JA-017 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert.
- `src/JobAgent.Report.psm1` rendert jetzt `published_at`, `first_seen`, `last_seen`, `salary`, `requirements`, `age_basis` und `age_days`.
- Markdown- und HTML-Report enthalten zusaetzlich die Sektion `Fehler und unsichere Quellen`.
- `src/JobAgent.DailyRun.psm1` uebernimmt die erweiterten Statistikfelder aus dem gemeinsamen Reportmodell.
- `todo-seed` hat die offenen Roadmap-Punkte als TD-0014 bis TD-0018 fuer den naechsten Chat vorbereitet.

## Geaenderte Dateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentReport.ps1`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd todo-seed` -> Exit `0`

## Offene Prioritaeten

1. `TD-0014 / JA-018`
   `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.Persistence.psm1`, `src/JobAgent.SourceAdapters.psm1`, `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentDailyRun.ps1`
   `REMOVED` auf `source_id` begrenzen und ein explizites `CLOSED`-Signal vom Adaptervertrag bis zur Statusmaschine verdrahten.
2. `TD-0015 / JA-019`
   `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Persistence.psm1`, `schemas/jobagent.schema.json`, `tests/Test-JobAgentSourceVerification.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`
   `verification_evidence` fuer offizielle ATS-/Redirect-Belege einfuehren und persistent machen.
3. `TD-0016 / JA-020`
   Live-Adapter erst nach JA-018 und JA-019 auf robuste Karriere- und ATS-Erkennung erweitern.
4. `TD-0017 / JA-021`
   Firmeninventar erst nach Status-/Quellenhaertung autonom und dedupliziert verbreitern.
5. `TD-0018 / JA-022`
   Lokalen Devserver-Portvertrag und HTML-Visual-Audit nachziehen, wenn die fachlichen Report-/Statuspunkte stabil sind.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` enthaelt jetzt nur noch JA-018 bis JA-022.
- `Roadmap_archive.md` enthaelt JA-001 bis JA-017.
- `todo.current.md` und `todo.state.json` enthalten jetzt die offenen To-dos TD-0014 bis TD-0018.
- Supertest wurde fuer JA-017 nicht separat gestartet; gemaess aktueller Nutzeranweisung gilt das Gate fuer diesen Abschluss als erledigt.
- Der browserbasierte Layout-Audit fuer HTML bleibt Teil von JA-022.
