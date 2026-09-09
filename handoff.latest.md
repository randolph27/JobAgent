# Handoff latest

Stand: 2026-09-09T18:20:00+02:00

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- Branch: `master`
- HEAD vor Commit: `ad13122cd3fb`
- Ahead/Behind vor Commit: `0/0`
- STP: `cmd /c .\ci.cmd stp` erfolgreich um 2026-09-09T18:12:11+02:00
- Devserver: Port 8500 lauscht (`http://localhost:8500/`).
- Supertest: gemaess Nutzeranweisung in diesem Chat nicht separat angefordert; JA-041 ist trotzdem fachlich noch nicht vollstaendig abgeschlossen.

## Abgeschlossener Slice

ATOSS/TRATON-Hotspot aus JA-041 wurde bearbeitet:

- Gatsby-StaticQuery-JSON unter `/page-data/sq/d/<hash>.json` wird aus offiziellen Karrierepages als Zusatzquelle verfolgt.
- Greenhouse-Knoten aus Gatsby-StaticQuery-Daten werden mit `gh_Id` zu konkreten Detailseiten rekonstruiert: `<career>/jobs/<gh_Id>-<slug>?gh_jid=<gh_Id>`.
- Pagination-URLs behalten Query-Parameter, damit `?page=2` und aehnliche Folgeseiten nicht mit der Startseite kollidieren.
- Newsroom-, Story-, Blog-, Presse-, Event-, Case-Study- und Insight-URLs werden nicht mehr als Jobdetailkandidaten akzeptiert.
- Parsing nutzt fuer Gatsby-StaticQuery-Inhalte weiter die urspruengliche Karrierepage als Basis-URL; iframe-/Portal-/Pagination-Folgeseiten behalten ihre eigene Basis-URL.

## Evidence

- `logs/jobagent/daily-run-20260909T155902193Z.json`: ATOSS-Pilot, Status `SUCCESS`, 1 Firma, 72 Raw-Jobs, 72 gepruefte Jobs, 0 unsichere Quellen, 0 Fehler.
- `html/jobagent/daily-run-20260909T155902193Z.html`: HTML-Bericht zum ATOSS-Pilot.
- `logs/jobagent/daily-run-20260909T160523370Z.json`: TRATON-Pilot nach Story-Abgrenzung, Status `SUCCESS`, 1 Firma, 0 Raw-Jobs, 1 alter Story-Snapshot entfernt, 0 unsichere Quellen, 0 Fehler.
- `html/jobagent/daily-run-20260909T160523370Z.html`: HTML-Bericht zum TRATON-Pilot.
- `docs/handoffs/2026-09-09-ja041-gatsby-static-query-traton-atoss-handoff.md`: Detail-Handoff.

## Verifikation

Erfolgreich mit Exitcode 0:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentClassification.ps1
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -MaxCompanies 1 -CompanyIds company:atoss_software_se -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient auto -HostConcurrency 1
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -MaxCompanies 1 -CompanyIds company:traton_se -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 10 -MaxRetries 0 -FetchClient auto -HostConcurrency 1
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd devserver-status
cmd /c .\ci.cmd stp
```

SonarQube:

```powershell
curl.exe --max-time 5 --silent --show-error http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

Ergebnis: Status-Request Timeout; Start fehlgeschlagen mit `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`.

## Roadmap/Todo

- `TD-0053` bleibt `in-progress`.
- `JA-041` bleibt offen. Nicht archivieren: weitere ATS-/Static-Site-Familien, produktiver Mehrfirmen-Pilot und Abschlussgate fehlen noch.
- Keine Roadmap-Punkte wurden komplett erledigt; daher keine Rotation nach `Roadmap_archive.md`.
- `TD-0041`/`JA-027`, `TD-0054`/`UI-001`, `TD-0055`/`JA-042` bleiben offen.

## Naechster Anker

Naechsten Mehrfirmen-Pilot auf weitere ATS-/Static-Site-Familien ausweiten. ATOSS und TRATON sind fuer Gatsby/Story/Pagination nicht mehr der aktive Blocker.
