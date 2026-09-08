# Handoff latest

Stand: 2026-09-08T15:12:00+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Branch: `master`
- HEAD vor Commit: `80cfd5cbd4bb`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Abschluss: `dirty`
- Route: `True`

## Abgeschlossener Slice

- `sonar.cmd` wurde als lokaler SonarQube-Wrapper ergaenzt.
- `.\ci.cmd sonar-start` ist nicht mehr durch fehlenden Wrapper blockiert.
- SonarQube war unter `http://localhost:9000/api/system/status` mit Status `UP` erreichbar.
- `.\ci.cmd devserver-start` hat den bestehenden Listener auf `http://localhost:8500/` wiederverwendet.
- Port `8090` war nicht belegt; fuer dieses Projekt ist laut CI-Konfiguration Port `8500` der Devserver-Port.
- Coverage-Gate-Konflikt fuer bestaetigte Discovery-Hints geschlossen: verifizierte `CAREER_URL_VERIFIED`/`COMPANY_DOMAIN_VERIFIED`/`OFFICIAL_ATS_VERIFIED`-Firmen mit urspruenglichem `DISCOVERY_HINT` werden nicht mehr als manuelle Review-Konflikte behandelt.
- Neue Coverage-Evidence: `logs/jobagent/company-coverage-20260908-125225.json`, `target_inventory_gate_status=passed`, `target_inventory_candidates_total=2318`, Duplicate-Groups `0`, `candidate_verification_ready=0`.
- Faellige JA-027-Retries wurden ausgefuehrt: Website-Discovery `logs/jobagent/company-candidate-website-discovery-20260908-125045.json` verarbeitete 14 Kandidaten, 0 verifiziert, 14 retryfaehig unverifiziert wegen SSL-Abruffehlern.
- Verify-Batch `logs/jobagent/JA-027-batch-20260908-125107.json` verarbeitete 9 Kandidaten, 27 Requests, P50 281 ms, P95 1683 ms, Nettozuwachs offizieller Karriere-/ATS-Arbeitgeber `0`.
- HTTP-/TLS-Fehlerdiagnose fuer JA-027-Fetches implementiert: Fetches tragen kuenftig `error_class`, `error_detail` und `exception_types`.
- `SEC_E_NO_CREDENTIALS` wird als `TLS_CREDENTIAL_UNAVAILABLE` klassifiziert; generische TLS-, Timeout-, DNS- und HTTP-Fehler bleiben getrennt auswertbar.
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1` und `tools/Verify-JobAgentCompanyCandidates.ps1` schreiben diese Felder in Website-Discovery- und JA-027-Batchlogs.
- Fixture-Fetcher liefern bei fehlenden Fixtures `HTTP_STATUS`, damit Logschema und Regressionen deterministisch pruefbar sind.
- STP wurde ausgefuehrt: `cmd /c .\ci.cmd stp` -> Exit 0.

## Roadmap/Todo

- `JA-027` / `TD-0041` bleibt offen. Nicht abgeschlossen sind der belastbare 100er-Live-Benchmark und das Ziel von mindestens 1.000 offiziell belegten Karriere-/ATS-Arbeitgeberquellen.
- Kein Roadmap-Punkt wurde rotiert, weil kein offener Punkt vollstaendig fachlich erledigt ist.
- `JA-041` / `TD-0053` bleibt offen: vollstaendige Karriere-/ATS-Listen, Pagination, iframe/ATS und Rollen-/Standortklassifikation.
- `UI-001` / `TD-0054` bleibt offen: vollstaendige Firmen-/Stellenansicht mit Filtern, Pagination und Viewport-Audit.
- `JA-042` / `TD-0055` bleibt offen: nachweisbarer 1.000er-Live-Scan und Wiederholungssicherheit.
- Supertest wurde gemaess Nutzeranweisung fuer diesen Chat nicht als Blocker behandelt; kein vollstaendiger JA-027-Abschlusslauf wurde ausgefuehrt.

## Naechster Anker

Naechster Retry-Zeitpunkt:

- Candidate-Verification-Retry ab `2026-09-10T12:51:07Z` / `2026-09-10T14:51:07+02:00`

Fortsetzung:

~~~powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
~~~

Danach neue Fetchlogs nach `error_class`, `error_detail` und `exception_types` auswerten. Wenn `TLS_CREDENTIAL_UNAVAILABLE` nur in der Sandbox auftritt, Live-Retries ausserhalb der Sandbox beziehungsweise ueber die zugelassene Projekt-/CI-Umgebung laufen lassen.

## Verifikation

- `cmd /c .\sonar.cmd status` -> Exit 0, Status `UP`
- `cmd /c .\sonar.cmd start` -> Exit 0, vorhandener Server wiederverwendet
- `cmd /c .\ci.cmd sonar-start` -> Exit 0
- `Invoke-WebRequest http://localhost:9000/api/system/status -TimeoutSec 10` -> Exit 0, Status `UP`
- `cmd /c .\ci.cmd devserver-start` -> Exit 0, Listener `http://localhost:8500/`
- `Invoke-WebRequest http://localhost:8500/ -TimeoutSec 5` -> Exit 0
- `Test-NetConnection 127.0.0.1 -Port 8090` -> `TcpTestSucceeded=false`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100` -> Exit 0, 14 verarbeitet, 0 verifiziert
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1` -> Exit 0, 9 verarbeitet, Nettozuwachs 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .` -> Exit 0, `target_inventory_gate_status=passed`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0
- `cmd /c .\ci.cmd stp` -> Exit 0
