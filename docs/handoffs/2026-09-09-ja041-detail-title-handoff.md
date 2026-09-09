# JA-041 Detailseiten-Titel-Handoff

Stand: 2026-09-09T18:35:00+02:00

## Ergebnis

Der Live-HTML-Adapter ersetzt generische Aktionslink-Titel wie `Learn More`, `Apply Now`, `Bewerben` oder `Jetzt bewerben` beim Erzeugen des RawJobs durch einen belegten Titel aus der offiziellen Detailseite. Ausgewertet werden in Reihenfolge `h1`, `og:title` und `title`; weiterhin generische oder leere Werte werden ignoriert.

## Geänderte Dateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `Roadmap.md`
- `todo.state.json`
- `handoff.latest.md`

## Evidence

- `logs/jobagent/daily-run-20260909T162900710Z.json`: 4screen-Live-Pilot, Status `SUCCESS`, 1 Firma, 2 Raw-Jobs, 2 geprüfte Jobs, 0 Fehler.
- `html/jobagent/daily-run-20260909T162900710Z.html`: HTML-Bericht zum Kontrolllauf.
- `logs/jobagent/live-pilot-20260909.json`: zeigt für 4screen konkrete Titel statt `Learn More`: `Business Ops Intern – People & Culture (f/m/x)` und `Initiative Applications (f/m/x)`.

## Verifikation

Erfolgreich mit Exitcode 0:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -Command "& .\tools\Invoke-JobAgentLivePilot.ps1 -MaxCompanies 1 -CompanyIds @('company:4_screen_gmbh') -MaxResultsPerSource 30 -MaxDetailFetchesPerSource 30 -MaxPagesPerSource 5 -MaxRetries 0 -FetchClient auto -HostConcurrency 1 -TimeoutSeconds 12"
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd stp
cmd /c .\ci.cmd devserver-status
```

SonarQube konnte nicht gestartet werden: Status-Request auf `http://localhost:9000/api/system/status` lief in Timeout; `cmd /c .\ci.cmd sonar-start` endete mit `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`.

## Offen

JA-041 bleibt offen. Der nächste sinnvolle Schritt ist ein weiterer Mehrfirmen-Pilot auf andere ATS-/Static-Site-Familien; Abschlussgate und Supertest sind noch nicht erreicht.
