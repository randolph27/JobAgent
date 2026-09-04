# Handoff latest

Stand: 2026-09-04T21:08:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Branch: master, Upstream: origin/master
- HEAD vor Commit: 9480591 Update handoff after wave AU
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am 2026-09-04T21:07:26.266+02:00.
- Supertest: nicht ausgefuehrt, weil JA-027 insgesamt offen bleibt.

## Letzter Fachfortschritt

Welle AV/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

- itsmydata GmbH
- Lilio Health GmbH
- Karevo GmbH
- Latheca GmbH
- Landschaftspflegeverband Freising e.V.
- ALFA AI

Kennzahlen nach Welle AV:

- Store: 449 Firmen
- JobSources: 419
- Source Coverage: 421 offizielle Quellen
- Karrierequellen: 420
- ATS-Quellen: 1
- Kandidatenqueue: 631 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1151 mit DISCOVER_OFFICIAL_WEBSITE
- Kandidatenqueue: 2 mit VERIFY_OFFICIAL_SITE
- Kandidatenqueue: 1 mit MANUAL_DECISION
- Importwellen-Gate B: passed, manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=6

## Evidence Welle AV

- data/jobagent/company-discovery.official.wave-av-20260904.json
- logs/jobagent/company-discovery-import-20260904-185803.json
- logs/jobagent/company-candidate-verification-20260904-185809.json
- logs/jobagent/company-coverage-20260904-185921.json
- logs/jobagent/company-coverage-20260904-185921.md
- logs/jobagent/ja-023-source-coverage.json
- data/jobagent/backups/store-20260904T185803845Z-pre-wave-import.json
- html/jobagent/company-coverage.html
- output/playwright/ja-022-viewport-800.png
- output/playwright/ja-022-viewport-1366.png
- output/playwright/ja-022-viewport-1920.png

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-av-20260904.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AV -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-av-20260904.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd devserver-status` -> Exit `0`, Devserver lief auf Port 8500
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube war `UP`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

JA-027 mit Welle AW fortsetzen. Naechste Feed-Datei: `data/jobagent/company-discovery.official.wave-aw-20260904.json` oder bei neuem Datum entsprechend `wave-aw-<YYYYMMDD>.json`. Kandidaten mit `next_action == DISCOVER_OFFICIAL_WEBSITE`, `risk_level == LOW`, hohem `priority_score` und belastbarem Muenchen-/Freising-Bezug priorisieren.

## Risiken

- JA-027 ist noch nicht abschliessbar, weil 1151 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber nicht der aktive Hotspot.
- Fuenf AV-Firmen wurden ohne separate Karriere-URL als offizielle Firmendomain importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
