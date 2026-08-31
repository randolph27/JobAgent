# Handoff latest

Stand: 2026-08-31T21:03:01.323+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Letzter fachlicher Commit: `4c25547 Add verified company import wave AB`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; kein Roadmap-Punkt ist komplett erledigt.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Uebergabeabschluss als erledigt.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-08-31T21:03:01.323+02:00`.
- Worktree-Ziel: diese Handoff-/STP-Aenderung committen und nach `origin/master` pushen.

## Aktueller Fachstand

JA-027 Welle AB/B-Import ist abgeschlossen und verifiziert. Welle AB hat 6 offiziell belegte Arbeitgeber verarbeitet:

- Neu produktiv aufgenommen: `metoda`
- Neu produktiv aufgenommen: `KREATIZE GmbH`
- Neu produktiv aufgenommen: `Intrinsic`
- Neu produktiv aufgenommen: `combyne`
- Neu produktiv aufgenommen: `DAIKIN Airconditioning Germany GmbH`
- Dedupliziertes Update: `E.ON Energy Projects GmbH` wurde wegen Domainmatch als Update zu `E.ON` verarbeitet.

Kennzahlen nach Welle AB:

- Store: `339` Firmen
- JobSources: `336`
- Source Coverage: `338` offizielle Quellen
- Karrierequellen: `337`
- Kandidatenqueue: `499` bereits produktiv verifiziert
- Kandidatenqueue: `1285` weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.1667`, `coverage_delta=5`

## Relevante Dateien und Artefakte

- `Roadmap.md`: `JA-027` enthaelt Fortschritt Welle AB; `UI-001` bleibt aktiv.
- `todo.current.md`: aktiver Eintrag `TD-0041`.
- `todo.state.json`: `active_id=TD-0041`, `checkpoint_event_id=EV-20260831-210301-2af22e`.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`: durch STP aktualisiert.
- `handoff.latest.md` und `handoff.latest.json`: dieser Uebergabestand.
- `data/jobagent/company-discovery.official.wave-ab-20260831.json`: offizieller Feed fuer Welle AB.
- `data/jobagent/company-candidate-verification.queue.json`: nach Welle AB aktualisierte Queue.
- `data/jobagent/store.json`: produktiver Store nach Welle AB.
- `html/jobagent/company-coverage.html`: aktualisierter Coverage-Report.
- `logs/todo/done-events-20260831-210301.jsonl`: STP-Rotation.

Evidence aus Welle AB:

- `logs/jobagent/company-discovery-import-20260831-185301.json`
- `logs/jobagent/company-candidate-verification-20260831-185307.json`
- `logs/jobagent/company-coverage-20260831-185405.json`
- `logs/jobagent/company-coverage-20260831-185405.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260831T185302431Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

Welle-AB-Funktionstests waren gruen:

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

## Naechste Aufgabe fuer neuen Agenten

1. Aktiven Punkt `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 der Hotspot bleibt.
2. In `data/jobagent/company-candidate-verification.queue.json` Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Bevorzugt Kandidaten mit hohem `priority_score`, belastbarem Muenchen-/Freising-Bezug und niedrigem Identitaetsrisiko aus offiziellen/regionalen Quellen nehmen.
4. Nur Kandidaten aufnehmen, deren `official_website_url` und `career_url` oder offiziell belegte ATS-Quelle per HTTP erreichbar sind.
5. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
6. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ac-YYYYMMDD.json` anlegen.
7. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest erst, wenn `JA-027` komplett abgeschlossen oder explizit angefragt ist. Wenn nicht explizit angefragt, gilt Supertest beim Uebergabeabschluss als erledigt.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil noch `1285` Kandidaten fail-closed in manueller Website-/Scope-Pruefung stehen.
- `UI-001` ist fachlich offen, soll aber erst nach dem aktuellen JA-027-Hotspot weitergefuehrt werden.
- Viele verbleibende Kandidaten koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
