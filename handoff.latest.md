# Handoff latest

Stand: 2026-09-05T09:05:48.828+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`, Upstream: `origin/master`
- HEAD vor diesem Arbeitsstand: `d05e32360b56`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` ist fachlich nicht komplett erledigt; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-05T09:05:12.149+02:00`; anschliessend wurde ein Korrektur-Event `EV-20260905-090548-awcorr` geschrieben, weil der STP-Digest einen alten Supertest als Verifikation referenzierte.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung erst bei Abschluss von `JA-027`.

## Letzter Fachfortschritt

Welle AW/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

- Breathment GmbH
- Raytheon Deutschland GmbH
- Rainer Schmidt Landschaftsarchitekten
- TAWNY GmbH
- Tensordyne (vormals Recogni)

Kennzahlen nach Welle AW:

- Store: 454 Firmen
- JobSources: 421
- Source Coverage: 423 offizielle Quellen
- Karrierequellen: 422
- ATS-Quellen: 1
- Discovery Sources: 1820
- Kandidatenqueue: 636 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1148 mit manueller Website-/Scope-Pruefung
- Importwellen-Gate B: passed, `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=5`

## Evidence Welle AW

- `data/jobagent/company-discovery.official.wave-aw-20260905.json`
- `logs/jobagent/company-discovery-import-20260905-065738.json`
- `logs/jobagent/company-candidate-verification-20260905-065746.json`
- `logs/jobagent/company-coverage-20260905-070052.json`
- `logs/jobagent/company-coverage-20260905-070052.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `data/jobagent/backups/store-20260905T065739183Z-pre-wave-import.json`
- `html/jobagent/company-coverage.html`
- `output/playwright/ja-022-viewport-800.png`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`

## Validierung

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-aw-20260905.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AW -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-aw-20260905.json -WaveId B` -> Exit `0`
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

`JA-027` mit Welle AX fortsetzen. Naechste Feed-Datei: `data/jobagent/company-discovery.official.wave-ax-20260905.json`.

Priorisierung: Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` mit `next_action == DISCOVER_OFFICIAL_WEBSITE`, niedrigem Risiko, hohem `priority_score` und belastbarem Muenchen-/Freising-Bezug auswaehlen; offizielle Firmenwebsite und Karriere-/Jobs-/ATS-Link fail-closed pruefen; nur offiziell belegte Firmen importieren.

## Risiken und offene Punkte

- `JA-027` ist noch nicht abschliessbar, weil 1148 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Drei AW-Firmen wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
