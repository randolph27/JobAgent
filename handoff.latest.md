# Handoff latest

Stand: 2026-09-03T11:55:30.000+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Commit/Push: `a924be493a0b`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` ist fachlich nicht komplett erledigt; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-03T11:54:21.395+02:00`.
- Supertest: gemaess Nutzeranweisung fuer diese Uebergabe als erledigt gewertet; kein neuer Supertest-Lauf in diesem Slice, weil `JA-027` weiter offen ist.

## Aktueller Fachstand

`JA-027` wurde mit Welle AI/B fortgesetzt. Welle AI hat 8 offiziell belegte Arbeitgeber verarbeitet:

- neu aufgenommen: `RTLZWEI Fernsehen GmbH & Co. KG`
- neu aufgenommen: `sewts GmbH`
- neu aufgenommen: `Schauburg - Theater fuer junges Publikum`
- neu aufgenommen: `Robotise Technologies GmbH`
- neu aufgenommen: `social sweethearts GmbH`
- neu aufgenommen: `Pina Earth`
- neu aufgenommen: `Smartlane GmbH`
- dedupliziertes Update: `Plan.Net Gruppe` wurde wegen `domain:house-of-communication.com` als Update zu `Serviceplan Gruppe SE & Co. KG` verarbeitet.

Kennzahlen nach Welle AI:

- Store: `380` Firmen
- JobSources: `376`
- Source Coverage: `378` offizielle Quellen
- Karrierequellen: `377`
- ATS-Quellen: `1`
- Discovery Sources/Hints gesamt: `1820`
- Kandidatenqueue: `550` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1234` mit manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken Welle AI: `manual_review_rate=0.0`, `duplicate_rate=0.125`, `coverage_delta=7`

## Geaenderte Dateien und Artefakte

Fachlicher Stand aus Welle AI:

- `data/jobagent/company-discovery.official.wave-ai-20260903.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `logs/jobagent/ja-023-source-coverage.json`
- `Roadmap.md`

Uebergabe-/STP-Sync:

- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

Evidence:

- `logs/jobagent/company-discovery-import-20260903-094445.json`
- `logs/jobagent/company-candidate-verification-20260903-094450.json`
- `logs/jobagent/company-coverage-20260903-094554.json`
- `logs/jobagent/company-coverage-20260903-094554.md`
- Store-Backup: `data/jobagent/backups/store-20260903T094446216Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation ausgefuehrt

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ai-20260903.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AI -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ai-20260903.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd devserver-status` -> Exit `0`, Devserver lief auf Projektport `8500`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube `UP`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe fuer neuen Agenten

1. `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 der aktive Hotspot bleibt.
2. `data/jobagent/company-candidate-verification.queue.json` lesen und Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Bevorzugen: hoher `priority_score`, `risk_level == "LOW"`, belastbarer Muenchen-/Freising-Bezug und geringe Identitaets-/Dublettenunsicherheit.
4. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-aj-YYYYMMDD.json` anlegen.
5. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
6. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
7. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil weiter viele Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` ist fachlich offen, aber aktuell nicht der Hotspot.
- Viele verbleibende Kandidaten sind vage OSM-/GitHub-/Regional-Hints oder koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
- Projektkonfiguration nutzt Devserver-Port `8500`; SonarQube laeuft auf `9000`.
