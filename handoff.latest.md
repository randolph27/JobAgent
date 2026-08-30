# Handoff latest

Stand: 2026-08-30T19:27:43.254+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: Aktive Punkte: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen #comment: Aus den Kandidaten werden erst dann Store-Firmen, wenn eine offizielle Firmenwebsite plus Jobs-/Karriere- oder belegte ATS-Quelle fail-closed verifiziert wurde.
- Branch: `master`
- HEAD: `9b1b92f7b307`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `tests/Test-JobAgentCoverage.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Measure-JobAgentCompanyCoverage.ps1`

## Verifikation

- `.\ci.cmd supertest` -> Exit `0`

## Naechster Anker


