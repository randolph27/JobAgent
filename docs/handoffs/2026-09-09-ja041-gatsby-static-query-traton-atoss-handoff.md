# JA-041 Handoff: Gatsby/Greenhouse und Story-Abgrenzung

Stand: 2026-09-09T18:10:00+02:00

## Ergebnis

- `src/JobAgent.LiveScan.psm1` verfolgt Gatsby-StaticQuery-JSON unter `/page-data/sq/d/<hash>.json` als belegte Zusatzquelle, wenn die offizielle Karrierepage `staticQueryHashes` ausweist.
- Greenhouse-Jobknoten aus Gatsby-StaticQuery-Daten werden als konkrete Detailseiten rekonstruiert: `<career>/jobs/<gh_Id>-<slug>?gh_jid=<gh_Id>`.
- Parsing nutzt fuer Gatsby-StaticQuery-Inhalte weiter die urspruengliche Karrierepage als Basis-URL; iframe-/Portal-/Pagination-Folgeseiten behalten dagegen ihre eigene Basis-URL.
- Newsroom-, Story-, Blog-, Presse-, Event-, Case-Study- und Insight-URLs werden nicht mehr als Jobdetailkandidaten akzeptiert.
- Pagination-URLs behalten Query-Parameter bei, damit `?page=2` und aehnliche Seiten nicht durch Kanonisierung mit der Startseite kollidieren.

## Live-Evidence

- `logs/jobagent/daily-run-20260909T155902193Z.json`: ATOSS-Pilot, Status `SUCCESS`, 1 Firma, 72 Raw-Jobs, 72 gepruefte Jobs, 0 unsichere Quellen, 0 Fehler.
- `html/jobagent/daily-run-20260909T155902193Z.html`: zugehoeriger HTML-Bericht.
- `logs/jobagent/daily-run-20260909T160523370Z.json`: TRATON-Pilot nach Story-Abgrenzung, Status `SUCCESS`, 1 Firma, 0 Raw-Jobs, 1 alter Story-Snapshot entfernt, 0 unsichere Quellen, 0 Fehler.
- `html/jobagent/daily-run-20260909T160523370Z.html`: zugehoeriger HTML-Bericht.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentClassification.ps1
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -MaxCompanies 1 -CompanyIds company:atoss_software_se -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient auto -HostConcurrency 1
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -MaxCompanies 1 -CompanyIds company:traton_se -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient auto -HostConcurrency 1
```

Alle Commands liefen mit Exitcode 0. Kein Supertest ausgefuehrt, weil JA-041 weiterhin offen ist.

## Naechster Anker

Weitere ATS-/Static-Site-Familien aus dem naechsten Mehrfirmen-Pilot priorisieren; ATOSS und TRATON sind fuer diese konkrete Adapterluecke nicht mehr die aktuellen Blocker.
