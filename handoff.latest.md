# Handoff latest

Stand: 2026-09-04T11:15:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Repo: https://github.com/randolph27/JobAgent
- Branch: master
- Upstream: origin/master
- Letzter Fach-Commit: 01dcb48 Import verified employers wave AP
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am 2026-09-04T11:12:55.976+02:00.
- Supertest: nicht neu ausgefuehrt und gemaess aktueller Nutzeranweisung als erledigt behandelt, solange er nicht explizit angefragt wird.

## Letzter abgeschlossener Fortschritt

Welle AP/B wurde abgeschlossen. Verarbeitet wurden 5 offiziell belegte Arbeitgeber.

Neu produktiv aufgenommen wurden:

- ParkHere GmbH
- Curiosity
- ICAROS GmbH
- German Accelerator
- Hyphe

Deduplizierte Updates: keine.

Kennzahlen nach Welle AP:

- Store: 413 Firmen
- JobSources: 404
- Source Coverage: 406 offizielle Quellen
- Karrierequellen: 405
- ATS-Quellen: 1
- Discovery Sources/Hints gesamt: 1820
- Kandidatenqueue: 593 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1191 mit DISCOVER_OFFICIAL_WEBSITE
- Kandidatenqueue: 1 mit MANUAL_DECISION
- Importwellen-Gate B: passed
- Gate-Metriken Welle AP: manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=5

## Geaenderte Dateien im letzten Fach-Commit

- data/jobagent/company-discovery.official.wave-ap-20260904.json
- data/jobagent/store.json
- data/jobagent/company-candidate-verification.queue.json
- html/jobagent/company-coverage.html
- Roadmap.md
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- handoff.latest.md
- handoff.latest.json

Aktueller Uebergabe-Sync enthaelt nur STP-/Handoff-Artefakte:

- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- handoff.latest.md
- handoff.latest.json

## Evidence

- logs/jobagent/company-discovery-import-20260904-090214.json
- logs/jobagent/company-candidate-verification-20260904-090224.json
- logs/jobagent/company-coverage-20260904-090333.json
- logs/jobagent/company-coverage-20260904-090333.md
- logs/jobagent/ja-023-source-coverage.json
- Store-Backup: data/jobagent/backups/store-20260904T090215185Z-pre-wave-import.json
- Viewport-Screenshots: output/playwright/ja-022-viewport-800.png, output/playwright/ja-022-viewport-1366.png, output/playwright/ja-022-viewport-1920.png

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ap-20260904.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren official_website_url, career_url und discovery_url aus Welle AP -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ap-20260904.json -WaveId B` -> Exit 0
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit 1
- `.\ci.cmd devserver-status` -> Exit 0, Devserver lief auf Port 8500
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit 0, SonarQube UP
- `.\ci.cmd stp` -> Exit 0

## Naechste Aufgabe

1. JA-027 fortsetzen; UI-001 nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
2. Zu Beginn erneut `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json` und `handoff.latest.md` lesen.
3. `data/jobagent/company-candidate-verification.queue.json` lesen und Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
4. Bevorzugen: hoher `priority_score`, `risk_level == "LOW"`, belastbarer Muenchen-/Freising-Bezug, geringe Identitaets-/Dublettenunsicherheit.
5. Naechste Feed-Datei anlegen: `data/jobagent/company-discovery.official.wave-aq-20260904.json`.
6. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
7. Bei nur belegter Firmendomain ist `career_url: null` erlaubt, wenn Welle B das akzeptiert; das erzeugt dann keine zusaetzliche scannbare JobSource.
8. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
9. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
10. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-aq-20260904.json -WaveId B`.
11. Danach Queue aktualisieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`.
12. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`.
13. Source-Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
14. Funktionsbezogene Tests ausfuehren; Supertest nicht ausfuehren, sofern nicht explizit angefragt.
15. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- JA-027 ist noch nicht abschliessbar, weil 1191 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Curiosity, ICAROS GmbH, German Accelerator und Hyphe wurden als offizielle Firmendomain ohne Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare JobSource.
- Externe Firmenwebsites koennen 403, Timeouts oder dynamische Karriereportale liefern; solche Kandidaten fail-closed belassen und nicht produktiv importieren.
- SonarQube lief zuletzt auf `http://localhost:9000` mit Status `UP`; Devserver lief zuletzt auf Port `8500`.
