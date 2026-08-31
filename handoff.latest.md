# Handoff latest

Stand: 2026-08-31T08:10:54.939+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- HEAD vor Handoff-Commit: `ff8fa6a`
- Upstream: `origin/master`
- Worktree-Ziel: nach Handoff-Commit sauber
- Route: `true`
- STP: `.\ci.cmd stp` am 2026-08-31T08:10:54+02:00 mit Exit `0`
- Supertest: nicht ausgefuehrt; JA-027 ist weiter offen, deshalb bleiben funktionsbezogene Tests massgeblich.

## Letzter fachlicher Abschluss

`JA-027` Welle V/B-Import:

- 16 offiziell belegte Arbeitgeber verarbeitet.
- 15 neue produktive Firmen aufgenommen:
  MVTec Software GmbH, SimScale GmbH, NFON AG, Mytheresa, Mutares SE & Co. KGaA, HolidayCheck Group AG, Serviceplan Gruppe SE & Co. KG, Muenchner Kammerspiele, Penguin Random House Verlagsgruppe, PwC Deutschland, ORACLE Deutschland, Roche Diagnostics, Muenchner Verkehrsgesellschaft mbH, Piper Verlag GmbH, MOTORWORLD Muenchen.
- 1 dedupliziertes Update:
  Muenchner Volkstheater wurde wegen Domainmatch als Update zu `Muenchener Volkstheater GmbH` verarbeitet.
- Store danach: 295 Firmen, 292 JobSources.
- Source Coverage danach: 294 offizielle Quellen, 293 Karrierequellen.
- Kandidatenqueue danach: 442 Kandidaten bereits produktiv verifiziert; 1340 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung; 2 Kandidaten in `VERIFY_OFFICIAL_SITE`; 1 Kandidat in `MANUAL_DECISION`.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0625`, `coverage_delta=15`.

## Geaenderte Artefakte

- `Roadmap.md`
- `data/jobagent/company-discovery.official.wave-v-20260831.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Evidence

- `data/jobagent/company-discovery.official.wave-v-20260831.json`
- `logs/jobagent/company-discovery-import-20260831-060440.json`
- `logs/jobagent/company-candidate-verification-20260831-060447.json`
- `logs/jobagent/company-coverage-20260831-060540.json`
- `logs/jobagent/company-coverage-20260831-060540.md`
- `logs/jobagent/company-coverage-20260831-060716.json`
- `logs/jobagent/company-coverage-20260831-060716.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260831T060441502Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-v-20260831.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest`/`curl.exe` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle V -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-v-20260831.json -WaveId B` -> Exit `0`
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
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit `1` als erwarteter Kein-Treffer-Check
- `.\ci.cmd stp` -> Exit `0`

## Naechster Einstieg

`JA-027` mit der naechsten verifizierten Importwelle aus der Kandidatenqueue fortsetzen. Supertest erst bei komplettem Roadmap-Abschluss oder ausdruecklicher Nutzeranforderung.

