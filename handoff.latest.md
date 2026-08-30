# Handoff latest

Stand: 2026-08-30T14:31:00+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Active Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Status: `in-progress`
- Branch: `master`
- Upstream: `origin/master`
- Letzter Feature-Commit vor Handoff: `e4a9bc24326c` (`JA-027 import official company wave R`)
- Roadmap-Rotation: nicht ausgefuehrt, weil `JA-027` noch nicht komplett erledigt ist.
- Supertest: nicht erneut angefragt; gemaess Nutzeranweisung als erledigt gewertet.

## Letzter abgeschlossener Fortschritt

Wave R/B wurde als offizieller Import-Slice abgeschlossen. Der Feed `data/jobagent/company-discovery.official.wave-r-20260830.json` wurde live per HTTP geprueft, importiert und ueber Import-Gate B validiert.

Produktiv neu hinzugefuegte, offiziell belegte Arbeitgeber:

- Holidu GmbH
- IBM Deutschland GmbH
- Interhyp AG
- iteratec GmbH
- jambit GmbH
- JetBrains GmbH
- Helbling Technik GmbH
- HELDELE GmbH
- Hugendubel Digital GmbH & Co. KG
- IABG Industrieanlagen-Betriebsgesellschaft mbH
- ImFusion GmbH
- KGAL GmbH & Co. KG

## Aktuelle Kennzahlen nach Wave R

- Store-Firmen: `242`
- JobSources: `238`
- Offizielle Quellen: `240`
- Karrierequellen: `239`
- Verifizierte Quellen: `240`
- Queue `verified/store-aware`: `368`
- Queue `DISCOVER_OFFICIAL_WEBSITE`: `1414`
- Queue `VERIFY_OFFICIAL_SITE`: `2`
- Queue `MANUAL_DECISION`: `1`
- Queue `RETRY_EXHAUSTED`: `1`
- Import-Gate Coverage-Delta: `12`
- Duplicate-Rate: `0.0`
- Manual-Review-Rate: `0.0`

## Relevante Artefakte

- Feed: `data/jobagent/company-discovery.official.wave-r-20260830.json`
- Import-Log: `logs/jobagent/company-discovery-import-20260830-122057.json`
- Pre-Import-Backup: `data/jobagent/backups/store-20260830T122058281Z-pre-wave-import.json`
- Candidate-Verification-Log: `logs/jobagent/company-candidate-verification-20260830-122103.json`
- Coverage-Log: `logs/jobagent/company-coverage-20260830-122149.json`
- Coverage-Report: `logs/jobagent/company-coverage-20260830-122149.md`
- Source-Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML-Report: `html/jobagent/company-coverage.html`
- Viewport-Audit: `html/jobagent/ja-022-viewport-audit.html`

## Verifikation im letzten Slice

Alle folgenden Commands liefen erfolgreich mit Exit `0`:

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-r-20260830.json | ConvertFrom-Json -Depth 100`
- HTTP-Checks fuer alle `official_website_url`, `career_url`, `discovery_url` aus Wave R
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-r-20260830.json -WaveId B`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1`
- `./ci.cmd route-check`
- `./ci.cmd stp`

## Aufgaben fuer den naechsten Chat

1. Weiter an `JA-027`, keine Roadmap-Rotation vor Gesamtabschluss.
2. Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` priorisieren, primaer `DISCOVER_OFFICIAL_WEBSITE`, danach `VERIFY_OFFICIAL_SITE`.
3. Pro Kandidat nur offizielle Firmenwebsite plus Jobs-/Karriere-Seite oder offiziell von der Firmenwebsite belegten ATS-Link akzeptieren.
4. Jobboersen, Register, GitHub-/Regionalverzeichnisse und Arbeitsagentur bleiben nur Discovery-Hinweise, nie Primaerbeleg fuer produktive Aufnahme.
5. Bei unklarem Domain-, Marken-, Konzern- oder Standortbezug fail-closed lassen: `MANUAL_REVIEW_REQUIRED`, `MANUAL_DECISION`, `RETRY_REQUIRED` oder `RETRY_EXHAUSTED`.
6. Naechste Wave-Datei nach Muster `data/jobagent/company-discovery.official.wave-s-20260830.json` oder mit aktuellem Datum erzeugen.
7. Vor Import alle `official_website_url`, `career_url` und `discovery_url` der Wave per HTTP pruefen.
8. Import mit `tools/Import-JobAgentCompanyDiscovery.ps1 -WaveId B` ausfuehren, danach Candidate Queue und Coverage nachziehen.
9. Funktionstests wie im letzten Slice ausfuehren; Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung, andernfalls als erledigt werten.
10. Am Ende Roadmap, Todo, Handoff und STP synchronisieren; stage, commit und push ausfuehren.

## Risiken und No-Gos

- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Keine produktive Firma ohne offiziellen finalen URL-Nachweis.
- Keine globalen ATS-Allowlist-Annahmen ohne Firmenbeleg.
- Keine externe Bewerbung oder extern wirksame Aktion.
- Keine Secrets in Reports, Logs, Todo, Handoff oder Git.