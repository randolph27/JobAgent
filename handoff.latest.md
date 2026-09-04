# Handoff latest

Stand: 2026-09-04T15:50:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Repo: https://github.com/randolph27/JobAgent
- Branch: master
- Upstream: origin/master
- Letzter Fach-Commit: f7540fc Import verified employers wave AQ
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am 2026-09-04T15:40:27.865+02:00.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Uebergabeabschluss als erledigt.

## Letzter abgeschlossener Fortschritt

Welle AQ/B wurde abgeschlossen. Verarbeitet wurden 5 offiziell belegte Arbeitgeber.

Neu produktiv aufgenommen wurden:

- VISTA Remote Sensing
- UX3D GmbH
- MEAG
- The Boston Consulting Group GmbH

Dedupliziertes Update:

- UniCredit -> HypoVereinsbank

Kennzahlen nach Welle AQ:

- Store: 417 Firmen
- JobSources: 406
- Source Coverage: 408 offizielle Quellen
- Karrierequellen: 407
- ATS-Quellen: 1
- Discovery Sources/Hints gesamt: 1820
- Kandidatenqueue: 598 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1184 mit `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: 2 mit `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: 1 mit `MANUAL_DECISION`
- Importwellen-Gate B: passed
- Gate-Metriken Welle AQ: `manual_review_rate=0.0`, `duplicate_rate=0.2`, `coverage_delta=4`

## Geaenderte Dateien im letzten Fach-Commit

- Roadmap.md
- data/jobagent/company-discovery.official.wave-aq-20260904.json
- data/jobagent/company-candidate-verification.queue.json
- data/jobagent/store.json
- html/jobagent/company-coverage.html
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- todo.state.json
- handoff.latest.md
- handoff.latest.json

Aktueller Uebergabe-Sync nach STP enthaelt nur Todo-/Handoff-Artefakte:

- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- todo.state.json
- handoff.latest.md
- handoff.latest.json

## Evidence

- data/jobagent/company-discovery.official.wave-aq-20260904.json
- logs/jobagent/company-discovery-import-20260904-132913.json
- logs/jobagent/company-candidate-verification-20260904-132918.json
- logs/jobagent/company-coverage-20260904-133033.json
- logs/jobagent/company-coverage-20260904-133033.md
- logs/jobagent/ja-023-source-coverage.json
- data/jobagent/backups/store-20260904T132914460Z-pre-wave-import.json
- html/jobagent/company-coverage.html
- output/playwright/ja-022-viewport-800.png
- output/playwright/ja-022-viewport-1366.png
- output/playwright/ja-022-viewport-1920.png

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-aq-20260904.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AQ -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-aq-20260904.json -WaveId B` -> Exit 0
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
- `.\ci.cmd devserver-status` -> Exit 0, Devserver laeuft auf Port 8500
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit 0, SonarQube `UP`
- `.\ci.cmd stp` -> Exit 0

## Naechste Aufgabe

1. JA-027 fortsetzen; UI-001 nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
2. Zu Beginn erneut `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json` und `handoff.latest.md` lesen.
3. `data/jobagent/company-candidate-verification.queue.json` lesen und Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
4. Bevorzugen: hoher `priority_score`, `risk_level == "LOW"`, belastbarer Muenchen-/Freising-Bezug, geringe Identitaets-/Dublettenunsicherheit.
5. Naechste Feed-Datei anlegen: `data/jobagent/company-discovery.official.wave-ar-20260904.json`.
6. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
7. Vor Import alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
8. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
9. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ar-20260904.json -WaveId B`.
10. Danach Queue aktualisieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`.
11. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`.
12. Source-Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
13. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anfrage oder bei Roadmap-Abschluss.
14. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- JA-027 ist noch nicht abschliessbar, weil 1184 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- UX3D GmbH und MEAG wurden als offizielle Firmendomain ohne Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare JobSource.
- BCG wurde ueber die offizielle BCG-Careers-Domain belegt; die Hauptdomain lieferte in der lokalen Pruefung 403 und wurde deshalb nicht als zu pruefende Feed-URL eingetragen.
- Externe Firmenwebsites koennen 403, Timeouts oder dynamische Karriereportale liefern; solche Kandidaten fail-closed belassen und nicht produktiv importieren.
