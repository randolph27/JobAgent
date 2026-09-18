# Handoff latest

Stand: 2026-09-18T19:55:15.489+02:00

## Zustand

- Active: `TD-0083`
- Status: `in-progress`
- Ziel: M3 - Publikation und Gesamtabnahme: JA-054 Kalender fuer tatsaechliche Abrufe, geplante Pruefungen und eigene Termine anbieten #comment: Der Kalender macht Datenaktualisierung und persoenliche Fristen sichtbar, ohne geplante Abrufe als durchgefuehrte Scrapes auszugeben.
- Branch: `master`
- HEAD: `f4ef04dfa320`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `handoff.latest.detail.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-fixture-viewport-1366.png`
- `output/playwright/ja-022-fixture-viewport-1920.png`
- `output/playwright/ja-022-fixture-viewport-390.png`
- `output/playwright/ja-022-fixture-viewport-800.png`
- `output/playwright/ja-022-production-coverage-viewport-1366.png`
- `output/playwright/ja-022-production-coverage-viewport-1920.png`
- `output/playwright/ja-022-production-coverage-viewport-390.png`
- `output/playwright/ja-022-production-coverage-viewport-800.png`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.Operations.psm1`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentCoverage.ps1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentOperations.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Invoke-JobAgentDailyRun.ps1`
- `tools/Measure-JobAgentCompanyCoverage.ps1`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

M3 - Publikation und Gesamtabnahme: JA-056 Gespeicherte Suchauftraege und neue Treffer seit letzter Sichtung bereitstellen #comment: Wiederholbare Suchprofile und ein generationengebundener Treffervergleich sollen Sucharbeit sparen, ohne alte Jobs nach jedem Scrape erneut als neu auszugeben.
