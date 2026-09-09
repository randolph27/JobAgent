# Handoff latest

Stand: 2026-09-09T13:42:13.176+02:00

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- Branch: `master`
- HEAD: `09e6818207ff`
- Ahead/Behind: `0/0`
- Route: `ok`
- STP: `cmd /c .\ci.cmd stp` erfolgreich um 2026-09-09T13:42:13+02:00
- Supertest: nicht ausgefuehrt, weil JA-041 offen ist.
- Devserver: `cmd /c .\ci.cmd devserver-status` erfolgreich, Port 8500 lauscht (`http://localhost:8500/`).
- SonarQube: `curl.exe --max-time 5 --silent --show-error http://localhost:9000/api/system/status` Timeout; `cmd /c .\ci.cmd sonar-start` fehlgeschlagen mit `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`.

## Ergebnis

- `scanrun:20260909T110550035Z` wurde fachlich ausgewertet: Die 10 MAN-Snapshots waren Karriere-/Navigationsseiten, keine konkreten Jobs.
- `src\JobAgent.LiveScan.psm1` trennt konkrete Jobdetail-Kandidaten von Karriere-Navigation.
- Offiziell verlinkte Jobportale werden als Quellseiten verfolgt, statt als Jobs gespeichert zu werden.
- Percent-encodete UTF-8-Detailpfade werden vor der offiziellen Quellenpruefung tolerant normalisiert.
- Strukturierte `application/json`-Navigation ohne `JobPosting` wird nicht mehr als Job akzeptiert.
- `tests\Test-JobAgentLiveScan.ps1` deckt Navigation, Jobportal-Followups, UTF-8-Detailpfade und strukturierte Navigation ab.

## Evidence

- `logs/jobagent/daily-run-20260909T112404328Z.json`: MAN-Kontrolllauf, Status `SUCCESS`, 0 Raw-Jobs, 0 Snapshots, 10 entfernte falsche Navigations-Jobs.
- `logs/jobagent/daily-run-20260909T113019911Z.json`: Mehrfirmen-Pilot, Status `PARTIAL`, 3 Firmen, 46 gepruefte Detailseiten, 0 Zielrollentreffer.
- `logs/jobagent/daily-run-20260909T113552446Z.json`: ATOSS-Nachlauf, Status `PARTIAL`, 30 echte Detailkandidaten; `Overview` und `Jobs` wurden nicht mehr als Snapshots erzeugt.
- `docs/handoffs/2026-09-09-ja041-navigation-jobportal-handoff.md`: Detail-Handoff.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd stp
cmd /c .\ci.cmd devserver-status
curl.exe --max-time 5 --silent --show-error http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

Funktionstests, Route-Check, STP und Devserver-Status waren erfolgreich. SonarQube blieb blockiert, weil Docker nicht verfuegbar ist und die WSL-Sonar-Distribution nicht laeuft.

## Naechster Anker

TRATON/ATOSS-Folgefaelle priorisieren: TRATON braucht staerkere Abgrenzung von Story-/News-Seiten gegen echte Joblisten; ATOSS braucht kontrollierte Pagination/Limit-Fortsetzung jenseits der ersten 30 Detailseiten.

