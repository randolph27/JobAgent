# Handoff latest

Stand: 2026-09-13T02:59:26.027+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- Branch: `master`
- HEAD vor Commit: `334957f59a0f`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `True`

## Abgeschlossener Slice

JA-041 Avature-Navigation/Seitenbudget:

- Avature-Listing-, Sprach-, Kategorie- und Accountpfade werden nicht mehr als Jobs akzeptiert, nur weil sie unter `/jobs/...` liegen.
- `FolderDetail`-Treffer bleiben zulaessig; Avature-Listing-Navigation ist durch einen eigenen Funktionstest abgedeckt.
- Avature-Seiten verfolgen keine generischen Jobportal-Follow-ups mehr, wenn zielrollenbezogene Avature-Such-Follow-ups aktiv sind.
- Abgearbeitete Pagination wird nicht mehr nur wegen sichtbarem Next-Link als offen markiert; offen bleibt nur eine noch nicht besuchte Folgeseite.
- Live-/Pilot-Seitenbudget ist bis `MaxPagesPerSource 100` steuerbar.
- Siemens-Energy-Kontrolllauf `logs/jobagent/daily-run-20260913T005454858Z.json`: `PARTIAL`, 1 Raw-Job, 1 Snapshot, 0 Zielrollentreffer; bewusst enges CIO-Budget, kein Abschlussgate.
- Zwischenlaeufe mit groesserem Budget wurden wegen Laufzeit abgebrochen oder als explorative Fehl-/Teilversuche bereinigt; kein Abschlussgate daraus ableiten.

## Geaenderte Hauptdateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `tools/Invoke-JobAgentDailyRun.ps1`
- `tools/Invoke-JobAgentLivePilot.ps1`
- `data/jobagent/store.json`
- `Roadmap.md`
- `docs/handoffs/2026-09-13-ja041-avature-navigation-budget-handoff.md`
- `html/jobagent/daily-run-20260913T005454858Z.html`
- `handoff.latest.md`
- `handoff.latest.json`
- `todo.state.json`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`

## Roadmap-Rotation

Keine Rotation. `TD-0053`/JA-041 bleibt offen, weil Avature-Abschlussbudget/Quellenbegrenzung, BMW-Erreichbarkeit und breitere Abschlussstichprobe noch fehlen. Nach Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt und wurde nicht gestartet.

## Naechster Anker

JA-041 fortsetzen:

1. Siemens Energy/Avature mit reproduzierbarem breitem Budget abschliessen oder einen belegten Quellenbegrenzungsvertrag dokumentieren.
2. BMW-Erreichbarkeit pruefen und bei Bedarf Adapter-/Fetch-Hotspot isolieren.
3. Breitere JA-041-Abschlussstichprobe erneut laufen lassen.
4. Danach Roadmap/Todo/Handoff synchronisieren; Supertest nur bei ausdruecklicher Anforderung.
