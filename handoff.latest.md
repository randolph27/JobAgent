# Handoff latest

Stand: 2026-09-03T16:22:00.000+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD nach Push: `22080ddc2f9a`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` ist fachlich nicht komplett erledigt; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-03T16:17:43.017+02:00`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung erst bei expliziter Anforderung oder Abschluss von `JA-027`.

## Letzter abgeschlossener Fortschritt

Welle AL/B wurde abgeschlossen. Verarbeitet wurden 6 offiziell belegte Arbeitgeber:

- Neu produktiv aufgenommen: `Noventi Healthcare`, `GE Aerospace Advanced Technology`, `Philip Morris GmbH`, `Sueddeutsche Zeitung`
- Dedupliziert aktualisiert: `Muenchner Rueck AG` -> `Munich Re`, `Siemens Mobility` -> `Siemens AG`
- Commit/Push: `22080dd Import verified employers wave AL`

Kennzahlen nach Welle AL:

- Store: `395` Firmen
- JobSources: `391`
- Source Coverage: `393` offizielle Quellen
- Karrierequellen: `392`
- ATS-Quellen: `1`
- Discovery Sources/Hints gesamt: `1820`
- Kandidatenqueue: `573` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1209` mit `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: `2` mit `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: `1` mit `MANUAL_DECISION`
- Importwellen-Gate B: `passed`
- Gate-Metriken Welle AL: `manual_review_rate=0.0`, `duplicate_rate=0.3333`, `coverage_delta=4`

## Relevante Dateien und Artefakte

- `data/jobagent/company-discovery.official.wave-al-20260903.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `logs/jobagent/ja-023-source-coverage.json`
- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

Evidence:

- `logs/jobagent/company-discovery-import-20260903-141044.json`
- `logs/jobagent/company-candidate-verification-20260903-141052.json`
- `logs/jobagent/company-coverage-20260903-141155.json`
- `logs/jobagent/company-coverage-20260903-141155.md`
- Store-Backup: `data/jobagent/backups/store-20260903T141045320Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation des letzten Fachstands

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-al-20260903.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AL -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-al-20260903.json -WaveId B` -> Exit `0`
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
4. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-am-YYYYMMDD.json` anlegen.
5. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
6. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
7. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
8. Import ausfuehren, danach Queue, Coverage und Source-Coverage aktualisieren.
9. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
10. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil weiter viele Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` ist fachlich offen, aber aktuell nicht der Hotspot.
- Einige offizielle Konzernkarriereseiten fuehren zu Domain-Deduplizierungen statt neuen Store-Firmen; das ist akzeptiert, solange die Importwellen-Gates gruen bleiben und keine produktive Firma ohne offiziellen Beleg entsteht.
