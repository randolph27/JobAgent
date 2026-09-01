# Handoff latest

Stand: 2026-09-01T08:14:05.003+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Abschlusscommit: `817a763bb290`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; kein Roadmap-Punkt ist komplett erledigt.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-01T08:14:05.003+02:00`.
- Supertest: nicht ausgefuehrt, weil `JA-027` weiter offen ist.

## Aktueller Fachstand

JA-027 wurde mit Welle AF/B fortgesetzt. Welle AF hat 6 offiziell belegte Arbeitgeber verarbeitet, davon 5 neue produktive Firmen und 1 dedupliziertes Update:

- `NanoTemper Technologies GmbH`
- `Mynaric AG`
- `Thoughtworks Deutschland GmbH`
- `IBM Deutschland GmbH` als Update
- `ZenML GmbH`
- `Tacto Technology GmbH`

Kennzahlen nach Welle AF:

- Store: `361` Firmen
- JobSources: `358`
- Source Coverage: `360` offizielle Quellen
- Karrierequellen: `359`
- Kandidatenqueue: `527` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1257` weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.1667`, `coverage_delta=5`

## Geaenderte Dateien und Artefakte

- `data/jobagent/company-discovery.official.wave-af-20260901.json`
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

Evidence aus Welle AF:

- `logs/jobagent/company-discovery-import-20260901-060824.json`
- `logs/jobagent/company-candidate-verification-20260901-060833.json`
- `logs/jobagent/company-coverage-20260901-060834.json`
- `logs/jobagent/company-coverage-20260901-060834.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260901T060825356Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-af-20260901.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AF -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-af-20260901.json -WaveId B` -> Exit `0`
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

## Naechste Aufgabe fuer neuen Agenten

1. `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 der Hotspot bleibt.
2. In `data/jobagent/company-candidate-verification.queue.json` Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Kandidaten mit hohem `priority_score`, belastbarem Muenchen-/Freising-Bezug und niedrigem Identitaetsrisiko bevorzugen.
4. Nur Kandidaten aufnehmen, deren `official_website_url` und `career_url` oder offiziell belegte ATS-Quelle per HTTP erreichbar sind.
5. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ag-YYYYMMDD.json` anlegen.
6. Supertest erst bei Abschluss von `JA-027` oder expliziter Nutzeranweisung ausfuehren.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil noch `1257` Kandidaten in manueller Website-/Scope-Pruefung stehen.
- Viele verbleibende Kandidaten koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.


