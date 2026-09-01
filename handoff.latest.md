# Handoff latest

Stand: 2026-09-01T07:55:00+02:00

## Status fuer neuen Chat

- Projekt: `JobAgent`
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Letzter fachlicher Commit: `cf2ac2e Add verified company import wave AD`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt; kein Roadmap-Punkt ist komplett erledigt.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-01T07:46:25.170+02:00`.
- Supertest-Regel fuer Uebergabe: nicht erneut angefragt; gemaess Nutzeranweisung gilt der Supertest fuer diesen Slice als erledigt.

## Aktueller Fachstand

JA-027 wurde mit Welle AD/B fortgesetzt. Welle AD hat 6 offiziell belegte Arbeitgeber verarbeitet:

- Neu produktiv aufgenommen: `MSD Deutschland`
- Neu produktiv aufgenommen: `JANUS Productions GmbH`
- Neu produktiv aufgenommen: `Merkur tz MEDIA`
- Neu produktiv aufgenommen: `MicroGenesis TechSoft`
- Neu produktiv aufgenommen: `Fraunhofer-Gesellschaft`
- Dedupliziertes Update: `MGH Muenchner Gewerbehof- und Technologiezentrumsgesellschaft mbH` wurde wegen Domainmatch auf den bestehenden MGH-Eintrag gemappt.

Kennzahlen nach Welle AD:

- Store: `350` Firmen
- JobSources: `347`
- Source Coverage: `349` offizielle Quellen
- Karrierequellen: `348`
- Kandidatenqueue: `514` bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: `1268` weiter fail-closed in `DISCOVER_OFFICIAL_WEBSITE`
- Kandidatenqueue: `2` in `VERIFY_OFFICIAL_SITE`
- Kandidatenqueue: `1` in `MANUAL_DECISION`
- Importwellen-Gate B: `passed`
- Gate-Metriken: `manual_review_rate=0.0`, `duplicate_rate=0.1667`, `coverage_delta=5`

## Geaenderte Dateien und Artefakte

- `data/jobagent/company-discovery.official.wave-ad-20260901.json`: offizieller Feed fuer Welle AD.
- `data/jobagent/store.json`: produktiver Store nach Welle AD.
- `data/jobagent/company-candidate-verification.queue.json`: nach Welle AD aktualisierte Queue.
- `html/jobagent/company-coverage.html`: aktualisierter Coverage-Report.
- `logs/jobagent/ja-023-source-coverage.json`: aktualisierte Source-Coverage-Metriken.
- `Roadmap.md`: `JA-027` enthaelt Fortschritt Welle AD.
- `todo.current.md`: aktiver Eintrag bleibt `TD-0041`.
- `todo.state.json`: aktiver State bleibt `TD-0041`.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`: durch STP aktualisiert.
- `handoff.latest.md` und `handoff.latest.json`: dieser Uebergabestand.

Evidence aus Welle AD:

- `logs/jobagent/company-discovery-import-20260901-053852.json`
- `logs/jobagent/company-candidate-verification-20260901-053901.json`
- `logs/jobagent/company-coverage-20260901-053901.json`
- `logs/jobagent/company-coverage-20260901-053901.md`
- `logs/jobagent/ja-023-source-coverage.json`
- Store-Backup: `data/jobagent/backups/store-20260901T053852654Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

Welle-AD-Funktionstests waren gruen:

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-ad-20260901.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle AD -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-ad-20260901.json -WaveId B` -> Exit `0`
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
6. Naechste Feed-Datei im Stil `data/jobagent/company-discovery.official.wave-ae-YYYYMMDD.json` anlegen.
7. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen.
8. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-feed> -WaveId B`.
9. Danach Queue, Coverage und Source-Coverage aktualisieren.
10. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder Abschluss von `JA-027`. Wenn er nicht angefragt wurde, gilt er gemaess aktueller Nutzeranweisung als erledigt.
11. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Annahmen

- `JA-027` ist noch nicht abschliessbar, weil noch `1268` Kandidaten in `DISCOVER_OFFICIAL_WEBSITE` stehen.
- `UI-001` ist fachlich offen, soll aber erst nach dem aktuellen JA-027-Hotspot weitergefuehrt werden.
- Viele verbleibende Kandidaten koennen wegen uneindeutiger Namen, fehlender Karrierepfade, dynamischer ATS-Portale oder Aggregator-Treffern nicht automatisch importiert werden; fail-closed beibehalten.
