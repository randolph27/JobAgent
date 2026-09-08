# Handoff latest

Stand: 2026-09-08T09:35:35+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD vor Abschlusscommit: `cd939670a1ca`
- Upstream: `origin/master`
- Ahead/Behind vor Abschlusscommit: `0/0`
- Route: `True`

## Neuer Chat: Sofortkontext

Der aktuelle Slice ist abgeschlossen, aber `JA-027` ist fachlich nicht abgeschlossen. Es wurde kein Roadmap-Punkt rotiert.

Fortschritt dieses Slices:

- Coverage-Ready-Metrik fuer die Kandidaten-Verifikationsqueue an die Verify-Auswahl angepasst.
- `src/JobAgent.Coverage.psm1` enthaelt jetzt `Test-JobAgentCoverageCandidateQueueEntryReady`.
- `ready_total` und `metrics.candidate_verification_ready` zaehlen nur `VERIFY_OFFICIAL_SITE`-Eintraege, die wirklich faellig sind.
- `PENDING` bleibt startbar; `RETRY_SCHEDULED` ist nur ab `next_attempt_at` startbar.
- Legacy-Datumswerte werden ueber die bestehende Coverage-Dateparserlogik toleriert.
- Regressionen fuer zukuenftige und faellige Retry-Termine wurden in `tests/Test-JobAgentCoverage.ps1` ergaenzt.

Aktueller Messstand:

- Coverage: `logs/jobagent/company-coverage-20260908-072653.json`
- Queue: `data/jobagent/company-candidate-verification.queue.json`
- `companies_total`: 487
- `official_sources`: 441
- `target_inventory_candidates_total`: 2318
- `target_inventory_gap_to_1000`: 0
- `candidate_verification_ready`: 0
- Queue `ready_total`: 0
- `RETRY_SCHEDULED`: 23
- naechster Retry: `2026-09-08T11:15:45.922Z` UTC / `2026-09-08T13:15:45+02:00`
- Target-Inventory-Gate: `failed`
- Gate-Verletzung: `SCANNABLE_COMPANY_WITHOUT_OFFICIAL_SOURCE`

## Detail-Handoff

- Ausfuehrlicher Handoff fuer den Folgechat: `docs/handoffs/2026-09-08-ja027-coverage-ready-handoff.md`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .` -> Exit 0
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0, nur CRLF-Warnungen
- `cmd /c .\ci.cmd stp` -> Exit 0
- Supertest nicht ausgefuehrt; laut Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Abschluss als erledigt.

## Bekannter Blocker

SonarQube ist nicht repariert:

- `Invoke-WebRequest http://localhost:9000/api/system/status -TimeoutSec 5` meldete Timeout.
- `cmd /c .\ci.cmd sonar-start` scheitert mit Exit 1, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt.
- Separater naechster technischer Schritt waere: lokalen `sonar.cmd`-Wrapper oder CI-Konfiguration wiederherstellen.

## Naechster Anker fuer JA-027

Ab dem Retryfenster:

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
```

Zeitanker:

- Website-Discovery-Retry ab `2026-09-08T13:15:45+02:00`
- Candidate-Verification-Retry ab `2026-09-08T13:19:32+02:00`

Wenn danach weiterhin `candidate_verification_ready=0` gilt, zuerst Queue-Eligibility und `next_attempt_at` pruefen. Nicht automatisch neue Quellen importieren, solange der Retry-/Eligibility-Befund ungeklärt ist.
