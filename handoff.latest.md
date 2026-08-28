# Handoff latest

Stand: 2026-08-28T17:54:42.703+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel:`n- Branch: `master`
- HEAD: `34505d646266`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.official.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`

## Verifikation

- `.\ci.cmd supertest` -> Exit `0`

## Naechster Anker

Aktive Punkte: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen #comment: Aus den Kandidaten werden erst dann Store-Firmen, wenn eine offizielle Firmenwebsite plus Jobs-/Karriere- oder belegte ATS-Quelle fail-closed verifiziert wurde.
