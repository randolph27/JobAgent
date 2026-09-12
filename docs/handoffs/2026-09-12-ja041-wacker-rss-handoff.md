# JA-041 Handoff: Wacker RSS-Follow-up

Stand: 2026-09-12T11:12:00+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Branch: `master`
- Slice: Wacker/`jobs.wacker.com` als scan-lokale offizielle Quelle ueber SuccessFactors-/j2w-RSS-Follow-up geschlossen.

## Umsetzung

- `src/JobAgent.LiveScan.psm1` verfolgt offiziell belegte `<link type="application/rss+xml">`-Feeds als Quellseiten.
- RSS-/Atom-Items werden als offizielle Detailkandidaten extrahiert, kanonisiert und mit pfadbasierter SuccessFactors-Job-ID versehen.
- `/go/`-Kategoriequellen werden auf zielrelevante SuccessFactors-Kategorien (`IT`, `All Jobs`, `Global Jobs`, `See all jobs`) begrenzt, damit Navigation nicht das Seitenbudget verbraucht.
- Relative Host-Strings wie `jobs.wacker.com` werden nicht mehr als relative Pfade auf derselben Quelle verarbeitet.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -Command "& { .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot . -CompanyIds @('company:wacker_chemie_ag') -MaxResultsPerSource 50 -MaxDetailFetchesPerSource 50 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient curl -HostConcurrency 1 }"` -> Exit `0`

## Evidence

- `logs/jobagent/daily-run-20260912T090641065Z.json`: Wacker `SUCCESS`, 1 Firma, 3 Raw-Jobs/gepruefte Jobs, 3 Snapshots, 0 Adapterfehler, 0 Zielrollentreffer.
- `html/jobagent/daily-run-20260912T090641065Z.html`: HTML-Report zum Kontrolllauf.

## Offene Punkte

- JA-041 bleibt offen: Giesecke+Devrient, HENSOLDT und Knorr-Bremse sind weiterhin wegen Ergebnis-/Pagination-Limits `PARTIAL`.
- SonarQube ist weiterhin lokal nicht erreichbar; `.\ci.cmd sonar-start` scheitert mit `docker_engine_unavailable; wsl_fallback=wsl_missing`.
- Supertest nicht ausgefuehrt, weil JA-041 noch nicht abgeschlossen ist.
