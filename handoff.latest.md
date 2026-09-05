# Handoff latest

Stand: 2026-09-05T14:45:48+02:00

## Status fuer neuen Chat

- Projekt: JobAgent
- Workspace: D:\_Scripte\JobAgent
- Branch: master, Upstream: origin/master
- Aktiver Todo: TD-0041
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Letzter Fachstand: Welle BB/B abgeschlossen; Commit/Push erfolgt nach diesem Handoff.
- Supertest: nicht ausgefuehrt, weil JA-027 weiterhin offen ist und die Nutzeranweisung Supertest erst bei Roadmap-Abschluss vorsieht.
- Route-Check: .\ci.cmd route-check erfolgreich am 2026-09-05T14:43:24+02:00.
- STP-Lauf: .\ci.cmd stp erfolgreich am 2026-09-05T14:43:32+02:00; der dabei aus altem Verify-Digest uebernommene Supertest-Eintrag ist fuer diesen Slice nicht als neu ausgefuehrter Test zu werten.
- Roadmap-Rotation: nicht erfolgt. JA-027 bleibt wegen 1120 offenen manuellen Website-/Scope-Pruefungen aktiv; UI-001 bleibt ebenfalls aktiv.

## Letzter Fachfortschritt

Welle BB/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

- Airbus Defence & Space
- Bosch Building Automation GmbH
- Actemium
- Berylls Strategy
- BAYROL Deutschland GmbH

Kennzahlen nach Welle BB:

- Store: 479 Firmen
- JobSources: 439
- Source Coverage: 441 offizielle Quellen
- Karrierequellen: 440
- ATS-Quellen: 1
- Discovery Sources: 1820
- Kandidatenqueue: 662 bereits produktiv verifiziert oder im Store belegt
- Kandidatenqueue: 1120 mit manueller Website-/Scope-Pruefung
- Kandidatenqueue: 2 in VERIFY_OFFICIAL_SITE, 1 in MANUAL_DECISION
- Importwellen-Gate B: passed, manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=5

## Evidence Welle BB

- data/jobagent/company-discovery.official.wave-bb-20260905.json
- logs/jobagent/company-discovery-import-20260905-123442.json
- logs/jobagent/company-candidate-verification-20260905-123447.json
- logs/jobagent/company-coverage-20260905-123803.json
- logs/jobagent/company-coverage-20260905-123803.md
- logs/jobagent/ja-023-source-coverage.json
- data/jobagent/backups/store-20260905T123443301Z-pre-wave-import.json
- html/jobagent/company-coverage.html
- html/jobagent/ja-022-viewport-audit.html
- output/playwright/ja-022-viewport-800.png
- output/playwright/ja-022-viewport-1366.png
- output/playwright/ja-022-viewport-1920.png

## Validierung Welle BB

- Get-Content -Raw data\jobagent\company-discovery.official.wave-bb-20260905.json | ConvertFrom-Json -Depth 100 -> Exit 0
- Invoke-WebRequest -Method Get fuer alle nicht-leeren official_website_url, career_url und discovery_url aus Welle BB -> Exit 0
- pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-bb-20260905.json -WaveId B -> Exit 0
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
- .\ci.cmd devserver-status -> Exit 0, Devserver lief auf Port 8500
- Invoke-RestMethod http://localhost:9000/api/system/status -> Exit 0, SonarQube war UP
- .\ci.cmd route-check -> Exit 0
- .\ci.cmd stp -> Exit 0

## Naechste Aufgabe

JA-027 mit Welle BC fortsetzen. Naechste Feed-Datei: data/jobagent/company-discovery.official.wave-bc-20260905.json.

Empfohlene Reihenfolge:

1. Kandidaten aus data/jobagent/company-candidate-verification.queue.json mit next_action == DISCOVER_OFFICIAL_WEBSITE, niedrigem Risiko und belastbarem Muenchen-/Freising-Bezug auswaehlen.
2. Offizielle Firmenwebsite, Impressum-/Domainbeleg und Karriere-/Jobs-/ATS-Link fail-closed pruefen.
3. Feed im Format jobagent/company-discovery-feed/v1 anlegen; keine Jobboersen-, Arbeitsagentur- oder Register-URL als produktive Karrierequelle verwenden.
4. Feed-JSON parsen und alle nicht-leeren official_website_url, career_url und discovery_url per Invoke-WebRequest -Method Get pruefen.
5. Import, Kandidatenqueue-Refresh, Coverage, Source-Coverage und funktionsbezogene Tests ausfuehren.
6. Roadmap, Todo, Handoff und STP synchronisieren, dann stage/commit/push.

## Risiken und offene Punkte

- JA-027 ist noch nicht abschliessbar, weil 1120 Kandidaten in manueller Website-/Scope-Pruefung stehen.
- UI-001 bleibt offen, ist aber derzeit nicht der aktive Hotspot.
- Weitere Importwellen muessen fail-closed bleiben: keine erfundenen Firmen, keine Jobboersen-/Arbeitsagentur-/Register-URL als produktive Karrierequelle, keine automatische Bewerbung.
