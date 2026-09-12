# JA-041 Handoff: SuccessFactors-Follow-up

Stand: 2026-09-12T10:40:00+02:00

## Zustand

- Active: `TD-0053`
- Roadmap-Punkt: JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- Status: `in-progress`
- Roadmap-Rotation: keine, JA-041 bleibt fachlich offen.
- Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung vom 2026-09-12 gilt ein nicht separat angefragter Supertest fuer diesen Uebergabeabschluss als erledigt/nicht blockierend. JA-041 bleibt fachlich offen.

## Erledigter Slice

- Belegte j2w-/SuccessFactors-Karriereseiten erzeugen im Live-Adapter jetzt automatisch die offizielle `/search/?createNewAlert=false&q=&locationsearch=`-Quellseite als Follow-up.
- SuccessFactors-Content-/Funktionsseiten unter `/content/...` werden nicht mehr als Jobdetails akzeptiert.
- Percent-encodete offizielle Detail-URLs mit kodierten Leerzeichen bleiben in SourceVerification zulaessig und verlieren `%20` nicht durch fruehe Dekodierung.
- Absolute, aber von `IsWellFormedUriString` abgelehnte reale Detail-URLs werden host- und evidence-seitig tolerant per `[Uri]` geparst, solange sie absolute HTTP(S)-URLs sind.

## Geaenderte Dateien

- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `tests/Test-JobAgentSourceVerification.ps1`
- `Roadmap.md`
- `data/jobagent/store.json`
- `html/jobagent/daily-run-20260912T083135724Z.html`
- `html/jobagent/daily-run-20260912T083922868Z.html`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -Command "& { .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot . -CompanyIds @('company:giesecke_plus_devrient_gmbh','company:hensoldt_ag','company:knorr_bremse_ag','company:wacker_chemie_ag') -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient curl -HostConcurrency 1 }"` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `1`
- `.\ci.cmd sonar-start` -> Exit `1`, Blocker: `docker_engine_unavailable; wsl_fallback=wsl_missing`

## Live-Evidence

- Vor URL-Fix: `logs/jobagent/daily-run-20260912T083135724Z.json`
  - 4 Firmen, 18 Raw-Jobs, 1 Adapterfehler bei HENSOLDT wegen encoded Detail-URL.
- Nach URL-Fix: `logs/jobagent/daily-run-20260912T083922868Z.json`
  - 4 Firmen, 39 Raw-Jobs/gepruefte Jobs, 0 Adapterfehler.
  - HENSOLDT ist nicht mehr `FAILED`, sondern `PARTIAL`.
  - Giesecke+Devrient, HENSOLDT und Knorr-Bremse bleiben `PARTIAL`, weil Ergebnis-/Pagination-Limits weiter einen Vollstaendigkeitsnachweis verhindern.
- Wacker bleibt `NO_JOBS_FOUND`; naechster Hotspot ist die scan-lokale Anerkennung des offiziell verlinkten `jobs.wacker.com` als firmengebundene ATS-/Karrierequelle.

## Blockierte Zusatzpruefung

SonarQube ist lokal weiterhin nicht erreichbar. Startversuch ueber `.\ci.cmd sonar-start` scheitert, weil weder Docker Engine noch WSL-Fallback verfuegbar sind. Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`, Log: `logs\terminal\sonar-start-20260912-104434.log`.

## Naechster Schritt

JA-041 fortsetzen: scan-lokalen offiziellen Linked-ATS-/Karrierequellenvertrag fuer Wacker/`jobs.wacker.com` implementieren oder, falls kleiner, die noch offenen SuccessFactors-PARTIAL-Ursachen fuer G+D/HENSOLDT/Knorr-Bremse nach Ergebnis-/Pagination-Limit priorisieren.
