# Handoff latest

Stand: 2026-09-01T08:01:46.700+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Letzter fachlicher Commit: `236d939 Add verified company import wave AE`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; kein Roadmap-Punkt ist komplett erledigt.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-01T08:01:46.700+02:00`.
- Supertest: nicht erneut angefragt; gemaess Nutzeranweisung gilt er fuer diese Uebergabe als erledigt.

## Aktueller Fachstand

JA-027 wurde zuletzt mit Welle AE/B fortgesetzt. Welle AE hat 6 offiziell belegte Arbeitgeber produktiv neu aufgenommen:

- `Smart Reporting GmbH`
- `VEACT GmbH`
- `Shore GmbH`
- `remote control productions GmbH`
- `Retorio GmbH`
- `Scandic Hotels Deutschland GmbH`

Kennzahlen nach Welle AE:

- Store: `356` Firmen
- JobSources: `353`
- Source Coverage: `355` offizielle Quellen
- Karrierequellen: `354`
- Kandidatenqueue: `520` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1264` weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=6`

## Geaenderte Dateien und Artefakte

Fachlicher Stand aus Welle AE:

- `data/jobagent/company-discovery.official.wave-ae-20260901.json`
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

Evidence aus Welle AE:

- `logs/jobagent/company-discovery-import-20260901-055239.json`
- `logs/jobagent/company-candidate-verification-20260901-055245.json`
- `logs/jobagent/company-coverage-20260901-055345.json`
- `logs/jobagent/company-coverage-20260901-055345.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260901T055240447Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

Welle-AE-Funktionstests waren gruen:

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ae-20260901.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AE -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ae-20260901.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe fuer neuen Agenten

1. Aktiven Punkt `JA-027` fortsetzen; `UI-001` nicht parallel bearbeiten, solange JA-027 der Hotspot bleibt.
2. In `data/jobagent/company-candidate-verification.queue.json` Kandidaten mit `next_action == "DISCOVER_OFFICIAL_WEBSITE"` priorisieren.
3. Kandidaten mit hohem `priority_score`, belastbarem Muenchen-/Freising-Bezug und niedrigem Identitaetsrisiko bevorzugen.
4. Nur Kandidaten aufnehmen, deren `official_website_url` und `career_url` oder offiziell belegte ATS-Quelle per HTTP erreichbar sind.
5. Keine Jobboersen-, Arbeitsagentur-, Register-, LinkedIn-, Xing-, Kununu-, Glassdoor- oder Aggregator-URL als offizielle Karrierequelle verwenden.
6. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-af-YYYYMMDD.json` anlegen.
7. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil noch `1264` Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` ist fachlich offen, aber nicht der aktuelle Hotspot.
- Viele verbleibende Kandidaten koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
