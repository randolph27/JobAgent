# Handoff latest

Stand: 2026-08-31T21:01:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Abschlusscommit: `8214d068b631`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; `JA-027` und `UI-001` bleiben aktiv.
- Supertest: nicht ausgefuehrt, weil `JA-027` insgesamt offen bleibt.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-08-31T20:59:36.909+02:00`; anschliessend wurde der fachliche Welle-AB-Event `EV-20260831-210100-wave-ab` ergaenzt.

## Aktueller Fachstand

JA-027 Welle AB/B-Import ist abgeschlossen und verifiziert. Welle AB hat 6 offiziell belegte Arbeitgeber verarbeitet:

- Neu produktiv aufgenommen: metoda, KREATIZE GmbH, Intrinsic, combyne, DAIKIN Airconditioning Germany GmbH
- Dedupliziertes Update: E.ON Energy Projects GmbH -> E.ON

Kennzahlen nach Welle AB:

- Store: 339 Firmen
- JobSources: 336
- Source Coverage: 338 offizielle Quellen
- Karrierequellen: 337
- Kandidatenqueue: 499 bereits produktiv verifiziert
- Kandidatenqueue: 1285 weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.1667`, `coverage_delta=5`

## Relevante Dateien

- `Roadmap.md`: JA-027 enthaelt Fortschritt Welle AB; UI-001 bleibt offen.
- `todo.current.md`: aktiver Eintrag `TD-0041`.
- `todo.state.json`: `active_id=TD-0041`, `checkpoint_event_id=EV-20260831-210100-wave-ab`.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`: STP plus Welle-AB-Event aktualisiert.
- `handoff.latest.md` und `handoff.latest.json`: dieser Uebergabestand.
- `data/jobagent/company-discovery.official.wave-ab-20260831.json`: offizieller Feed fuer Welle AB.
- `data/jobagent/company-candidate-verification.queue.json`: nach Welle AB aktualisierte Queue.
- `data/jobagent/store.json`: produktiver Store nach Welle AB.
- `html/jobagent/company-coverage.html`: aktualisierter Coverage-Report.

Evidence aus Welle AB:

- `logs/jobagent/company-discovery-import-20260831-185301.json`
- `logs/jobagent/company-candidate-verification-20260831-185307.json`
- `logs/jobagent/company-coverage-20260831-185405.json`
- `logs/jobagent/company-coverage-20260831-185405.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260831T185302431Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ab-20260831.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AB -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ab-20260831.json -WaveId B` -> Exit 0
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
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit 1, erwarteter Kein-Treffer-Check
- `.\ci.cmd devserver-status` -> Exit 0, Port `8500` listening
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit 0, SonarQube `UP`
- `.\ci.cmd stp` -> Exit 0

## Naechste Aufgabe

`JA-027` fortsetzen: in `data/jobagent/company-candidate-verification.queue.json` weitere Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren, nur mit erreichbarer offizieller Website plus Karriere-/ATS-Beleg in `data/jobagent/company-discovery.official.wave-ac-YYYYMMDD.json` aufnehmen, dann Import, Coverage, Funktionstests, Handoff und Commit/Push abschliessen.
