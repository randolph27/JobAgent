# Handoff latest

Stand: 2026-08-17T17:11:55.108+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-019 ist abgeschlossen und archiviert; naechster fachlicher Einstieg ist TD-0016 / JA-020.`
- Branch: `master`
- HEAD: `bdea1cdf52b3`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Schritt

- JA-019 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert.
- `src/JobAgent.SourceVerification.psm1` fuehrt `verification_evidence` ein, haertet ATS-Pruefungen gegen `verified_by_url` und behandelt unbelegte ATS-Domains fail-closed als `UNVERIFIED`.
- `src/JobAgent.CompanyInventory.psm1` persistiert fuer Seed-Karrierequellen jetzt ebenfalls auditierbare Verifikationsbelege.
- `src/JobAgent.Persistence.psm1` normalisiert bestehende `jobagent/v1`-Stores ohne `verification_evidence` kompatibel beim Laden und erzwingt kuenftig mindestens einen Verifikationsbeleg pro `job_source`.
- `schemas/jobagent.schema.json` macht `job_sources[*].verification_evidence` verpflichtend und definiert dafuer Status-, Typ- und Feldvertrag.
- Die Testsuite deckt jetzt Karriere-Belege, ATS mit und ohne Firmenbeleg, Legacy-Normalisierung und Folgekompatibilitaet in Daily-Run-, Live- und Report-Lanes ab.

## Geaenderte Dateien

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `schemas/jobagent.schema.json`
- `src/JobAgent.CompanyInventory.psm1`
- `src/JobAgent.Persistence.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyInventory.ps1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentLiveScan.ps1`
- `tests/Test-JobAgentPersistence.ps1`
- `tests/Test-JobAgentReport.ps1`
- `tests/Test-JobAgentSchema.ps1`
- `tests/Test-JobAgentSourceAdapters.ps1`
- `tests/Test-JobAgentSourceVerification.ps1`
- `tests/fixtures/jobagent/valid.json`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.json`
- `handoff.latest.md`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> letzter verifizierter Digest `Exit 0`; kein separater Supertest fuer JA-019 angefragt und gemaess Nutzeranweisung als erledigt gewertet.

## Offene Prioritaeten

1. `TD-0016 / JA-020`
   `src/JobAgent.LiveScan.psm1`, `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentLiveScan.ps1`, `tests/Test-JobAgentSourceAdapters.ps1`, `tests/Test-JobAgentDailyRun.ps1`
   Live-Adapter von generischer HTML-Linkerkennung auf robuste Karriereportal-/ATS-Erkennung erweitern. Fokus: strukturierte JSON-LD/JobPosting-Auswertung, mindestens ein explizites ATS-Muster, Fehlerklassen und begrenzte Detailfetches beibehalten.
2. `TD-0017 / JA-021`
   `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tools/Seed-JobAgentCompanies.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1`
   Firmeninventar quellenorientiert vergroessern, neue Firmen dedupliziert aufnehmen und neue ATS-/Career-Quellen nur mit belastbarer offizieller Beweiskette einpflegen.
3. `TD-0018 / JA-022`
   `.ci/ci.config.json`, `.ci/bin/modules/*`, `tests/Test-JobAgentOperations.ps1`, `manual/PROGRAM.md`
   Devserver-Portvertrag (`:8500` vs `:8300`) bereinigen, lokalen HTML-Audit einfuehren und Handoff/Status um nutzbare Reportpfade fuer lokale Oeffnung erweitern.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` enthaelt jetzt nur noch JA-020 bis JA-022.
- `Roadmap_archive.md` enthaelt jetzt JA-001 bis JA-019.
- `todo.current.md` und `todo.state.json` enthalten nur noch TD-0016 bis TD-0018; TD-0015 ist als `done` im Index hinterlegt und aus der aktiven Liste entfernt.
- `verification_evidence` ist jetzt Pflicht im Schema und wird fuer neue sowie legacy-normalisierte `job_sources` erwartet.
- ATS-Domains duerfen nur dann als offiziell gelten, wenn `official_domain` zur Ziel-URL passt und `verified_by_url` selbst ueber die offizielle Firmen- oder Karriere-URL validiert werden kann.
- Redirect-Ketten sind jetzt modelliert, werden aber noch nicht aktiv per Live-Redirect-Aufloesung befuellt; diese operative Nutzung bleibt Teil von JA-020.
- Reports rendern `verification_evidence` aktuell nicht separat; JA-020/JA-022 koennen bei Bedarf die Sichtbarkeit in HTML/Markdown weiter ausbauen, fachlich ist die Persistenz bereits vorhanden.
