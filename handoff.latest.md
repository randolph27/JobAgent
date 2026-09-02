# Handoff latest

Stand: 2026-09-02T18:51:03.361+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Aktueller HEAD vor finalem STP-Commit: `2445941 Sync handoff after wave AG`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. Kein Roadmap-Punkt ist komplett erledigt; `JA-027` und `UI-001` bleiben aktiv.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-02T18:51:03.361+02:00`.
- Supertest: wurde in diesem Chat nicht erneut angefragt und gilt gemaess Nutzeranweisung fuer diese Uebergabe als erledigt; letzter gespeicherter Verify-Digest ist weiterhin `.\ci.cmd supertest` -> Exit `0`.

## Aktueller Fachstand

`JA-027` wurde zuletzt mit Welle AG/B fortgesetzt. Welle AG hat 7 offiziell belegte Arbeitgeber produktiv neu aufgenommen:

- `nebumind GmbH`
- `Brainamics GmbH`
- `Nelhiebel Elektrotechnik GmbH`
- `Nuclino GmbH`
- `OCELL GmbH`
- `top.legal GmbH`
- `Travian Games GmbH`

Kennzahlen nach Welle AG:

- Store: `368` Firmen
- JobSources: `365`
- Source Coverage: `367` offizielle Quellen
- Karrierequellen: `366`
- Kandidatenqueue: `537` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1247` weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=7`

## Geaenderte Dateien und Artefakte seit Welle AG

Fachlicher Stand:

- `data/jobagent/company-discovery.official.wave-ag-20260902.json`
- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `logs/jobagent/ja-023-source-coverage.json`
- `Roadmap.md`

Uebergabe-/STP-Sync:

- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

Evidence:

- `logs/jobagent/company-discovery-import-20260902-164009.json`
- `logs/jobagent/company-candidate-verification-20260902-164018.json`
- `logs/jobagent/company-coverage-20260902-164208.json`
- `logs/jobagent/company-coverage-20260902-164208.md`
- Store-Backup: `data/jobagent/backups/store-20260902T164010548Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

Funktionstests aus Welle AG:

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ag-20260902.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AG -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ag-20260902.json -WaveId B` -> Exit `0`
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

Uebergabe-Checks:

- `.\ci.cmd devserver-status` -> Exit `0`, Devserver laeuft auf Projektport `8500`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube `UP`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe fuer neuen Agenten

1. `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 der Hotspot bleibt.
2. In `data/jobagent/company-candidate-verification.queue.json` Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Kandidaten mit hohem `priority_score`, belastbarem Muenchen-/Freising-Bezug und niedrigem Identitaetsrisiko bevorzugen.
4. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ah-YYYYMMDD.json` anlegen.
5. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
6. Nur Kandidaten aufnehmen, deren offizielle Website plus Karriere-URL oder offiziell belegte ATS-Quelle erreichbar ist.
7. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil noch `1247` Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` ist fachlich offen, aber nicht der aktuelle Hotspot.
- Viele verbleibende Kandidaten koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
- Projektkonfiguration nutzt Devserver-Port `8500`; der separat gepruefte Port `8090` war nicht belegt.
