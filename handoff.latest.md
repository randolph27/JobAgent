# Handoff latest

Stand: 2026-08-28T18:15:19.328+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027: offizielle Arbeitgeber-/Karriereverifikation und produktive Importwellen fortsetzen
- Branch: `master`
- HEAD vor Commit: `1a6116fac392`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `True`

## Ergebnis

- JA-027 bleibt aktiv; kein Roadmap-Rausrotieren, weil die Gesamtanforderung noch nicht komplett erledigt ist.
- Welle C/B: 9 offiziell belegte Arbeitgeber verarbeitet, 8 neue Firmen, 1 Update.
- Neu importiert: Bayerische Landesanstalt fuer Landwirtschaft, Bayerische Landesanstalt fuer Wald und Forstwirtschaft, Jungheinrich Moosburg GmbH, Hubert Burda Media Holding, IHK fuer Muenchen und Oberbayern, Telefonica Deutschland Holding AG, TUEV Sued AG, Technische Universitaet Muenchen.
- Aktualisiert: MAN Truck and Bus SE.
- Store: 96 Firmen, 92 JobSources.
- Source Coverage: 1914 Quellen gesamt, 94 offizielle Quellen, 93 Karrierequellen.
- Kandidatenqueue: Store-verifizierte Treffer werden als `ALREADY_VERIFIED_IN_STORE`/`VERIFIED` gefuehrt; erneute Website-Ermittlung wird dadurch nicht blockiert.

## Naechste Aufgabe

Naechste JA-027-Welle: weitere store-ferne Kandidaten mit offizieller Firmen-/Karrierequelle belegen oder fail-closed in Review lassen. Primaere Kandidaten: BMW Group, Europaeisches Patentamt, Hochschule Weihenstephan-Triesdorf, TUM School of Life Sciences und weitere hoch priorisierte Regional-/Register-Hints.

## Versionierte Aenderungen

- `Roadmap.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.official.wave-c-20260828.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.Coverage.psm1`
- `tests/Test-JobAgentCoverage.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Verify-JobAgentCompanyCandidates.ps1`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-c-20260828.json -WaveId B` -> Exit `0`
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
