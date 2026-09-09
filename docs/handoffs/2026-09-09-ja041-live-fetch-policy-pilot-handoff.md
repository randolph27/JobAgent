# Handoff JA-041 Live-Fetch-Policy und Pilotdiagnose 2026-09-09

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- JA-041 bleibt offen: ein erfolgreicher Live-Pilot mit erreichbaren offiziellen Quellen und weitere ATS-Familienabdeckung fehlen.

## Umgesetzter Slice

- `tools\Invoke-JobAgentDailyRun.ps1` und `tools\Invoke-JobAgentLivePilot.ps1` akzeptieren jetzt `-FetchClient`, `-WslDistribution` und `-HostConcurrency` fuer Live-Laeufe.
- `src\JobAgent.LiveScan.psm1` nutzt fuer produktive Fetches die gemeinsame HTTP-Policy aus `src\JobAgent.SourceVerification.psm1`.
- `src\JobAgent.SourceVerification.psm1` exportiert den gemeinsamen HTTP-Fetcher fuer LiveScan.
- Live-Adapter-Fehlerartefakte behalten die konkrete Fetch-Fehlerklasse und den tatsaechlichen Client, z. B. `TLS_CREDENTIAL_UNAVAILABLE` und `curl.exe`.
- `docs\data-model.md` dokumentiert den erweiterten Live-CLI-Fetchvertrag.

## Live-Pilot

Ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 2 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient auto
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 1 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient curl
```

Ergebnis:

- `logs/jobagent/daily-run-20260909T104917305Z.json`: 2 Firmen, 2 Adapterfehler, 0 Jobs, Status `FAILED`.
- `logs/jobagent/daily-run-20260909T105052362Z.json`: 1 Firma, 1 Adapterfehler, 0 Jobs, Status `FAILED`.
- `html/jobagent/daily-run-20260909T104917305Z.html` und `html/jobagent/daily-run-20260909T105052362Z.html` wurden erzeugt.
- Ursache ist lokal belegt: `SEC_E_NO_CREDENTIALS` / `TLS_CREDENTIAL_UNAVAILABLE`; `wsl.exe --list --quiet` liefert keine Distribution, daher ist `wsl-curl` aktuell nicht nutzbar.

Die Live-Pilots sind Diagnoseartefakte, kein Stellen- oder Vollstaendigkeitsnachweis.

## Verifikation

Erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
```

Nicht ausgefuehrt:

- `.\ci.cmd supertest`, weil JA-041 nicht abgeschlossen ist.

## Naechste Aufgabe

Live-Erreichbarkeit herstellen oder einen funktionierenden FetchClient bereitstellen, dann denselben Live-Pilot erneut ausfuehren. Danach die entstehenden ATS-/iframe-/PARTIAL-Faelle fachlich priorisieren.
