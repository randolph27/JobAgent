# Handoff latest

Stand: 2026-09-08T19:49:06.315+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Active Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`, nicht archivieren.
- Branch: `master`
- HEAD: `siehe aktueller Git-HEAD`
- Supertest: nicht ausgefuehrt, weil JA-027 weiterhin offen ist.
- STP: `cmd /c .\ci.cmd stp` wurde ausgefuehrt, Exit 0.
- Roadmap-Rotation: keine Rotation, weil kein Top-Level-Roadmap-Punkt fachlich komplett erledigt ist.

## Was in diesem Chat erledigt wurde

- Neu: `tools/Test-JobAgentFetchEnvironment.ps1`.
- Neu: `tests/Test-JobAgentFetchEnvironment.ps1`.
- Das Tool nimmt TLS-Beispiel-URLs aus `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json` und prueft sie getrennt mit PowerShell/.NET und `curl.exe`.
- Evidence erzeugt: `logs/jobagent/JA-027-fetch-environment-20260908-174432.json`.
- Ergebnis des Live-Probes: fuenf Beispiel-URLs geprueft; .NET und `curl.exe` scheitern jeweils mit `SEC_E_NO_CREDENTIALS`; Status `all_probe_clients_failed`.
- SonarQube auf `localhost:9000` meldet `UP`; Devserver auf Port `8500` lauscht.
- `docs/company-discovery-operations.md`, `Roadmap.md`, `todo.state.json` und Handoff wurden synchronisiert.

## Aktueller JA-027-Stand

- Retention-Schnitt JA-027.1 ist umgesetzt.
- Quelleninventar/Snapshot-Lane ist umgesetzt.
- Queue-/Retry-Grundlagen fuer JA-027.3 sind umgesetzt.
- Fetch-Inspection `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json`: 143 fehlgeschlagene Fetches, dominante Fehlerklasse `TLS_HANDSHAKE_FAILED` mit 91 Fetches / 63,64 %, Status `environment_tls_check_required`.
- Fetch-Environment-Probe `logs/jobagent/JA-027-fetch-environment-20260908-174432.json`: `all_probe_clients_failed`; lokale Windows-Schannel/TLS-Credentials sind die aktuelle Blockade, nicht ein belegter fachlicher Quellenfehler.
- Letzte Coverage: `logs/jobagent/company-coverage-20260908-125225.json`, `target_inventory_gate_status=passed`, `target_inventory_candidates_total=2318`, Duplicate-Groups 0, `candidate_verification_ready=0`.

## Offene Aufgaben fuer neuen Chat

1. Windows-Schannel/TLS-Credentials ausserhalb des Projektcodes reparieren oder einen kontrollierten alternativen Fetchpfad belegen.
2. Danach erneut ausfuehren:

~~~powershell
pwsh -NoProfile -File .\tools\Test-JobAgentFetchEnvironment.ps1 -ProjectRoot . -InspectionPath logs\jobagent\JA-027-fetch-error-inspection-20260908-153700.json -MaxUrls 5
~~~

3. JA-027.3 erst nach erfolgreichem Environment-Probe fortsetzen, fruehestens ab `2026-09-10T12:51:07Z` / `2026-09-10T14:51:07+02:00`:

~~~powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
pwsh -NoProfile -File .\tools\Inspect-JobAgentFetchErrors.ps1 -ProjectRoot .
~~~

4. JA-027 bleibt offen, bis ein belastbarer 100er-Live-Benchmark und mindestens 1.000 offiziell belegte Karriere-/ATS-Arbeitgeberquellen erreicht und dokumentiert sind.

## Weitere offene Roadmap-Punkte

- `JA-041` / `TD-0053`: IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- `UI-001` / `TD-0054`: vollstaendige Stellen- und Firmenansichten mit Filtern, Pagination und Viewport-Audit.
- `JA-042` / `TD-0055`: mindestens 1.000 Firmenkarriereseiten vollstaendig untersuchen und Wiederholung absichern.

## Verifikation in diesem Chat

- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchEnvironment.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tools\Test-JobAgentFetchEnvironment.ps1 -ProjectRoot . -InspectionPath logs\jobagent\JA-027-fetch-error-inspection-20260908-153700.json -MaxUrls 5` -> Exit 0, Status `all_probe_clients_failed`
- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchErrorInspection.ps1` -> Exit 0
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0
- `curl.exe -s http://localhost:9000/api/system/status` -> Exit 0, Status `UP`
- `cmd /c .\ci.cmd devserver-status` -> Exit 0, Port `8500` listening
- `cmd /c .\ci.cmd stp` -> Exit 0


