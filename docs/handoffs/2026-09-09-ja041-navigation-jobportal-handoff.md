# JA-041 Handoff: Navigation vs. Jobportal

Stand: 2026-09-09T13:42:00+02:00

## Ergebnis

- MAN-Snapshot-Auswertung: `scanrun:20260909T110550035Z` hatte 10 gespeicherte Raw-Jobs, die nur Karriere-/Navigationsseiten waren (`Career at MAN`, `Benefits`, `Values`, `Pupils`, `Students`, `Professionals`, `Job Portal`, Laenderseiten). Das war kein fachlicher Stellennachweis.
- `src/JobAgent.LiveScan.psm1` trennt jetzt konkrete Jobdetail-Kandidaten von Karriere-Navigation:
  - generische Karriere-/Benefits-/Students-/Jobportal-Links werden nicht mehr als Jobs gespeichert;
  - offiziell verlinkte Jobportale werden als zusaetzliche Quellseiten verfolgt;
  - bereits percent-encodete UTF-8-Detailpfade werden vor der offiziellen Quellenpruefung tolerant normalisiert;
  - strukturierte `application/json`-Navigation ohne `JobPosting` wird nicht mehr als Job akzeptiert.
- `tests/Test-JobAgentLiveScan.ps1` deckt diese Regressionsfaelle ab.

## Live-Evidence

- `logs/jobagent/daily-run-20260909T112404328Z.json`: gezielter MAN-Kontrolllauf nach Parserfix, Status `SUCCESS`, 0 Raw-Jobs, 0 Snapshots, 10 entfernte falsche Navigations-Jobs.
- `logs/jobagent/daily-run-20260909T113019911Z.json`: Mehrfirmen-Pilot, Status `PARTIAL`, 3 Firmen, 46 gepruefte Detailseiten, 0 Zielrollentreffer, ATOSS/TRATON als PARTIAL-Folgefaelle.
- `logs/jobagent/daily-run-20260909T113552446Z.json`: gezielter ATOSS-Nachlauf nach JSON-Strukturfilter, Status `PARTIAL`, 30 echte Detailkandidaten; `Overview` und `Jobs` werden in diesem Lauf nicht mehr als Snapshots erzeugt.
- `logs/jobagent/live-pilot-20260909.json`: zeigt auf den letzten ATOSS-Pilot.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
```

Alle vier Funktionstests liefen erfolgreich. `.\ci.cmd supertest` wurde nicht ausgefuehrt, weil JA-041 weiter offen ist.

## Naechster Schritt

ATOSS und TRATON aus dem Mehrfirmen-Pilot fachlich priorisieren: Bei ATOSS ist das naechste konkrete Problem `result_limit_reached`; bei TRATON werden Story-/News-Seiten als offizielle Kandidaten sichtbar und muessen durch einen staerkeren Stellenlisten-/Content-Typ-Filter oder eine quellspezifische Priorisierung von echten Joblisten abgegrenzt werden.
