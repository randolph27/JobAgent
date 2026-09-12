# Handoff latest

Stand: 2026-09-12T16:02:00+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager über vollständige Karriere- und ATS-Ergebnislisten finden.
- Branch: `master`
- HEAD vor Commit: `ba089c6d308f`
- Upstream: `origin/master`
- Worktree: `dirty` vor Stage/Commit
- Route: `True`

## Abgeschlossene Slices in diesem Arbeitsstand

1. Wacker/`jobs.wacker.com`: offiziell verlinkte SuccessFactors-/j2w-RSS-Feeds werden verfolgt; RSS-/Atom-Items werden als offizielle Detailkandidaten extrahiert; `/go/`-Kategoriequellen sind auf relevante Joblisten begrenzt; relative Host-Strings werden nicht mehr zu Scheindetailpfaden aufgeloest.
2. Giesecke+Devrient, HENSOLDT und Knorr-Bremse: belegte SuccessFactors-Seiten priorisieren rollenbezogene `/services/rss/job/`-Feeds aus den konfigurierten Suchbegriffen vor generischen Suchseiten; generische Suchseiten bleiben Fallback; nicht abgearbeitete RSS-/Quellen-Follow-ups erzeugen nicht mehr pauschal `pagination_detected`.

## Geaenderte Hauptdateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `data/jobagent/store.json`
- `Roadmap.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.checkpoint.json`
- `docs/handoffs/2026-09-12-ja041-wacker-rss-handoff.md`
- `docs/handoffs/2026-09-12-ja041-successfactors-rss-priority-handoff.md`
- `html/jobagent/daily-run-20260912T090641065Z.html`
- `html/jobagent/daily-run-20260912T135204013Z.html`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- Wacker-Live-Kontrolllauf `scanrun:20260912T090641065Z` -> `SUCCESS`, 3 Raw-Jobs/gepruefte Jobs, 0 Adapterfehler, 0 Zielrollentreffer.
- G+D/HENSOLDT/Knorr-Bremse-Live-Kontrolllauf `scanrun:20260912T135204013Z` -> `SUCCESS`, 17 Raw-Jobs, 16 gepruefte Jobs/Snapshots, 0 unsichere Quellen, 0 Adapterfehler, 0 Zielrollentreffer.
- `cmd /c .\ci.cmd stp` -> Exit `0` am 2026-09-12T16:00:03+02:00.

## Roadmap-Rotation

Keine Rotation. `TD-0053`/JA-041 bleibt offen, weil Abschlussgate und breitere Live-Stichprobe noch ausstehen. Nach Nutzeranweisung ist ein nicht ausdruecklich angefragter Supertest kein Blocker.

## Bekannter Zusatzblocker

SonarQube war im vorherigen STP-Kontext lokal nicht erreichbar. Startversuch ueber `.\ci.cmd sonar-start` scheiterte mit `docker_engine_unavailable; wsl_fallback=wsl_missing`. Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`, Log: `logs\terminal\sonar-start-20260912-111035.log`.

## Naechster Anker

JA-041 fortsetzen: Abschlussgate und breitere Live-Stichprobe nach erfolgreichem SuccessFactors-RSS-Hotspot vorbereiten; Supertest ist nach Nutzeranweisung nicht blockierend, wenn nicht ausdruecklich angefragt.
