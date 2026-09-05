# Handoff latest

Stand: 2026-09-05T14:06:55+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: `D:\_Scripte\JobAgent`
- Branch: `master`, Upstream: `origin/master`
- HEAD vor diesem Handoff-Sync: `322329d Sync handoff after wave AZ`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Ebenfalls offen: `UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen`
- Roadmap-Rotation: nicht erfolgt. Kein Roadmap-Punkt ist komplett erledigt: `JA-027` bleibt aktiv, weil weiterhin 1132 Kandidaten fail-closed in manueller Website-/Scope-Pruefung stehen; `UI-001` ist ebenfalls offen.
- STP: `.\ci.cmd stp` lief erfolgreich am `2026-09-05T14:06:55+02:00`.
- Supertest: nicht neu ausgefuehrt. Laut aktueller Nutzeranweisung gilt ein nicht angefragter Supertest fuer diese Uebergabe als erledigt.

## Letzter Fachfortschritt

Welle AZ/B wurde abgeschlossen und im Commit `699cd79 Add verified company import wave AZ` gepusht. Der anschliessende Sync-Commit ist `322329d Sync handoff after wave AZ`. Neu produktiv aufgenommen wurden:

- toponauten GmbH
- Ohrbeit GmbH
- AV-Suite Veranstaltungstechnik GmbH
- Tresor TV Produktions GmbH
- Huntrees GmbH

Direkt davor wurde Welle AY/B ebenfalls abgeschlossen und gepusht. Neu produktiv aufgenommen wurden:

- hema.to GmbH
- Fold ecosystemics
- tiramizoo GmbH
- TikTok Germany GmbH
- Audi Business Innovation GmbH

Kennzahlen nach Welle AZ:

- Store: 469 Firmen
- JobSources: 429
- Source Coverage: 431 offizielle Quellen
- Karrierequellen: 430
- ATS-Quellen: 1
- Discovery Sources: 1820
- Kandidatenqueue: 652 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1132 mit manueller Website-/Scope-Pruefung
- Importwellen-Gate B: passed, `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=5`

## Versionierter Arbeitsstand

Fach-Commits:

- `64bee9f Add verified company import wave AY`
- `699cd79 Add verified company import wave AZ`

Sync-/Handoff-Commits:

- `3d330ee Sync handoff after wave AY`
- `322329d Sync handoff after wave AZ`

Dieser Handoff-Sync aktualisiert nur Uebergabe- und Todo-Artefakte:

- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Evidence Welle AZ

- `data/jobagent/company-discovery.official.wave-az-20260905.json`
- `logs/jobagent/company-discovery-import-20260905-115720.json`
- `logs/jobagent/company-candidate-verification-20260905-115725.json`
- `logs/jobagent/company-coverage-20260905-115838.json`
- `logs/jobagent/company-coverage-20260905-115838.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `data/jobagent/backups/store-20260905T115721390Z-pre-wave-import.json`
- `html/jobagent/company-coverage.html`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-viewport-800.png`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`

## Validierung Welle AZ

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-az-20260905.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` aus Welle AZ -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-az-20260905.json -WaveId B` -> Exit `0`
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
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit `1`
- `.\ci.cmd devserver-status` -> Exit `0`, Devserver lief auf Port 8500
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, SonarQube war `UP`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

`JA-027` mit Welle BA fortsetzen. Naechste Feed-Datei: `data/jobagent/company-discovery.official.wave-ba-20260905.json`.

Empfohlene Reihenfolge:

1. Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` mit `next_action == DISCOVER_OFFICIAL_WEBSITE`, niedrigem Risiko, hohem `priority_score` und belastbarem Muenchen-/Freising-Bezug auswaehlen.
2. Offizielle Firmenwebsite, Impressum-/Domainbeleg und Karriere-/Jobs-/ATS-Link fail-closed pruefen.
3. Feed im Format `jobagent/company-discovery-feed/v1` anlegen; keine Jobboersen-, Arbeitsagentur- oder Register-URL als produktive Karrierequelle verwenden.
4. Feed-JSON parsen und alle nicht-leeren `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest -Method Get` pruefen.
5. Import ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B`.
6. Kandidatenqueue refreshen: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`.
7. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`.
8. Source-Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
9. Funktionsbezogene Tests ausfuehren; Supertest nur bei expliziter Anforderung oder wenn `JA-027` komplett abgeschlossen wird.
10. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Punkte

- `JA-027` ist noch nicht abschliessbar, weil 1132 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- `UI-001` bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Drei AZ-Firmen wurden als offizielle Firmendomain ohne separate Karriere-URL importiert; das ist fuer Welle B erlaubt, erzeugt aber keine zusaetzliche scannbare Karrierequelle.
- Weitere Importwellen muessen fail-closed bleiben: keine erfundenen Firmen, keine Jobboersen-/Arbeitsagentur-/Register-URL als produktive Karrierequelle, keine automatische Bewerbung.
