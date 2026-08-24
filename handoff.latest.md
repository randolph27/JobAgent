# Handoff latest

Stand: 2026-08-24T11:35:44.234+02:00

## Zustand

- Active: ``
- Status: `open`
- Branch: `master`
- HEAD: `036c43698520`
- Upstream: `origin/master`
- Ahead/Behind vor finalem Push: `1/0`
- Worktree: `dirty`
- Route: `True`
- Letzter STP: `.\ci.cmd stp` -> Exit `0`

## Abgeschlossen

- `JA-026 Daily-Run-Scanbreite konfigurierbar machen und Bericht darf nicht nur drei Firmen anzeigen` ist abgeschlossen und nach `Roadmap_archive.md` rotiert.
- `TD-0043 CI: Resolve drift (observer/route/immutables)` ist erledigt. Ausloeser war Drift nach Roadmap-/Config-Aenderungen; bereinigt durch `.\ci.cmd repin-immutables` und `.\ci.cmd observer-baseline`.
- Daily-Run persistiert jetzt pro ScanRun eine `selection_summary` mit `companies_total`, `companies_due`, `companies_selected`, `companies_skipped`, `limit`, `selection_reason`, `explicit_company_ids` und gekappter Skip-Liste.
- Daily-Run-Markdown und Daily-Run-HTML zeigen `Firmen gesamt`, `Firmen im Lauf`, `Faellige Firmen`, `Uebersprungene Firmen`, `Limit` und `Auswahlgrund`.
- Live-Pilot und LiveScan-Policy verwenden Default `MaxCompanies 25`; CLI-Overrides wie `-MaxCompanies`, `-CompanyIds` und `-TimeoutSeconds` bleiben erhalten.

## Wichtige geaenderte Dateien

- `.ci/ci.config.json`
- `schemas/jobagent.schema.json`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.Report.psm1`
- `tools/Invoke-JobAgentLivePilot.ps1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentReport.ps1`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- Todo-/Handoff-/Immutable-/Observer-Artefakte

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd drift-check` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- SonarQube `http://localhost:9000/api/system/status` -> `UP`
- Devserver `.\ci.cmd devserver-status` -> Port `8500` listening

## Offene Aufgaben

- `TD-0039 / JA-025`: Firmeninventar auf mindestens 1000 verifizierte oder pruefbare Zielgebiet-Kandidaten erweitern. Einstieg: Quelleninventar, erlaubte Kandidatenkanaele, Importwellen, Dedupe, Coverage-Gates. Tests: `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentImportWaves.ps1`, `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentCompanyDedupeScale.ps1`.
- `TD-0041 / JA-027`: Verifizierte Karriere-/ATS-Link-Ermittlung fuer Firmen- und Jobquellen skalieren. Nach oder parallel zu JA-025 vorbereiten; keine Aggregatorlinks als Primaerbeleg, keine generischen Such-/FAQ-/Landingpages als Jobdetails persistieren.

## Naechster Anker

Mit `JA-025` weitermachen: Kandidatenbasis fuer Muenchen, 20-km-Umkreis und Freising skalieren. Keine Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen erfinden. Jobboersen nur als Discovery-Hinweise verwenden, nicht als Primaerquelle.
