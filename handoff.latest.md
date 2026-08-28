# Handoff latest

Stand: 2026-08-28T18:27:36.324+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027: offizielle Arbeitgeber-/Karriereverifikation und produktive Importwellen fortsetzen
- Branch: `master`
- HEAD: `36eb462ae616`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Ergebnis

- Welle D/B: 12 offiziell belegte Arbeitgeber verarbeitet, 11 neue Firmen, 1 dedupliziertes Update.
- Neu importiert: Europaeisches Patentamt, Hochschule Weihenstephan-Triesdorf, ADAC, Accenture, Adobe, Aenova Group, Agile Robots SE, ARRI, ams OSRAM, BayWa AG, Bayerische Versorgungskammer.
- Aktualisiert/dedupliziert: BayernLB auf bestehende Bayerische Landesbank.
- Store: 107 Firmen, 103 JobSources.
- Source Coverage: 1925 Quellen gesamt, 105 offizielle Quellen, 104 Karrierequellen.
- Astellas Pharma GmbH blieb fail-closed in `RETRY_SCHEDULED`; kein offizieller Karriere-/ATS-Link wurde belegt.

## Naechste Aufgabe

Naechste JA-027-Welle: weitere store-ferne Kandidaten priorisiert belegen; Astellas Pharma GmbH erst nach belastbarem offiziellen Karriere-/ATS-Beleg erneut verifizieren.

## Versionierte Aenderungen


- `Roadmap.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.official.wave-d-20260828.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-d-20260828.json -WaveId B` -> Exit `0`
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
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
