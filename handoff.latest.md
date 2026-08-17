# Handoff latest

Stand: 2026-08-17T16:55:49.210+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-018 ist abgeschlossen und archiviert; naechster fachlicher Einstieg ist TD-0015 / JA-019.`
- Branch: `master`
- HEAD: `e581cd667308`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Schritt

- JA-018 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert.
- `src/JobAgent.Persistence.psm1` scoped `Mark-JobAgentMissingJobs` jetzt optional auf `SourceId`, damit erfolgreiche Leerlaeufe nur Jobs derselben Quelle auf `REMOVED` setzen.
- `src/JobAgent.StatusMachine.psm1` entfernt nur noch pro erfolgreicher Quelle, verarbeitet explizite Closed-Signale aus `source_status` oder `job_state` und erzeugt `JOB_CLOSED`.
- `src/JobAgent.SourceAdapters.psm1` dokumentiert `source_status` und `job_state` als optionale RawJob-Felder; `New-JobAgentRawJob` setzt standardmaessig `source_status = ACTIVE`.
- Die Funktionstests decken jetzt Mehrquellen-Entfernung, explizites `CLOSED` und Daily-Run-Verhalten mit parallelen Quellen ab.

## Geaenderte Dateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `src/JobAgent.Persistence.psm1`
- `src/JobAgent.SourceAdapters.psm1`
- `src/JobAgent.StatusMachine.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentPersistence.ps1`
- `tests/Test-JobAgentSourceAdapters.ps1`
- `tests/Test-JobAgentStatusMachine.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.json`
- `handoff.latest.md`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> letzter verifizierter Digest `Exit 0`; kein separater Lauf fuer JA-018 angefordert und gemaess Nutzeranweisung als erledigt gewertet.

## Offene Prioritaeten

1. `TD-0015 / JA-019`
   `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Persistence.psm1`, `schemas/jobagent.schema.json`, `tests/Test-JobAgentSourceVerification.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`
   `verification_evidence` fuer offizielle ATS-/Redirect-Belege einfuehren, persistieren und im Report/Audit nachvollziehbar machen.
2. `TD-0016 / JA-020`
   Live-Adapter erst nach JA-019 auf robuste Karriere- und ATS-Erkennung ausbauen; dabei `source_status`/`job_state` bei belegten Closed-Signalen weiterverwenden.
3. `TD-0017 / JA-021`
   Firmeninventar nach JA-019 dedupliziert verbreitern; neue ATS-Quellen nur mit belastbarer offizieller Beweiskette aufnehmen.
4. `TD-0018 / JA-022`
   Devserver-Portvertrag, HTML-Audit und lokale Artefaktbedienung erst nach stabiler Quellen-/Statuslogik nachziehen.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` enthaelt jetzt nur noch JA-019 bis JA-022.
- `Roadmap_archive.md` enthaelt jetzt JA-001 bis JA-018.
- `todo.current.md` und `todo.state.json` enthalten nur noch TD-0015 bis TD-0018; TD-0014 ist im Index als `done` markiert und wurde aus der aktiven Liste entfernt.
- Fuer `CLOSED` gilt jetzt: nur explizite Signale (`source_status`, `job_state`) duerfen `JOB_CLOSED` erzeugen; unbekannte oder fehlende Signals bleiben fail-closed.
- Fuer `REMOVED` gilt jetzt: nur erfolgreiche Quelllaeufe derselben `source_id` duerfen einen bestehenden Job entfernen; Fehler-/Timeout-/Blockadefaelle entfernen nichts.
