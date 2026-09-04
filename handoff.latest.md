# Handoff latest

Stand: 2026-09-04T21:12:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor diesem Uebergabe-Commit: `8a4ac96 Import verified employers wave AV`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-04T21:09:19.471+02:00`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Uebergabeabschluss als erledigt.

## Letzter Fachfortschritt

Welle AV/B wurde abgeschlossen und bereits committed/gepusht in `8a4ac96`. Neu produktiv aufgenommen wurden:

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
- Discovery Sources/Hints gesamt: 1820
- Kandidatenqueue: 631 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1151 mit `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: 2 mit `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: 1 mit `MANUAL_DECISION`
- Importwellen-Gate B: passed
- Gate-Metriken Welle AV: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=6`

## Relevante Dateien

- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.official.wave-av-20260904.json`
- `html/jobagent/company-coverage.html`

## Evidence Welle AV

- `data/jobagent/company-discovery.official.wave-av-20260904.json`
- `logs/jobagent/company-discovery-import-20260904-185803.json`
- `logs/jobagent/company-candidate-verification-20260904-185809.json`
- `logs/jobagent/company-coverage-20260904-185921.json`
- `logs/jobagent/company-coverage-20260904-185921.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `data/jobagent/backups/store-20260904T185803845Z-pre-wave-import.json`
- `html/jobagent/company-coverage.html`
- `output/playwright/ja-022-viewport-800.png`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`

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

1. Startdateien erneut lesen: `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md`.
2. JA-027 fortsetzen; UI-001 nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
3. `data/jobagent/company-candidate-verification.queue.json` lesen und Kandidaten mit `next_action == DISCOVER_OFFICIAL_WEBSITE` priorisieren.
4. Bevorzugen: hoher `priority_score`, `risk_level == LOW`, belastbarer Muenchen-/Freising-Bezug, geringe Identitaets-/Dublettenunsicherheit.
5. Naechste Feed-Datei anlegen: `data/jobagent/company-discovery.official.wave-aw-20260904.json` oder bei neuem Datum entsprechend `wave-aw-<YYYYMMDD>.json`.
6. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
7. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
8. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
9. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B`.
10. Danach Queue aktualisieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`.
11. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`.
12. Source-Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
13. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder wenn JA-027 komplett abgeschlossen wird.
14. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- JA-027 ist noch nicht abschliessbar, weil 1151 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- itsmydata GmbH, Karevo GmbH, Latheca GmbH, Landschaftspflegeverband Freising e.V. und ALFA AI wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
- Externe Firmenwebsites koennen 403, Timeouts oder dynamische Karriereportale liefern; solche Kandidaten fail-closed belassen und nicht produktiv importieren.
