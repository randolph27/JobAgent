# Handoff latest

Stand: 2026-09-09T08:32:16.574+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager über vollständige Karriere- und ATS-Ergebnislisten finden #comment: Firmenlinks werden erst durch verlässliche Extraktion and passende Rollen-/Standortbewertung zu nutzbaren Stellenangeboten.
- Branch: `master`
- HEAD: `a92ec0268a24`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `docs/data-model.md`
- `docs/handoffs/2026-09-09-ja041-live-cli-iframe-handoff.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentLiveScan.ps1`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Invoke-JobAgentDailyRun.ps1`
- `tools/Invoke-JobAgentLivePilot.ps1`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`
- `curl.exe -s --max-time 5 http://localhost:9000/api/system/status` -> Exit `1`
- `cmd /c .\ci.cmd sonar-start` -> Exit `1`, `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`

## Naechster Anker

JA-041 fortsetzen: kontrollierten kleinen Live-Pilot ueber neuen Daily-CLI-/LivePilot-Einstieg ausfuehren, Artefakte auswerten und weitere ATS-/iframe-Faelle priorisieren.

## Detail-Handoff

- Vollstaendiger Uebergabeanker: `docs/handoffs/2026-09-09-ja041-live-cli-iframe-handoff.md`
- Roadmap-Rotation: keine; JA-041 bleibt offen, JA-027 bleibt offen.
- Supertest: vom Nutzer fuer diesen Uebergang als erledigt gewertet; nicht erneut ausgefuehrt.
