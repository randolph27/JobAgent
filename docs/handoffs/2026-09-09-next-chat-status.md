# Next Chat Handoff 2026-09-09

## Einstieg

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- Letzter bekannter HEAD vor Commit dieses Handoffs: `b49a1b24046d`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`, nicht archivieren. JA-027 ist nicht komplett erledigt, weil 100er-Live-Benchmark und 1.000 belegte offizielle Karriere-/ATS-Quellen noch fehlen.

## In diesem Chat erledigt

- `ConvertFrom-JobAgentCompanyVerificationCurlOutput` liest Curl-Header jetzt case-insensitive.
  - Datei: `src/JobAgent.SourceVerification.psm1`
  - Zweck: `content-type` und `retry-after` aus `curl.exe`/`wsl-curl`-Fetches gehen nicht verloren, wenn Header klein geschrieben sind.
  - Test: `tests/Test-JobAgentSourceVerification.ps1`
- `.\ci.cmd devserver-start` erkennt vorhandene Listener auf `:8500` wieder robust.
  - Datei: `.ci/bin/modules/browser-logic.ps1`
  - Grund: In dieser Umgebung lieferte `Get-NetTCPConnection` zeitweise keinen Listener, obwohl `127.0.0.1:8500` per HTTP erreichbar war und `netstat` den Listener zeigte.
  - Umsetzung: `Get-ListeningPid` nutzt weiter zuerst `Get-NetTCPConnection` und danach einen lokalisierten `netstat -ano -p tcp`-Fallback fuer `ABHOEREN/ABH...REN`.
  - Test: `tests/Test-JobAgentCiContracts.ps1`
- STP/Todo/Handoff-Sync wurde ausgefuehrt; Roadmap-Punkte wurden nicht rotiert, weil kein aktiver Punkt vollstaendig erledigt ist.

## Verifikation

Ausgefuehrt und erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentFetchEnvironment.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentFetchErrorInspection.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1
.\ci.cmd devserver-start
.\ci.cmd self-check
.\ci.cmd route-check
.\ci.cmd stp
```

Nicht ausgefuehrt:

- `.\ci.cmd supertest`: nicht angefragt; gemaess aktueller Nutzeranweisung fuer diesen Uebergabeabschluss nicht erforderlich.
- Sonar-Analyse: Projekt meldet `.\ci.cmd sonar` als `not-supported`; der Serverstatus ist kein Analysebeleg.

## Laufzeitstatus

- Devserver: `http://localhost:8500/` antwortet mit HTTP 200. `.\ci.cmd devserver-start` beendet wieder mit Exit `0` und verwendet den vorhandenen externen Listener wieder.
- SonarQube: `http://localhost:9000/api/system/status` antwortet nicht innerhalb von 5-10 Sekunden.
  - `.\ci.cmd sonar-start` scheitert mit `docker_engine_unavailable; wsl_fallback=wsl_missing`.
  - Evidence: `logs\verify\sq-005-sonarqube-wsl-fallback.md`
  - Docker API nicht erreichbar; WSL-Enumeration scheitert mit `E_ACCESSDENIED`; Portproxy auf `127.0.0.1:9000 -> 172.24.29.45:9000` existiert, Ziel ist aber nicht erreichbar.

## JA-027 Stand

- Retention umgesetzt: `discovery_inventory` und `discovered_urls`, Import-/Snapshot-/Name-only-Retention, Produktivmigration ohne unbegruendeten Firmenverlust.
- Quelleninventur/Refresh umgesetzt: 35 Registry-Quellen, 29 Snapshot-Manifesteintraege, 1.833 Hints, 1.831 Queue-Cluster, 2.312 Retention-Funde, 1.401 URL-Funde.
- Batch-/Resume-Metriken umgesetzt: `JA-027-batch-<run-id>.json`, `JA-027-resume-<run-id>.json`, Kandidaten-Telemetrie, Requestzaehlung, P50/P95, Nettozuwachs.
- HostConcurrency/Redirect-/ATS-Hostlimit umgesetzt.
- Retry-Wiederaufnahme und due-aware Coverage umgesetzt.
- Fetch-Diagnostik umgesetzt: `error_class`, `error_detail`, Exception-Typen, `fetch_error_summary`, `Inspect-JobAgentFetchErrors.ps1`, `Test-JobAgentFetchEnvironment.ps1`.
- Auto-Fetch-Fallback umgesetzt: `curl.exe`, optional `wsl-curl`, CLI-Parameter `-FetchClient` und `-WslDistribution` in Discovery und Verify.
- Offen: produktiver Retry nach Faelligkeit, 100er-Live-Benchmark, Nachfuellung bis 1.000 belegte offizielle Karriere-/ATS-Arbeitgeber, danach Abschluss/Archivierung.

## Naechster konkreter Schritt

Ab Retryfaelligkeit `2026-09-10T12:51:07Z` / `2026-09-10 14:51:07+02:00`:

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -FetchClient auto
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -FetchClient auto
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1
```

Danach pruefen:

- ob `candidate_verification_ready` wieder `0` ist oder neue faellige Kandidaten offen bleiben;
- ob `net_official_career_growth` groesser als `0` ist;
- ob Fetch-Fehler weiterhin TLS-/Umgebungsfehler sind oder echte Website-/ATS-Fehler;
- ob ein echter 100-Kandidaten-Live-Benchmark mit ausreichend faelligen Kandidaten moeglich ist.

## Offene Roadmap-/Todo-Reihenfolge

1. `TD-0041 / JA-027`: aktive Arbeit fortsetzen; keine Rotation.
2. `TD-0053 / JA-041`: IT-Leiter/Lead/Manager ueber vollstaendige Karriere-/ATS-Ergebnislisten finden; parallel pilotierbar mit vorhandenen belegten Quellen.
3. `TD-0054 / UI-001`: vollstaendige Stellen- und Firmenansichten mit Filtern; abhaengig von belastbaren Ergebnisdaten, Fixture-UI parallel moeglich.
4. `TD-0055 / JA-042`: 1.000 Firmenkarriereseiten vollstaendig live untersuchen; erst nach JA-027, JA-041 und UI-001 produktiv abnahmefaehig.

## Risiken fuer den naechsten Agenten

- SonarQube ist kein verfuegbares Gate, solange Docker/WSL/Portproxy nicht repariert sind.
- Live-Fetches koennen durch Netzwerk, TLS, Bot-Schutz, ATS-Rate-Limits und Redirect-Ketten schwanken.
- Keine kuenstliche Mengensteigerung: Domain-only, Fixtures, Alias-URLs und ungepruefte ATS-Sprachvarianten zaehlen nicht als 1.000 offizielle Karrierequellen.
- Keine Roadmap-Rotation, solange die messbaren Done-Kriterien nicht belegt sind.
