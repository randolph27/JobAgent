# Handoff JA-041 Live-CLI und ATS-Frames 2026-09-09

## Startpunkt fuer neuen Chat

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- JA-041 ist weiter offen: ein echter datierter Live-Pilot gegen vorhandene offizielle Quellen und weitere ATS-Familienabdeckung stehen noch aus.

## Umgesetzter Slice

- `tools\Invoke-JobAgentDailyRun.ps1`
  - unterstuetzt jetzt `-AdapterMode auto|fixture|live`;
  - waehlt mit `-FixturePath` den Fixture-Modus und ohne Fixture den Live-Modus;
  - reicht Live-Policy-Parameter durch: `MaxRetries`, `MaxResultsPerSource`, `MaxDetailFetchesPerSource`, `MaxPagesPerSource`, `SearchTerms`;
  - gibt `adapter_mode` im JSON-Resultat aus.
- `tools\Invoke-JobAgentLivePilot.ps1`
  - nutzt dieselben produktiven Defaults wie die Daily-CLI: 100 Kandidaten, 100 Detailabrufe, 10 Seiten;
  - akzeptiert `MaxPagesPerSource` und `SearchTerms`.
- `src\JobAgent.LiveScan.psm1`
  - erkennt offiziell belegte `iframe`-/`frame`-Einbettungen als zusaetzliche Quellseiten;
  - verarbeitet daraus extrahierte offizielle ATS-Joblisten ohne Headless-Browser;
  - markiert vollstaendig abgearbeitete leere Quellen als `SUCCESS` mit `scan_complete=true`;
  - bleibt fail-closed fuer blockierte, dynamische, fehlerhafte oder unvollstaendig verarbeitete Quellen.
- `docs\data-model.md` dokumentiert den neuen Daily-CLI-Betriebsvertrag.
- `Roadmap.md` enthaelt den Fortschrittsvermerk unter JA-041.

## Verifikation

Erfolgreich ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd stp
```

SonarQube:

```powershell
curl.exe -s --max-time 5 http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

Status: nicht verfuegbar. `sonar-start` schlug erneut fehl mit `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`. Evidence: `logs\terminal\sonar-start-20260909-082906.log`, `logs\terminal\error-sonar-start-latest.json`.

Nicht ausgefuehrt:

- `.\ci.cmd supertest`, weil JA-041 nicht abgeschlossen ist und der Nutzer Supertest erst nach Roadmap-Abschluss verlangt.
- Produktiver Live-Pilot gegen externe Quellen, weil dieser nach den lokalen Funktionstests als naechster separater JA-041-Schritt ansteht.

## Naechste Aufgabe

JA-041 fortsetzen:

1. Kontrollierten Live-Pilot mit kleiner `CompanyIds`- oder `MaxCompanies`-Auswahl ueber den neuen Daily-CLI- oder LivePilot-Einstieg ausfuehren.
2. `logs/jobagent/JA-041-live-*.json` beziehungsweise Pilot-/Daily-Artefakte auswerten: offizielle Detail-URLs, iframe-/ATS-Abdeckung, PARTIAL-/Review-Ursachen.
3. Aus Live-Befunden weitere ATS-Adapter-/Parserfaelle priorisieren; keine pauschale Allowlist und keine Captcha-/Login-Umgehung.

