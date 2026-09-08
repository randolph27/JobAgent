# Handoff latest

Stand: 2026-09-08T15:43:00+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Active Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`, nicht archivieren.
- Branch: `master`
- Remote: `origin/master`
- HEAD: `1523f26d7dd6`
- Supertest: nicht ausgefuehrt, weil JA-027 weiterhin offen ist.
- STP: `cmd /c .\ci.cmd stp` wurde ausgefuehrt, Exit 0.
- Roadmap-Rotation: keine Rotation, weil kein Top-Level-Roadmap-Punkt fachlich komplett erledigt ist.

## Was in diesem Chat erledigt wurde

- JA-027 Fetch-Error-Triage als eigener, reproduzierbarer Einstieg ergaenzt.
- Neu: `tools/Inspect-JobAgentFetchErrors.ps1`.
- Neu: `tests/Test-JobAgentFetchErrorInspection.ps1`.
- Das Tool liest die neuesten `JA-027-batch-*.json`- und `company-candidate-website-discovery-*.json`-Logs.
- Primaer nutzt es `fetch_error_summary`; fuer aeltere Logs baut es eine Fallback-Summary aus `results[].fetches`.
- Legacy-Fehlertexte ohne `error_class` werden deterministisch in `TLS_CREDENTIAL_UNAVAILABLE`, `TLS_HANDSHAKE_FAILED`, `TIMEOUT`, `DNS_RESOLUTION_FAILED`, `HTTP_STATUS` oder `HTTP_REQUEST_FAILED` eingeordnet.
- Dominante TLS-Fehler erzeugen `status=environment_tls_check_required`.
- Evidence erzeugt: `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json`.
- `docs/company-discovery-operations.md`, `Roadmap.md`, `todo.state.json` und Handoff wurden synchronisiert.

## Aktueller JA-027-Stand

- Retention-Schnitt JA-027.1 ist umgesetzt.
- Quelleninventar/Snapshot-Lane ist umgesetzt.
- Queue-/Retry-Grundlagen fuer JA-027.3 sind umgesetzt.
- Letzter produktiver Retrylauf vom 2026-09-08: Website-Discovery `logs/jobagent/company-candidate-website-discovery-20260908-125045.json` verarbeitete 14 Kandidaten, 0 verifiziert, 14 retryfaehig unverifiziert wegen SSL-Abruffehlern.
- Letzter Verify-Batch vom 2026-09-08: `logs/jobagent/JA-027-batch-20260908-125107.json` verarbeitete 9 Kandidaten, 27 Requests, P50 281 ms, P95 1683 ms, Nettozuwachs offizieller Karriere-/ATS-Arbeitgeber 0.
- Letzte Coverage: `logs/jobagent/company-coverage-20260908-125225.json`, `target_inventory_gate_status=passed`, `target_inventory_candidates_total=2318`, Duplicate-Groups 0, `candidate_verification_ready=0`.
- Neue Fetch-Inspection ueber fuenf Batch-/Website-Discovery-Logs: 143 fehlgeschlagene Fetches, 106 betroffene Kandidaten, dominante Fehlerklasse `TLS_HANDSHAKE_FAILED` mit 91 Fetches / 63,64 %, Status `environment_tls_check_required`.

## Offene Aufgaben fuer neuen Chat

1. TLS-Schicht ausserhalb der aktuellen Sandbox/Schannel-Umgebung gegen Beispiel-URLs aus `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json` pruefen.
2. JA-027.3 fortsetzen, sobald der naechste Retry faellig ist: ab `2026-09-10T12:51:07Z` / `2026-09-10T14:51:07+02:00`.
3. Dann ausfuehren:

~~~powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
pwsh -NoProfile -File .\tools\Inspect-JobAgentFetchErrors.ps1 -ProjectRoot .
~~~

4. Neue Logs zuerst ueber `fetch_error_summary` beziehungsweise `Inspect-JobAgentFetchErrors.ps1` auswerten.
5. JA-027 bleibt offen, bis ein belastbarer 100er-Live-Benchmark und mindestens 1.000 offiziell belegte Karriere-/ATS-Arbeitgeberquellen erreicht und dokumentiert sind.

## Weitere offene Roadmap-Punkte

- `JA-041` / `TD-0053`: IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- `UI-001` / `TD-0054`: vollstaendige Stellen- und Firmenansichten mit Filtern, Pagination und Viewport-Audit.
- `JA-042` / `TD-0055`: mindestens 1.000 Firmenkarriereseiten vollstaendig untersuchen und Wiederholung absichern.

## Verifikation in diesem Chat

- `pwsh -NoProfile -File .\tests\Test-JobAgentFetchErrorInspection.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tools\Inspect-JobAgentFetchErrors.ps1 -ProjectRoot .` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0
- `cmd /c .\ci.cmd stp` -> Exit 0
