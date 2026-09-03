# Handoff latest

Stand: 2026-09-03T11:07:49.122+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD bei Handoff-Erstellung: `b26fc3c82287`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` ist fachlich nicht komplett erledigt; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-03T11:07:49.122+02:00`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diese Uebergabe als erledigt.

## Aktueller Fachstand

`JA-027` wurde zuletzt mit Welle AH/B fortgesetzt. Welle AH hat 5 offiziell belegte Arbeitgeber produktiv neu aufgenommen:

- `Neovii Biotech GmbH`
- `Muenchner Hybrid Systemtechnik GmbH`
- `Hyperganic`
- `dstack.ai`
- `Datarella`

Kennzahlen nach Welle AH:

- Store: `373` Firmen
- JobSources: `369`
- Source Coverage: `371` offizielle Quellen
- Karrierequellen: `370`
- ATS-Quellen: `1`
- Discovery Sources/Hints gesamt: `1820`
- Kandidatenqueue: `542` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1240` mit `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: `2` mit `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: `1` mit `MANUAL_DECISION`
- Importwellen-Gate B: `passed`
- Gate-Metriken Welle AH: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=5`

## Geaenderte Dateien und Artefakte

Fachlicher Stand aus Welle AH:

- `data/jobagent/company-discovery.official.wave-ah-20260903.json`
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

- `logs/jobagent/company-discovery-import-20260903-085420.json`
- `logs/jobagent/company-candidate-verification-20260903-085431.json`
- `logs/jobagent/company-coverage-20260903-085533.json`
- `logs/jobagent/company-coverage-20260903-085533.md`
- Store-Backup: `data/jobagent/backups/store-20260903T085421198Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation zuletzt ausgefuehrt

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ah-20260903.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`/`career_url`/`discovery_url` aus Welle AH -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ah-20260903.json -WaveId B` -> Exit `0`
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
3. Bevorzugen: hoher `priority_score`, `risk_level == "LOW"`, belastbarer Muenchen-/Freising-Bezug (`REGISTER_SEAT_IN_TARGET`, `BRANCH_HINT_IN_TARGET` oder `JOB_LOCATION_IN_TARGET`) und geringe Identitaets-/Dublettenunsicherheit.
4. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ai-YYYYMMDD.json` anlegen.
5. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
6. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
7. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil weiter `1240` Kandidaten in `DISCOVER_OFFICIAL_WEBSITE` stehen.
- `UI-001` ist fachlich offen, aber aktuell nicht der Hotspot.
- Viele verbleibende Kandidaten sind vage OSM-/GitHub-/Regional-Hints oder koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
- Projektkonfiguration nutzt Devserver-Port `8500`; SonarQube laeuft auf `9000`.
