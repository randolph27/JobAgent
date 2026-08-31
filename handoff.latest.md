# Handoff latest

Stand: 2026-08-31T13:50:00.000+02:00

## Zustand fuer neuen Chat

- Active: TD-0041
- Status: in-progress
- Aktiver Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Ebenfalls offen: UI-001 Coverage- und Report-UI wie Stellenboerse lesbar machen
- Branch: master
- HEAD beim Handoff-Update: HEAD nach Commit `Add verified company import wave Y`
- Upstream: origin/master
- Fachcommit erstellt: HEAD `Add verified company import wave Y`
- Roadmap-Rotation: nicht erfolgt, weil kein aktiver Roadmap-Punkt komplett abgeschlossen ist.
- Supertest-Regel: gemaess Nutzeranweisung nicht ausgefuehrt, weil JA-027 insgesamt offen bleibt; funktionsbezogene Tests sind gruen.

## Letzter fachlicher Abschluss

JA-027 Welle Y/B-Import ist abgeschlossen.

Produktiv neu aufgenommen wurden 8 offiziell belegte Arbeitgeber:

- McKinsey & Company Inc.
- limango GmbH
- F. X. MEILLER Fahrzeug- und Maschinenfabrik GmbH & Co. KG
- Medien.Bayern GmbH
- Moderna
- LivaNova Deutschland GmbH
- megaherz GmbH
- MING Labs

Kennzahlen nach Welle Y:

- Store: 317 Firmen, 314 JobSources
- Source Coverage: 316 offizielle Quellen, 315 Karrierequellen
- Kandidatenqueue: 470 bereits produktiv verifiziert, 1314 weiter fail-closed in manueller Website-/Scope-Pruefung
- Importwellen-Gate B: passed, manual_review_rate=0.0, duplicate_rate=0.0, coverage_delta=8

## Geaenderte Artefakte

- Roadmap.md
- data/jobagent/company-discovery.official.wave-y-20260831.json
- data/jobagent/company-candidate-verification.queue.json
- data/jobagent/store.json
- html/jobagent/company-coverage.html
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- todo.state.json
- handoff.latest.md
- handoff.latest.json

## Evidence

- data/jobagent/company-discovery.official.wave-y-20260831.json
- logs/jobagent/company-discovery-import-20260831-112828.json
- logs/jobagent/company-candidate-verification-20260831-112836.json
- logs/jobagent/company-coverage-20260831-112836.json
- logs/jobagent/company-coverage-20260831-112836.md
- logs/jobagent/ja-023-source-coverage.json
- html/jobagent/company-coverage.html
- Store-Backup: data/jobagent/backups/store-20260831T112828747Z-pre-wave-import.json
- Viewport-Screenshots: output/playwright/ja-022-viewport-800.png, output/playwright/ja-022-viewport-1366.png, output/playwright/ja-022-viewport-1920.png

## Verifikation

- Get-Content -Raw data\jobagent\company-discovery.official.wave-y-20260831.json | ConvertFrom-Json -Depth 100 -> Exit 0
- Invoke-WebRequest fuer alle official_website_url/career_url/discovery_url aus Welle Y -> Exit 0
- pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-y-20260831.json -WaveId B -> Exit 0
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
- .\ci.cmd stp -> Exit 0
- SonarQube http://localhost:9000/api/system/status -> UP
- .\ci.cmd devserver-status -> Port 8500 laeuft

## Naechster Einstieg

1. JA-027 mit naechster offizieller Importwelle fortsetzen.
2. Kandidaten aus data/jobagent/company-candidate-verification.queue.json priorisieren, vorzugsweise DISCOVER_OFFICIAL_WEBSITE mit hohem priority_score und belastbarem Muenchen-/Freising-Bezug.
3. Nur Firmen mit offizieller Firmenwebsite plus offizieller Karriere-/Jobs-/ATS-Evidenz in data/jobagent/company-discovery.official.wave-z-YYYYMMDD.json aufnehmen.
4. Vor Import alle official_website_url, career_url und discovery_url per Invoke-WebRequest pruefen.
5. Import mit pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave> -WaveId B ausfuehren.
6. Danach Queue/Coverage/Source-Coverage aktualisieren und die funktionsbezogenen Tests laufen lassen.
7. Supertest erst bei komplettem Roadmap-Abschluss oder expliziter Nutzeranforderung erneut ausfuehren.
