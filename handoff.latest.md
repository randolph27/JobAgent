# Handoff latest

Stand: 2026-08-30T14:11:11+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Roadmap: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- Upstream: `origin/master`
- Worktree: nach Stage/Commit/Push dieses Slices sauber zu erwarten
- Roadmap-Rotation: nicht rotiert, weil `JA-027` noch offen ist
- Supertest: nicht angefragt; gemaess Nutzeranweisung als erledigt gewertet

## Abgeschlossener Slice

Wave Q wurde als offizielle Importwelle abgeschlossen und produktiv importiert:

- Feed: `data/jobagent/company-discovery.official.wave-q-20260830.json`
- Import-Log: `logs/jobagent/company-discovery-import-20260830-115914.json`
- Pre-Import-Backup: `data/jobagent/backups/store-20260830T115915299Z-pre-wave-import.json`
- Coverage-Log: `logs/jobagent/company-coverage-20260830-120518.json`
- Coverage-Report: `logs/jobagent/company-coverage-20260830-120518.md`
- HTML-Report: `html/jobagent/company-coverage.html`

Produktiv neu hinzugefuegte, offiziell belegte Arbeitgeber:

- EY
- GEMA
- HCL Technologies GmbH
- HAWE Hydraulik SE
- HDI Global SE
- Heidelberg Materials
- FNZ Bank
- GE HealthCare
- GKN Aerospace
- FDG Entertainment GmbH & Co. KG
- givve
- Gini GmbH

## Metriken

- Store-Firmen: `230`
- JobSources: `226`
- Offizielle Quellen: `228`
- Karrierequellen: `227`
- Verifizierte Quellen: `228`
- Queue `verified/store-aware`: `354`
- Queue `DISCOVER_OFFICIAL_WEBSITE`: `1428`
- Queue `VERIFY_OFFICIAL_SITE`: `2`
- Queue `MANUAL_DECISION`: `1`
- Import-Gate Coverage-Delta: `12`
- Duplicate-Rate: `0.0`
- Manual-Review-Rate: `0.0`

## Verifikation

- JSON-Parsing des Wave-Q-Feeds: Exit `0`
- HTTP-Checks fuer alle `official_website_url`, `career_url`, `discovery_url`: Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-q-20260830.json -WaveId B`: Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`: Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`: Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1`: Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1`: Exit `0`
- `.\ci.cmd route-check`: Exit `0`
- `.\ci.cmd stp`: Exit `0`

## Naechster Arbeitsanker

Weiter mit `JA-027`: naechste offizielle Verifikations- und Importwelle aus `data/jobagent/company-candidate-verification.queue.json` priorisieren. Produktiv importieren nur bei offizieller Firmenwebsite plus Jobs-/Karriere- oder offiziell belegter ATS-Quelle. Jobboersen, Register und Verzeichnisse bleiben nur Discovery-Hinweise.

Empfohlene naechste Schritte:

1. Kandidaten mit Status `DISCOVER_OFFICIAL_WEBSITE` und `VERIFY_OFFICIAL_SITE` nach Prioritaet waehlen.
2. Offizielle Website, Karriere-/Jobs-Pfad und ggf. offiziell verlinkte ATS-Quelle live belegen.
3. Neue Wave-Feed-Datei erzeugen und Import-Gates laufen lassen.
4. Funktionstests fuer Import, Verification, Coverage, Report und Live-Scan ausfuehren.
5. Roadmap/Todo/Handoff/STP am Slice-Ende synchronisieren.
