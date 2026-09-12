# Handoff latest

Stand: 2026-09-12T10:46:10.029+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager über vollständige Karriere- und ATS-Ergebnislisten finden #comment: Firmenlinks werden erst durch verlässliche Extraktion and passende Rollen-/Standortbewertung zu nutzbaren Stellenangeboten.
- Branch: `master`
- HEAD: `0d1d9e8e6a66`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Erledigter Slice

JA-041 SuccessFactors/j2w-Hotspot erweitert:

- belegte SuccessFactors-Karriereseiten erzeugen automatisch die offizielle `/search/?createNewAlert=false&q=&locationsearch=`-Quellseite als Follow-up;
- SuccessFactors-Contentseiten wie `/content/...` werden nicht mehr als Jobdetails akzeptiert;
- percent-encodete offizielle Detail-URLs mit kodierten Leerzeichen bleiben in SourceVerification zulaessig;
- absolute reale Detail-URLs, die `IsWellFormedUriString` ablehnt, werden host- und evidence-seitig tolerant per `[Uri]` geparst.

Roadmap-Rotation: keine. JA-041 bleibt offen, weil G+D/HENSOLDT/Knorr-Bremse noch `PARTIAL` sind und Wacker/`jobs.wacker.com` noch keinen vollstaendigen scan-lokalen Quellenvertrag hat.

Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung vom 2026-09-12 gilt ein nicht separat angefragter Supertest fuer diesen Uebergabeabschluss als erledigt/nicht blockierend.

## Versionierte Aenderungen

- `Roadmap.md`
- `data/jobagent/store.json`
- `docs/handoffs/2026-09-12-ja041-successfactors-followup-handoff.md`
- `html/jobagent/daily-run-20260912T083135724Z.html`
- `html/jobagent/daily-run-20260912T083922868Z.html`
- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `tests/Test-JobAgentSourceVerification.ps1`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -Command "& { .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot . -CompanyIds @('company:giesecke_plus_devrient_gmbh','company:hensoldt_ag','company:knorr_bremse_ag','company:wacker_chemie_ag') -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient curl -HostConcurrency 1 }"` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `1`
- `.\ci.cmd sonar-start` -> Exit `1`

## Evidence

- `logs/jobagent/daily-run-20260912T083135724Z.json`: vor URL-Fix, 4 Firmen, 18 Raw-Jobs, 1 Adapterfehler bei HENSOLDT wegen encoded Detail-URL.
- `logs/jobagent/daily-run-20260912T083922868Z.json`: nach URL-Fix, 4 Firmen, 39 Raw-Jobs/gepruefte Jobs, 0 Adapterfehler.
- `html/jobagent/daily-run-20260912T083922868Z.html`: HTML-Report zum Kontrolllauf.

## Blockierte Zusatzpruefung

SonarQube ist lokal nicht erreichbar. Startversuch ueber `.\ci.cmd sonar-start` scheitert mit `docker_engine_unavailable; wsl_fallback=wsl_missing`. Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`, Log: `logs\terminal\sonar-start-20260912-104434.log`.

## Naechster Anker

JA-041 fortsetzen, nicht zu UI-001 wechseln:

1. Wacker-Hotspot priorisieren: `https://www.wacker.com/cms/en-us/careers/overview.html` verlinkt offiziell auf `https://jobs.wacker.com/?locale=en_US`; diese Quelle wird im Live-Scan noch nicht als firmengebundene ATS-/Karrierequelle akzeptiert und endet deshalb `NO_JOBS_FOUND`.
2. Danach SuccessFactors-PARTIAL-Ursachen fuer Giesecke+Devrient, HENSOLDT und Knorr-Bremse pruefen: Ergebnis-/Pagination-Limits verhindern weiterhin `SUCCESS`.
3. Nach jedem Adapter-Slice: betroffene Funktionstests, gezielter Live-Kontrolllauf mit `-FetchClient curl`, Roadmap/Todo/Handoff-Sync und STP.
