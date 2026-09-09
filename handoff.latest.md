# Handoff latest

Stand: 2026-09-09T12:58:00+02:00

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- Roadmap-Rotation: keine. `JA-041`, `JA-027`, `UI-001` und `JA-042` sind fachlich nicht abgeschlossen.
- Supertest: nicht erneut ausgefuehrt; gemaess Nutzeranweisung fuer diesen Uebergang als erledigt gewertet.

## Umgesetzter Stand

- `tools\Invoke-JobAgentDailyRun.ps1` und `tools\Invoke-JobAgentLivePilot.ps1` akzeptieren fuer Live-Laeufe jetzt `-FetchClient`, `-WslDistribution` und `-HostConcurrency`.
- `src\JobAgent.LiveScan.psm1` nutzt fuer produktive HTTP-Abrufe den gemeinsamen Fetchvertrag aus `src\JobAgent.SourceVerification.psm1`.
- `src\JobAgent.SourceVerification.psm1` exportiert `Invoke-JobAgentCompanyVerificationHttpRequest`.
- Live-Fehlerartefakte enthalten jetzt konkrete Fetch-Fehlerklasse und Client, z. B. `source_fetch_failed[TLS_CREDENTIAL_UNAVAILABLE][curl.exe]`.
- `docs\data-model.md`, `Roadmap.md`, Todo-State und Detail-Handoff sind synchronisiert.

## Live-Pilot-Diagnose

Ausgefuehrt wurden kontrollierte JA-041-Live-Pilots:

```powershell
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 2 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient auto
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 1 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient curl
```

Ergebnis:

- `logs/jobagent/daily-run-20260909T104917305Z.json`: 2 Firmen, 2 Adapterfehler, 0 Jobs, Status `FAILED`.
- `logs/jobagent/daily-run-20260909T105052362Z.json`: 1 Firma, 1 Adapterfehler, 0 Jobs, Status `FAILED`.
- HTML-Artefakte: `html/jobagent/daily-run-20260909T104917305Z.html`, `html/jobagent/daily-run-20260909T105052362Z.html`.
- Ursache: lokale TLS-Credential-Fehler `SEC_E_NO_CREDENTIALS` / `TLS_CREDENTIAL_UNAVAILABLE`.
- `curl.exe` ist betroffen; `wsl.exe --list --quiet` liefert keine Distribution, daher ist `wsl-curl` aktuell nicht nutzbar.

Die Live-Pilots sind Diagnoseartefakte, kein Stellen- oder Vollstaendigkeitsnachweis.

## Verifikation

Erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd stp
```

Nicht ausgefuehrt:

```powershell
.\ci.cmd supertest
```

Grund: JA-041 ist noch offen; gemaess aktueller Nutzeranweisung gilt der nicht angefragte Supertest fuer diesen Uebergang als erledigt.

## Naechster Anker

1. Lokale Live-Erreichbarkeit herstellen oder funktionierenden FetchClient bereitstellen.
2. Danach denselben kleinen JA-041-Live-Pilot erneut ausfuehren.
3. Entstehende ATS-/iframe-/PARTIAL-Faelle auswerten und die naechste Adaptererweiterung priorisieren.

Detail-Handoff: `docs/handoffs/2026-09-09-ja041-live-fetch-policy-pilot-handoff.md`
