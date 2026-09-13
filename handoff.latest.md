# Handoff latest

Stand: 2026-09-13T03:15:30.000+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- Branch: `master`
- HEAD: `fc4677b032ed`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Abgeschlossener Slice

JA-041 Avature-Budget und BMW-Erreichbarkeit:

- Siemens Energy/Avature wurde mit breitem Budget reproduzierbar abgeschlossen.
- Kontrolllauf `logs/jobagent/daily-run-20260913T010421462Z.json`: `SUCCESS`, 1 Firma, 30 Raw-Jobs, 1 gepruefter Snapshot, 0 unsichere Quellen, 0 nicht erreichbare Quellen, 0 Fehler, 0 Zielrollentreffer.
- Verwendete Parameter: `-MaxPagesPerSource 100 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -FetchClient auto`.
- BMW-Erreichbarkeit wurde separat reproduziert: `logs/jobagent/daily-run-20260913T010245703Z.json` bleibt `FAILED`, `NOT_REACHABLE`, weil `curl.exe` fuer `https://www.bmwgroup.jobs/de/en.html` mit HTTP/2-Streamfehler beziehungsweise lokalem Schannel-Fehler `SEC_E_NO_CREDENTIALS` scheitert.
- WSL-Fallback ist aktuell nicht nutzbar; `Ubuntu-22.04` ist auf diesem System nicht vorhanden.

## Geaenderte Hauptdateien

- `Roadmap.md`
- `data/jobagent/store.json`
- `docs/handoffs/2026-09-13-ja041-avature-budget-bmw-reachability-handoff.md`
- `html/jobagent/daily-run-20260913T010245703Z.html`
- `html/jobagent/daily-run-20260913T010421462Z.html`
- `handoff.latest.md`
- `handoff.latest.json`
- `todo.state.json`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:siemens_energy_ag -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 100 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:bmw_group -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `1`, dokumentierter Erreichbarkeitsfehler
- `cmd /c .\ci.cmd devserver-start` -> Exit `0`
- `Test-NetConnection localhost -Port 9000` -> `TcpTestSucceeded=True`
- `Get-Content todo.state.json/handoff.latest.json | ConvertFrom-Json` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`

## Roadmap-Rotation

Keine Rotation. `TD-0053`/JA-041 bleibt offen, weil BMW-Fetch/Fallback beziehungsweise Quellenwechsel und die breitere Abschlussstichprobe noch fehlen. Nach Nutzeranweisung wurde kein Supertest gestartet.

## Naechster Anker

JA-041 fortsetzen:

1. BMW-spezifischen Fetch-/Fallback-Slice isolieren oder belegte alternative offizielle BMW-Karriere-/ATS-Quelle im Store verifizieren.
2. Breitere JA-041-Abschlussstichprobe erneut laufen lassen.
3. Danach Roadmap/Todo/Handoff synchronisieren; Supertest nur bei ausdruecklicher Anforderung.
