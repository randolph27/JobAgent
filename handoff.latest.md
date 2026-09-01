# Handoff latest

Stand: 2026-09-01T07:58:37.883+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Commit: `129a073f1a58`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; `JA-027` ist weiter offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-01T07:58:37.883+02:00`.
- Supertest: nicht ausgefuehrt, weil `JA-027` nicht abgeschlossen ist und der Nutzer funktionsbezogene Tests bis dahin bevorzugt.

## Aktueller Fachstand

JA-027 wurde mit Welle AE/B fortgesetzt. Welle AE hat 6 offiziell belegte Arbeitgeber produktiv neu aufgenommen:

- `Smart Reporting GmbH`
- `VEACT GmbH`
- `Shore GmbH`
- `remote control productions GmbH`
- `Retorio GmbH`
- `Scandic Hotels Deutschland GmbH`

Kennzahlen nach Welle AE:

- Store: `356` Firmen
- JobSources: `353`
- Source Coverage: `355` offizielle Quellen
- Karrierequellen: `354`
- Kandidatenqueue: `520` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1264` weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=6`

## Geaenderte Dateien und Artefakte

- `data/jobagent/company-discovery.official.wave-ae-20260901.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `logs/jobagent/ja-023-source-coverage.json`
- `Roadmap.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

Evidence aus Welle AE:

- `logs/jobagent/company-discovery-import-20260901-055239.json`
- `logs/jobagent/company-candidate-verification-20260901-055245.json`
- `logs/jobagent/company-coverage-20260901-055345.json`
- `logs/jobagent/company-coverage-20260901-055345.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260901T055240447Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ae-20260901.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AE -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ae-20260901.json -WaveId B` -> Exit `0`
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
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit `1`, erwarteter Kein-Treffer-Check
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

`JA-027` mit Welle AF fortsetzen: Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren, offizielle Firmenwebsite plus Karriere-/ATS-Beleg per HTTP pruefen, Feed `data/jobagent/company-discovery.official.wave-af-YYYYMMDD.json` anlegen, importieren, Coverage/Source-Coverage aktualisieren und funktionsbezogen testen.
