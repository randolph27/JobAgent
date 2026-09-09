# Handoff latest

Stand: 2026-09-09T13:18:00+02:00

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `4d6d909522a2`
- Aktiver Todo: `TD-0053`
- Aktiver Roadmap-Punkt: `JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden`
- Status: `in-progress`
- Roadmap-Rotation: keine. `JA-041`, `JA-027`, `UI-001` und `JA-042` sind fachlich nicht abgeschlossen.
- STP: zuletzt ausgefuehrt am `2026-09-09T13:13:12+02:00`.
- Supertest: gemaess Nutzeranweisung als erledigt gewertet, aber nicht technisch ausgefuehrt, weil JA-041 noch offen ist.

## Umgesetzter Stand

- Der native Curl-Fetchpfad in `src\JobAgent.SourceVerification.psm1` bevorzugt jetzt ein nicht-Schannel-`curl.exe`, wenn mehrere Curl-Binaries vorhanden sind.
- OpenSSL-/LibreSSL-/BoringSSL-kompatible Curl-Builds werden mit `--ca-native` ausgefuehrt.
- Fetchresultate dokumentieren `curl_path`, `curl_tls_backend` und bei Nutzung `curl_ca_native`.
- Der vorhandene Schannel-Fallbackpfad bleibt dokumentiert und traegt `tls_revocation_policy`, ist aber nicht mehr der primaere Ausweg, wenn ein funktionierendes LibreSSL-Curl verfuegbar ist.
- `tests\Test-JobAgentSourceVerification.ps1` deckt Policy-Feld, Curl-TLS-Backend-Aufloesung, CA-Native-Entscheidung und Fallback-Metadaten ab.
- `data/jobagent/store.json` enthaelt den erfolgreichen Live-Scan `scanrun:20260909T110550035Z`.
- `Roadmap.md`, `todo.state.json`, `todo.checkpoint.json`, `todo.history.digest.json`, `todo.master.index.json`, `todo.events.jsonl`, `handoff.latest.json` und dieses Handoff wurden synchronisiert.

## Live-Pilot

Ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 1 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient curl
```

Ergebnis:

- `logs/jobagent/daily-run-20260909T110550035Z.json`: Status `SUCCESS`.
- 1 Firma gescannt.
- 10 Raw-Jobs.
- 10 gepruefte Jobs.
- 10 Snapshots.
- 0 Fehler.
- 0 aktive Zielrollentreffer.
- HTML-Artefakt: `html/jobagent/daily-run-20260909T110550035Z.html`.

Der vorherige Negativlauf `logs/jobagent/daily-run-20260909T110053094Z.json` bleibt als Diagnose erhalten: Windows-Schannel-`curl.exe` scheiterte mit `SEC_E_NO_CREDENTIALS`.

## Verifikation

Erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
cmd /c .\ci.cmd route-check
cmd /c .\ci.cmd stp
cmd /c .\ci.cmd devserver-status
```

Nicht erfolgreich:

```powershell
curl.exe --max-time 5 --silent --show-error http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

Ergebnis: Port 9000 lieferte Timeout; `sonar-start` scheiterte mit `docker_engine_unavailable; wsl_fallback=sonarqube_wsl_not_started`. Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`.

Nicht technisch ausgefuehrt:

```powershell
.\ci.cmd supertest
```

Grund: JA-041 ist weiterhin offen; laut Nutzeranweisung gilt der nicht angefragte Supertest fuer diesen Uebergang als erledigt.

## Naechster Anker

1. Snapshots aus `scanrun:20260909T110550035Z` fachlich auswerten: warum 10 gepruefte Jobs keine aktiven Zielrollentreffer ergaben.
2. Danach kleinen Mehrfirmen-JA-041-Live-Pilot starten.
3. Entstehende ATS-/iframe-/PARTIAL-Faelle priorisieren und die naechste Adapter-/Klassifikations-Erweiterung ableiten.
4. SonarQube erst erneut pruefen, wenn Docker Desktop oder die WSL-Sonar-Distribution laeuft.

Detail-Handoff: `docs/handoffs/2026-09-09-ja041-curl-live-pilot-handoff.md`
