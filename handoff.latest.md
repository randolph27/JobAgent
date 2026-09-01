# Handoff latest

Stand: 2026-09-01T07:48:00+02:00

## Status

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Active: `TD-0041`
- Status: `in-progress`
- Aktiver Roadmap-Punkt: `JA-027`
- Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung erst bei Abschluss von `JA-027`.

## Ergebnis Welle AD

- 6 offiziell belegte Arbeitgeber verarbeitet.
- 5 neue produktive Firmen: `MSD Deutschland`, `JANUS Productions GmbH`, `Merkur tz MEDIA`, `MicroGenesis TechSoft`, `Fraunhofer-Gesellschaft`.
- 1 dedupliziertes Update: `MGH Muenchner Gewerbehof- und Technologiezentrumsgesellschaft mbH` -> bestehender MGH-Domainmatch.
- Store: `350` Firmen, `347` JobSources.
- Source Coverage: `349` offizielle Quellen, `348` Karrierequellen.
- Kandidatenqueue: `514` verifiziert/produktiv belegt, `1268` weiter in `DISCOVER_OFFICIAL_WEBSITE`, `2` in `VERIFY_OFFICIAL_SITE`, `1` in `MANUAL_DECISION`.
- Importwellen-Gate B: `passed` (`manual_review_rate=0.0`, `duplicate_rate=0.1667`, `coverage_delta=5`).

## Evidence

- `data/jobagent/company-discovery.official.wave-ad-20260901.json`
- `logs/jobagent/company-discovery-import-20260901-053852.json`
- `logs/jobagent/company-candidate-verification-20260901-053901.json`
- `logs/jobagent/company-coverage-20260901-053901.json`
- `logs/jobagent/company-coverage-20260901-053901.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- `data/jobagent/backups/store-20260901T053852654Z-pre-wave-import.json`
- `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ad-20260901.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get fuer alle official_website_url/career_url/discovery_url aus Welle AD` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ad-20260901.json -WaveId B` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit `1`
- `.\ci.cmd stp` -> Exit `0`

## Naechster Anker

JA-027 fortsetzen: verbleibende `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten fail-closed priorisieren und naechste Welle AE nur mit erreichbarer offizieller Website plus Karriere-/ATS-Beleg importieren.
