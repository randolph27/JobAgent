# Handoff latest

Stand: 2026-09-05T14:04:38+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`, Upstream: `origin/master`
- HEAD vor diesem Handoff-Sync: `699cd79 Add verified company import wave AZ`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` bleibt aktiv, weil weiterhin 1132 Kandidaten fail-closed in manueller Website-/Scope-Pruefung stehen.
- Supertest: nicht ausgefuehrt, weil `JA-027` noch nicht komplett abgeschlossen ist und die aktuelle Nutzeranweisung Supertest erst nach Roadmap-Abschluss vorsieht.

## Letzter Fachfortschritt

Welle AZ/B wurde abgeschlossen und im Commit `699cd79 Add verified company import wave AZ` gepusht. Neu produktiv aufgenommen wurden:

- toponauten GmbH
- Ohrbeit GmbH
- AV-Suite Veranstaltungstechnik GmbH
- Tresor TV Produktions GmbH
- Huntrees GmbH

Kennzahlen nach Welle AZ:

- Store: 469 Firmen
- JobSources: 429
- Source Coverage: 431 offizielle Quellen
- Karrierequellen: 430
- ATS-Quellen: 1
- Discovery Sources: 1820
- Kandidatenqueue: 652 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1132 mit manueller Website-/Scope-Pruefung
- Importwellen-Gate B: passed, `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=5`

## Evidence Welle AZ

- `data/jobagent/company-discovery.official.wave-az-20260905.json`
- `logs/jobagent/company-discovery-import-20260905-115720.json`
- `logs/jobagent/company-candidate-verification-20260905-115725.json`
- `logs/jobagent/company-coverage-20260905-115838.json`
- `logs/jobagent/company-coverage-20260905-115838.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `data/jobagent/backups/store-20260905T115721390Z-pre-wave-import.json`
- `html/jobagent/company-coverage.html`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-viewport-800.png`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`

## Validierung Welle AZ

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-az-20260905.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AZ -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-az-20260905.json -WaveId B` -> Exit `0`
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

`JA-027` mit Welle BA fortsetzen. Naechste Feed-Datei: `data/jobagent/company-discovery.official.wave-ba-20260905.json`.

## Risiken und offene Punkte

- `JA-027` ist noch nicht abschliessbar, weil 1132 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Drei AZ-Firmen wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
