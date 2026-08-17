# Handoff latest

Stand: 2026-08-17T16:30:58.182+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-016 abgeschlossen und archiviert; naechster fachlicher Einstieg ist JA-017.`
- Branch: `master`
- HEAD: `4c7d6a55ca75`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Schritt

- JA-016 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert.
- Daily-Run erzeugt jetzt JSON-, Markdown- und HTML-Reports.
- `html_report_path` ist in Daily-Run-Rueckgabe, Summary-JSON, CLI-Output und Live-Pilot-Summary verdrahtet.
- HTML-Rendering escaped problematische Inhalte und nutzt nur lokale CSS/HTML-Ressourcen.

## Geaenderte Dateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentReport.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Invoke-JobAgentDailyRun.ps1`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`

## Offene Prioritaeten

1. JA-017 in `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentDailyRun.ps1`, optional `docs/data-model.md`.
   Reporteintraege um `published_at`, `first_seen`, `last_seen`, `salary`, `requirements`, `age_basis`, `age_days` und erweiterte Recherche-Statistik ergaenzen; Markdown und HTML muessen dieselben Pflichtfelder sichtbar machen.
2. JA-018 in `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.Persistence.psm1`, `src/JobAgent.SourceAdapters.psm1`, `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentDailyRun.ps1`.
   `REMOVED` auf `source_id` begrenzen und ein explizites `CLOSED`-Signal vom Adaptervertrag bis zur Statusmaschine durchziehen.
3. JA-019 in `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Persistence.psm1`, `schemas/jobagent.schema.json`, `tests/Test-JobAgentSourceVerification.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`.
   `verification_evidence` fuer ATS-/Redirect-Belege persistieren und im Report spaeter nutzbar machen.
4. JA-020 und JA-021 erst nach JA-018/JA-019 verbreitern.
   Live-Adapter auf strukturierte Karriere-/ATS-Seiten ausbauen und Firmeninventar dedupliziert erweitern.
5. JA-022 erst nach JA-017 angehen.
   Devserver-Portvertrag, lokaler HTML-Audit und Handoff-/Betriebsartefakte fuer oeffenbare HTML-Berichte absichern.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` enthaelt jetzt nur noch aktive Punkte JA-017 bis JA-022.
- `Roadmap_archive.md` enthaelt JA-001 bis JA-016.
- `Roadmap_index.md` wurde entsprechend aktualisiert.
- `html/jobagent/latest.html` existiert bewusst nicht.
- Der browserbasierte Layout-Audit fuer HTML ist noch offen und gehoert zu JA-022, nicht zu JA-016.
- Vor weiteren Roadmap-Rotationen wieder nur funktionsbezogene Tests fahren; Supertest erst nach abgeschlossenem Roadmap-Punkt oder wenn explizit verlangt.
