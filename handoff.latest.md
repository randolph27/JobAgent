# Handoff latest

Stand: 2026-09-08T09:08:12+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD: `b3c5da94d5f6`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Route: `True`

## Erledigter Slice

- Verify-Queue verarbeitet faellige `RETRY_SCHEDULED`/`VERIFY_OFFICIAL_SITE`-Eintraege wieder.
- `ready_total` und Kandidatenauswahl nutzen dieselbe zentrale Due-Pruefung.
- Nicht datierte `PENDING`-Eintraege bleiben startbar; `RETRY_SCHEDULED` wird erst ab `next_attempt_at` erneut verarbeitet.
- JA-027 bleibt offen: 100er-Live-Benchmark und 1.000 belegte offizielle Karriere-/ATS-Quellen sind nicht erreicht.
- Kein Roadmap-Punkt wurde rotiert, weil kein Punkt fachlich komplett erledigt ist.
- Supertest wurde nicht erneut ausgefuehrt; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Abschluss als erledigt.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `cmd /c .\ci.cmd stp` -> Exit 0
- `Invoke-WebRequest http://localhost:9000/api/system/status -TimeoutSec 5` -> Exit 1 (timeout)
- `cmd /c .\ci.cmd sonar-start` -> Exit 1 (missing local wrapper D:\_Scripte\JobAgent\sonar.cmd)
- `cmd /c .\ci.cmd devserver-start` -> Exit 0 (http://localhost:8500/ listener_pid=31300)

## Laufende Dienste

- Devserver: `http://localhost:8500/` gestartet, Listener PID 31300.
- SonarQube: API-Check Timeout; Start via `cmd /c .\ci.cmd sonar-start` fehlgeschlagen, lokaler Wrapper `D:\_Scripte\JobAgent\sonar.cmd` fehlt.

## Geaenderte Dateien

- `Roadmap.md`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `handoff.latest.json`
- `handoff.latest.md`

## Naechster Anker

- Ab 2026-09-08T13:15:45+02:00: pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
- Ab 2026-09-08T13:19:32+02:00: pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
- Danach Coverage messen: pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
- SonarQube separat reparieren: lokalen sonar.cmd-Wrapper oder CI-Konfiguration wiederherstellen.
