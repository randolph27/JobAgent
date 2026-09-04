# Handoff latest

Stand: 2026-09-04T20:30:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Repo: https://github.com/randolph27/JobAgent
- Branch: master
- Upstream: origin/master
- HEAD vor Commit: 9e37e3b19d48
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: .\ci.cmd stp lief erfolgreich am 2026-09-04T20:27:33.233+02:00.
- Supertest: nicht ausgefuehrt, weil JA-027 insgesamt offen bleibt und der Nutzer funktionsbezogene Tests vor Supertest verlangt.

## Letzter abgeschlossener Fortschritt

Welle AT/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

- Wolt
- Zuehlke Engineering
- Trimble
- Quantumrock
- SUMM
- Sub Capitals
- Riscognition GmbH

Kennzahlen nach Welle AT:

- Store: 437 Firmen
- JobSources: 417
- Source Coverage: 419 offizielle Quellen
- Karrierequellen: 418
- ATS-Quellen: 1
- Discovery Sources/Hints gesamt: 1820
- Kandidatenqueue: 619 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1165 mit DISCOVER_OFFICIAL_WEBSITE
- Importwellen-Gate B: passed
- Gate-Metriken Welle AT: manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=7

## Geaenderte Dateien in Welle AT

- Roadmap.md
- data/jobagent/company-discovery.official.wave-at-20260904.json
- data/jobagent/company-candidate-verification.queue.json
- data/jobagent/store.json
- html/jobagent/company-coverage.html
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- handoff.latest.md
- handoff.latest.json

## Evidence

- data/jobagent/company-discovery.official.wave-at-20260904.json
- logs/jobagent/company-discovery-import-20260904-182211.json
- logs/jobagent/company-candidate-verification-20260904-182220.json
- logs/jobagent/company-coverage-20260904-182220.json
- logs/jobagent/company-coverage-20260904-182220.md
- logs/jobagent/ja-023-source-coverage.json
- data/jobagent/backups/store-20260904T182212658Z-pre-wave-import.json
- html/jobagent/company-coverage.html
- output/playwright/ja-022-viewport-800.png
- output/playwright/ja-022-viewport-1366.png
- output/playwright/ja-022-viewport-1920.png

## Verifikation Welle AT

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-at-20260904.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get fuer alle nicht-leeren official_website_url, career_url und discovery_url aus Welle AT` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-at-20260904.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd devserver-status` -> Exit `0`, Devserver laeuft auf Port 8500
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube ist `UP`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

1. JA-027 fortsetzen; UI-001 nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
2. Startdateien erneut lesen: README.md, Roadmap.md, todo.current.md, todo.state.json und handoff.latest.md.
3. data/jobagent/company-candidate-verification.queue.json lesen und Kandidaten mit next_action == DISCOVER_OFFICIAL_WEBSITE priorisieren.
4. Bevorzugen: hoher priority_score, risk_level == LOW, belastbarer Muenchen-/Freising-Bezug, geringe Identitaets-/Dublettenunsicherheit.
5. Naechste Feed-Datei anlegen: data/jobagent/company-discovery.official.wave-au-20260904.json oder naechster Kalendertag.
6. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
7. Vor Import alle nicht-leeren official_website_url, career_url und discovery_url per Invoke-WebRequest pruefen.
8. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
9. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B`.
10. Danach Queue aktualisieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`.
11. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`.
12. Source-Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
13. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder wenn JA-027 komplett abgeschlossen wird.
14. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- JA-027 ist noch nicht abschliessbar, weil 1165 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Quantumrock, SUMM, Sub Capitals und Riscognition wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
- Externe Firmenwebsites koennen 403, Timeouts oder dynamische Karriereportale liefern; solche Kandidaten fail-closed belassen und nicht produktiv importieren.
