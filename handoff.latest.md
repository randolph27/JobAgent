# Handoff latest

Stand: 2026-08-29T07:38:01.296+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027: offizielle Arbeitgeber-/Karriereverifikation und produktive Importwellen fortsetzen
- Branch: `master`
- HEAD: `efd555c46fda`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Ergebnis

- Welle F/B: 2 offiziell belegte Arbeitgeber neu produktiv importiert.
- Neu importiert: Astellas Pharma GmbH, LTIMindtree GmbH.
- Store: 115 Firmen, 111 JobSources.
- Source Coverage: 1933 Quellen gesamt, 113 offizielle Quellen, 112 Karrierequellen.
- Importwellen-Gate B bestanden: `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=2`.
- Kandidatenqueue: 189 verifizierte/store-aware Kandidaten, 1595 weiter fail-closed in manueller Website-/Scope-Pruefung.

## Naechste Aufgabe

Naechste JA-027-Welle: weitere store-ferne Kandidaten mit offizieller Firmenwebsite plus Karriere-/Jobs-/ATS-Beleg aufnehmen; Kandidaten ohne eindeutigen offiziellen Beleg bleiben in Review.

## Versionierte Aenderungen

- `Roadmap.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.official.wave-e-20260828.json`
- `data/jobagent/company-discovery.official.wave-f-20260829.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-f-20260829.json -WaveId B` -> Exit `0`
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
