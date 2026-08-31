# Handoff latest

Stand: 2026-08-31T13:10:00.000+02:00

## Zustand

- Active: TD-0041
- Status: in-progress
- Ziel: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Branch: master
- HEAD: 31e63755e5fe
- Upstream: origin/master
- Ahead/Behind: 0/0
- Worktree: dirty
- Route: true
- STP: `./ci.cmd stp` am 2026-08-31T13:08:15.069+02:00 mit Exit 0; danach manuelle Korrektur der Handoff-Verifikation, weil STP den alten Supertest-Digest referenziert hat.
- Supertest: nicht ausgefuehrt; JA-027 ist weiter offen, deshalb bleiben funktionsbezogene Tests massgeblich.

## Letzter fachlicher Abschluss

JA-027 Welle X/B-Import:

- 8 offiziell belegte Arbeitgeber produktiv neu aufgenommen: ExB Labs GmbH, FIXIT TM Holding GmbH, KNOWRON GmbH, SAP Fioneer GmbH, Siemens EDA, MHP Management- und IT-Beratung GmbH, Dolby Germany GmbH, NVIDIA GmbH.
- Store danach: 309 Firmen, 306 JobSources.
- Source Coverage danach: 308 offizielle Quellen, 307 Karrierequellen.
- Kandidatenqueue danach: 460 Kandidaten bereits produktiv verifiziert; 1322 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung; 2 Kandidaten in VERIFY_OFFICIAL_SITE; 1 Kandidat in MANUAL_DECISION; 1 Kandidat in RETRY_EXHAUSTED.
- Importwellen-Gate fuer Welle B: passed, manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=8.

## Geaenderte Artefakte

- Roadmap.md
- data/jobagent/company-discovery.official.wave-x-20260831.json
- data/jobagent/company-candidate-verification.queue.json
- data/jobagent/store.json
- html/jobagent/company-coverage.html
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- todo.state.json
- handoff.latest.md
- handoff.latest.json

## Evidence

- data/jobagent/company-discovery.official.wave-x-20260831.json
- logs/jobagent/company-discovery-import-20260831-110143.json
- logs/jobagent/company-candidate-verification-20260831-110150.json
- logs/jobagent/company-coverage-20260831-110246.json
- logs/jobagent/company-coverage-20260831-110246.md
- logs/jobagent/company-coverage-20260831-110423.json
- logs/jobagent/ja-023-source-coverage.json
- html/jobagent/company-coverage.html
- Store-Backup: data/jobagent/backups/store-20260831T110144096Z-pre-wave-import.json
- Viewport-Screenshots: output/playwright/ja-022-viewport-800.png, output/playwright/ja-022-viewport-1366.png, output/playwright/ja-022-viewport-1920.png

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-x-20260831.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest fuer alle official_website_url/career_url/discovery_url aus Welle X` -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-x-20260831.json -WaveId B` -> Exit 0
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit 1
- `.\ci.cmd stp` -> Exit 0

## Naechster Einstieg

JA-027 mit Welle Y fortsetzen. Naechste Kandidaten aus data/jobagent/company-candidate-verification.queue.json nur bei offizieller Firmenwebsite plus Karriere-/Jobs-/ATS-Evidenz in data/jobagent/company-discovery.official.wave-y-YYYYMMDD.json aufnehmen, URLs pruefen, WaveId B importieren, Queue/Coverage/Source-Coverage und Funktionstests laufen lassen. Supertest erst bei komplettem Roadmap-Abschluss oder expliziter Anforderung.
