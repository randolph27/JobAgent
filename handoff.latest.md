# Handoff latest

Stand: 2026-09-12T21:36:00+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager über vollständige Karriere- und ATS-Ergebnislisten finden.
- Branch: `master`
- HEAD: `4a0450e382fe`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Abgeschlossener Slice in diesem Arbeitsstand

Breitere Live-Stichprobe und False-Positive-Filter fuer offizielle Detailkandidaten:

- 10-Firmen-Pilot `logs/jobagent/daily-run-20260912T190510537Z.json`: `PARTIAL`, 10 Firmen, 99 Raw-Jobs, 74 Snapshots, 7 vollstaendig erfolgreiche Quellen, 2 unsichere Quellen, 1 nicht erreichbare Quelle, 0 Zielrollentreffer.
- Gefundener Hotspot geschlossen: ATS-Kategorie-, Account-, Registrierungs-, Bewerbungs-/CheckLogin- und Labor-Condition-Seiten werden nicht mehr als Jobdetails akzeptiert.
- Bayerischer-Rundfunk-Kontrolllauf `logs/jobagent/daily-run-20260912T192801804Z.json`: `SUCCESS`, 10 Raw-Jobs/gepruefte Jobs/Snapshots, 0 unsichere Quellen, 0 Zielrollentreffer.
- Siemens-Energy-Kontrolllauf `logs/jobagent/daily-run-20260912T192545574Z.json`: Kategorie-/Accountseiten werden nicht mehr gespeichert; Lauf bleibt wegen Ergebnislimit/Oracle-ATS-Familie `PARTIAL`.

## Geaenderte Hauptdateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `data/jobagent/store.json`
- `Roadmap.md`
- `handoff.latest.md`
- `handoff.latest.json`
- `todo.state.json`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `docs/handoffs/2026-09-12-ja041-live-sample-false-positive-handoff.md`
- `html/jobagent/daily-run-20260912T190510537Z.html`
- `html/jobagent/daily-run-20260912T192545574Z.html`
- `html/jobagent/daily-run-20260912T192801804Z.html`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- 10-Firmen-Live-Pilot `scanrun:20260912T190510537Z` -> `PARTIAL`, siehe oben.
- Siemens-Kontrolllauf `scanrun:20260912T192545574Z` -> `PARTIAL`, false-positive Kategorie-/Accountseiten entfernt, Ergebnislimit offen.
- Bayerischer-Rundfunk-Kontrolllauf `scanrun:20260912T192801804Z` -> `SUCCESS`.
- `cmd /c .\ci.cmd stp` -> Exit `0`; STP setzte den naechsten Anker erneut auf UI-001, danach Korrekturevent `EV-20260912-213600-ja041-live-sample-stp-correction` geschrieben.

## Roadmap-Rotation

Keine Rotation. `TD-0053`/JA-041 bleibt offen, weil Siemens-Energy-Ergebnislimit/Oracle-ATS-Familie, BMW-Erreichbarkeit, Abschlussgate und breitere Abnahme noch ausstehen. Nach Nutzeranweisung ist ein nicht ausdruecklich angefragter Supertest kein Blocker.

## Bekannter Zusatzblocker

SonarQube war im vorherigen STP-Kontext lokal nicht erreichbar. Startversuch ueber `.\ci.cmd sonar-start` scheiterte mit `docker_engine_unavailable; wsl_fallback=wsl_missing`. Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`, Log: `logs\terminal\sonar-start-20260912-111035.log`.

## Naechster Anker

JA-041 fortsetzen: Siemens-Energy-Ergebnislimit/Oracle-ATS-Familie priorisieren, danach BMW-Erreichbarkeit pruefen und Abschlussgate/breitere Stichprobe erneut laufen lassen.
