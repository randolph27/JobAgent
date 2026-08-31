# Handoff latest

Stand: 2026-08-31T20:29:00.000+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Letzter fachlicher Fortschrittscommit: `7f93ff8 Add verified company import wave AA`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; kein Roadmap-Punkt ist komplett erledigt. `JA-027` und `UI-001` bleiben aktiv.
- Supertest: nicht neu ausgefuehrt; gemaess aktueller Nutzeranweisung gilt er fuer diesen Uebergabeabschluss als erledigt.
- STP: ausgefuehrt am `2026-08-31T20:28:32.335+02:00`; Todo-Compact/Prune/Rotate liefen erfolgreich.
- Worktree-Ziel: nach diesem Handoff committen und nach `origin/master` pushen.

## Aktueller Fachstand

JA-027 Welle AA/B-Import ist abgeschlossen und verifiziert. Welle AA hat 7 offiziell belegte Arbeitgeber produktiv aufgenommen:

- Cobrainer
- adnymics / ParcelDealz
- KontextMaps
- The Landbanking Group
- Hula Earth
- 95.5 Charivari
- Burger Rudacs Architekten

Kennzahlen nach Welle AA:

- Store: 334 Firmen
- JobSources: 331
- Source Coverage: 333 offizielle Quellen
- Karrierequellen: 332
- Kandidatenqueue: 492 bereits produktiv verifiziert
- Kandidatenqueue: 1292 weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=7`

## Relevante Dateien

- `Roadmap.md`: JA-027 enthaelt Fortschritt Welle AA; UI-001 bleibt offen.
- `todo.current.md`: aktiver Eintrag `TD-0041`.
- `todo.state.json`: `active_id=TD-0041`, `checkpoint_event_id=EV-20260831-202500-wave-aa`.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`: durch STP aktualisiert.
- `handoff.latest.md` und `handoff.latest.json`: dieser Uebergabestand.
- `data/jobagent/company-discovery.official.wave-aa-20260831.json`: offizieller Feed fuer Welle AA.
- `data/jobagent/company-candidate-verification.queue.json`: nach Welle AA aktualisierte Queue.
- `data/jobagent/store.json`: produktiver Store nach Welle AA.
- `html/jobagent/company-coverage.html`: aktualisierter Coverage-Report.

Evidence aus Welle AA:

- `logs/jobagent/company-discovery-import-20260831-181831.json`
- `logs/jobagent/company-candidate-verification-20260831-181836.json`
- `logs/jobagent/company-coverage-20260831-181935.json`
- `logs/jobagent/company-coverage-20260831-181935.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260831T181832252Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`
- STP-Rotation: `logs/todo/done-events-20260831-202832.jsonl`

## Verifikation

Welle-AA-Funktionstests waren gruen:

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-aa-20260831.json | ConvertFrom-Json -Depth 100` -> Exit 0
- `Invoke-WebRequest` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AA -> Exit 0
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-aa-20260831.json -WaveId B` -> Exit 0
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

1. Aktiven Punkt `JA-027` fortsetzen; `UI-001` bleibt offen und soll nicht parallel bearbeitet werden, solange JA-027 der Hotspot ist.
2. In `data/jobagent/company-candidate-verification.queue.json` nach `next_action == "DISCOVER_OFFICIAL_WEBSITE"`, hohem `priority_score` und belastbarem Muenchen-/Freising-Bezug priorisieren.
3. Nur Kandidaten aufnehmen, deren `official_website_url` und `career_url` oder offiziell belegte ATS-Quelle per HTTP erreichbar sind.
4. Keine Jobboersen-, Arbeitsagentur-, Register- oder Aggregator-URL als offizielle Karrierequelle verwenden.
5. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ab-YYYYMMDD.json` anlegen.
6. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
7. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
8. Danach Queue, Coverage und Source-Coverage aktualisieren.
9. Funktionsbezogene Tests ausfuehren; Supertest erst, wenn JA-027 komplett abgeschlossen oder explizit angefragt ist.
10. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.
