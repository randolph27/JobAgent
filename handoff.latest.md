# Handoff latest

Stand: 2026-09-04T10:27:21.877+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Commit: `03e5be619c41`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. `JA-027` ist fachlich nicht komplett erledigt; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-04T10:27:21.877+02:00`.
- Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung erst bei Abschluss von `JA-027`.

## Letzter abgeschlossener Fortschritt

Welle AN/B wurde abgeschlossen. Verarbeitet wurden 5 offiziell belegte Arbeitgeber.

Neu produktiv aufgenommen wurden:

- `DeutschlandGPT`
- `Reply - Digital Experience`
- `MorphoSys AG`
- `Qlik Tech`

Dedupliziertes Update:

- `Capgemini Engineering` -> `Capgemini Deutschland GmbH` wegen Domainmatch `capgemini.com`

Kennzahlen nach Welle AN:

- Store: `403` Firmen
- JobSources: `399`
- Source Coverage: `401` offizielle Quellen
- Karrierequellen: `400`
- ATS-Quellen: `1`
- Discovery Sources/Hints gesamt: `1820`
- Kandidatenqueue: `583` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1199` mit `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: `2` mit `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: `1` mit `MANUAL_DECISION`
- Importwellen-Gate B: `passed`
- Gate-Metriken Welle AN: `manual_review_rate=0.0`, `duplicate_rate=0.2`, `coverage_delta=4`

## Geaenderte Dateien und Artefakte

- `data/jobagent/company-discovery.official.wave-an-20260904.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `Roadmap.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

Evidence:

- `logs/jobagent/company-discovery-import-20260904-082010.json`
- `logs/jobagent/company-candidate-verification-20260904-082017.json`
- `logs/jobagent/company-coverage-20260904-082130.json`
- `logs/jobagent/company-coverage-20260904-082130.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260904T082010746Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-an-20260904.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AN -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-an-20260904.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd devserver-status` -> Exit `0`, Devserver lief auf Projektport `8500`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube `UP`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

1. `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
2. `data/jobagent/company-candidate-verification.queue.json` lesen und Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Bevorzugen: hoher `priority_score`, `risk_level == "LOW"`, belastbarer Muenchen-/Freising-Bezug, geringe Identitaets-/Dublettenunsicherheit.
4. Naechste Feed-Datei anlegen: `data/jobagent/company-discovery.official.wave-ao-20260904.json`.
5. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
6. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
7. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ao-20260904.json -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- `JA-027` ist noch nicht abschliessbar, weil weiter viele Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Externe Firmenwebsites koennen 403, Timeouts oder dynamische Karriereportale liefern; solche Kandidaten fail-closed belassen und nicht produktiv importieren.
