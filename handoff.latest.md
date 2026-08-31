# Handoff latest

Stand: 2026-08-31T14:04:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Fachlicher Fortschrittscommit: `cc935ed Add verified company import wave Z`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; `JA-027` und `UI-001` sind weiterhin offen.
- Supertest: nicht neu angefragt; gemaess Nutzeranweisung gilt er als erledigt. Funktionsbezogene Tests fuer Welle Z sind gruen.
- STP: ausgefuehrt am `2026-08-31T13:57:08.986+02:00`; Todo-Compact/Prune/Rotate liefen erfolgreich.

## Letzter fachlicher Fortschritt

JA-027 Welle Z/B-Import ist abgeschlossen und produktiv importiert.

Produktiv neu aufgenommen wurden 10 offiziell belegte Arbeitgeber:

- UnternehmerTUM
- Speexx
- Userlane
- SPORT1
- Plaion
- Robominds
- Willy Bogner
- Vinzenzmurr Vertriebs GmbH
- Valtech
- Samsung Semiconductors Europe

Kennzahlen nach Welle Z:

- Store: 327 Firmen
- JobSources: 324
- Source Coverage: 326 offizielle Quellen
- Karrierequellen: 325
- Kandidatenqueue: 484 bereits produktiv verifiziert
- Kandidatenqueue: 1300 weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=10`

## Wichtige Dateien

- `Roadmap.md`: JA-027 enthaelt Fortschritt Welle Z; UI-001 bleibt offen.
- `todo.current.md`: aktiver Eintrag `TD-0041`.
- `todo.state.json`: `active_id=TD-0041`, `checkpoint_event_id=EV-20260831-135000-wave-z`.
- `todo.events.jsonl`: STP-Event nach Welle Z vorhanden.
- `todo.history.digest.json` und `todo.master.index.json`: durch STP aktualisiert.
- `data/jobagent/company-discovery.official.wave-z-20260831.json`: importierter offizieller Feed.
- `data/jobagent/company-candidate-verification.queue.json`: nach Welle Z aktualisierte Queue.
- `data/jobagent/store.json`: produktiver Store nach Welle Z.
- `html/jobagent/company-coverage.html`: aktualisierter Coverage-Report.

## Evidence

- `data/jobagent/company-discovery.official.wave-z-20260831.json`
- `logs/jobagent/company-discovery-import-20260831-114708.json`
- `logs/jobagent/company-candidate-verification-20260831-114715.json`
- `logs/jobagent/company-coverage-20260831-114811.json`
- `logs/jobagent/company-coverage-20260831-114811.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260831T114708954Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`
- STP-Rotation: `logs/todo/done-events-20260831-135708.jsonl`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-z-20260831.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle Z -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-z-20260831.json -WaveId B` -> Exit 0
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit 1, erwarteter Kein-Treffer-Check
- `./ci.cmd stp` -> Exit 0

## Umgebung

- SonarQube: letzter Check vor Welle-Z-Abschluss meldete `UP` auf `http://localhost:9000`.
- Devserver: letzter Check meldete laufenden Server auf konfiguriertem Port `8500`.
- Hinweis: Nutzertext nennt teils Port `8090`; aktive Projektkonfiguration `.ci/ci.config.json` nutzt `8500`.

## Naechste Aufgabe

1. JA-027 mit naechster offizieller Importwelle fortsetzen.
2. Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` priorisieren: zuerst `DISCOVER_OFFICIAL_WEBSITE` mit hohem `priority_score` und belastbarem Muenchen-/Freising-Bezug.
3. Nur Firmen aufnehmen, wenn `official_website_url` plus offizielle `career_url` oder offiziell belegte ATS-Quelle belastbar per HTTP erreichbar sind.
4. Neue Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-aa-YYYYMMDD.json` anlegen.
5. Vor Import alle `official_website_url`, `career_url` und `discovery_url` mit `Invoke-WebRequest` pruefen.
6. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
7. Danach Queue, Coverage und Source-Coverage aktualisieren.
8. Funktionsbezogene Tests ausfuehren, Roadmap/Todo/Handoff/STP synchronisieren, stage/commit/push.
