# Handoff latest

Stand: 2026-09-04T15:58:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Repo: https://github.com/randolph27/JobAgent
- Branch: master
- Upstream: origin/master
- Letzter Fach-Commit vor dieser Welle: 3b0f35c
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Roadmap-Rotation: nicht erfolgt. JA-027 ist fachlich nicht komplett erledigt; UI-001 ist ebenfalls offen.
- STP: .\ci.cmd stp lief erfolgreich am 2026-09-04T15:55:05.756+02:00.
- Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung erst bei Roadmap-Abschluss oder expliziter Anfrage.

## Letzter abgeschlossener Fortschritt

Welle AR/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

- Infosys Ltd.
- jameda
- petaFuel GmbH
- Micro Fuzzy GmbH
- Intellias
- Presize.ai

Kennzahlen nach Welle AR:

- Store: 423 Firmen
- JobSources: 409
- Source Coverage: 411 offizielle Quellen
- Karrierequellen: 410
- ATS-Quellen: 1
- Discovery Sources/Hints gesamt: 1820
- Kandidatenqueue: 604 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1178 mit DISCOVER_OFFICIAL_WEBSITE
- Kandidatenqueue: 2 mit VERIFY_OFFICIAL_SITE
- Kandidatenqueue: 1 mit MANUAL_DECISION
- Importwellen-Gate B: passed
- Gate-Metriken Welle AR: manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=6

## Evidence

- data/jobagent/company-discovery.official.wave-ar-20260904.json
- logs/jobagent/company-discovery-import-20260904-134932.json
- logs/jobagent/company-candidate-verification-20260904-134943.json
- logs/jobagent/company-coverage-20260904-134944.json
- logs/jobagent/company-coverage-20260904-134944.md
- logs/jobagent/ja-023-source-coverage.json
- data/jobagent/backups/store-20260904T134933503Z-pre-wave-import.json
- html/jobagent/company-coverage.html
- output/playwright/ja-022-viewport-800.png
- output/playwright/ja-022-viewport-1366.png
- output/playwright/ja-022-viewport-1920.png

## Verifikation

- Get-Content -Raw data\jobagent\company-discovery.official.wave-ar-20260904.json | ConvertFrom-Json -Depth 100 -> Exit 0
- Invoke-WebRequest -Method Get fuer alle nicht-leeren official_website_url, career_url und discovery_url aus Welle AR -> Exit 0
- pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ar-20260904.json -WaveId B -> Exit 0
- pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5 -> Exit 0
- pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250 -> Exit 0
- pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1 -> Exit 0
- rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html -> Exit 1
- .\ci.cmd devserver-status -> Exit 0
- Invoke-RestMethod http://localhost:9000/api/system/status -> Exit 0
- .\ci.cmd stp -> Exit 0

## Naechste Aufgabe

1. JA-027 fortsetzen; UI-001 nicht parallel bearbeiten, solange JA-027 aktiver Hotspot bleibt.
2. data/jobagent/company-candidate-verification.queue.json lesen und Kandidaten mit next_action == DISCOVER_OFFICIAL_WEBSITE priorisieren.
3. Naechste Feed-Datei anlegen: data/jobagent/company-discovery.official.wave-as-20260904.json oder naechster Kalendertag.
4. Pro Kandidat offizielle Firmenwebsite plus Karriere-URL oder offiziell von der Firmenwebsite belegte ATS-Quelle pruefen.
5. Vor Import alle nicht-leeren official_website_url, career_url und discovery_url per Invoke-WebRequest pruefen.
6. Import, Queue, Coverage, Source-Coverage und funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anfrage oder Roadmap-Abschluss.
7. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und Annahmen

- JA-027 ist noch nicht abschliessbar, weil 1178 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- jameda, Micro Fuzzy und Intellias wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare JobSource.
- Presize.ai wurde ueber eine erreichbare Freshteam-Karriereseite importiert, weil die Hauptdomain lokal nicht belastbar abrufbar war.
