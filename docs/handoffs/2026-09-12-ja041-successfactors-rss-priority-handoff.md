# JA-041 SuccessFactors-RSS-Priorisierung

Stand: 2026-09-12T15:52:04+02:00

## Ergebnis

Der SuccessFactors-Hotspot fuer Giesecke+Devrient, HENSOLDT und Knorr-Bremse ist scan-lokal geschlossen.

- Belegte j2w-/SuccessFactors-Seiten erzeugen rollenbezogene `/services/rss/job/`-Feeds aus den konfigurierten Suchbegriffen.
- Diese RSS-Feeds werden vor generischen SuccessFactors-Suchseiten verarbeitet.
- Generische `/search/?createNewAlert=false&q=&locationsearch=`-Seiten bleiben Fallback, wenn keine offiziellen RSS-Feeds ableitbar sind.
- Nicht abgearbeitete RSS-/Quellen-Follow-ups zaehlen nicht mehr pauschal als `pagination_detected`; echte Pagination bleibt weiter unvollstaendig.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- Live-Kontrolllauf:
  `pwsh -NoProfile -Command "& { .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot . -CompanyIds @('company:giesecke_plus_devrient_gmbh','company:hensoldt_ag','company:knorr_bremse_ag') -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient curl -HostConcurrency 1 }"` -> Exit 0

## Evidence

- `logs/jobagent/daily-run-20260912T135204013Z.json`
- `html/jobagent/daily-run-20260912T135204013Z.html`

Kontrolllauf `scanrun:20260912T135204013Z`: Status `SUCCESS`; 3 Firmen gescannt; 17 Raw-Jobs; 16 gepruefte Jobs/Snapshots; 0 unsichere Quellen; 0 Adapterfehler; 0 Zielrollentreffer.

## Naechster Anker

JA-041 bleibt offen fuer Abschlussgate und breitere Live-Stichprobe. Supertest wurde nicht ausgefuehrt, weil JA-041 noch nicht vollstaendig abgeschlossen ist.
