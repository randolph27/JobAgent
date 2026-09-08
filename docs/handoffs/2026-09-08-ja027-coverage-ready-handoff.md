# JA-027 Handoff: Coverage-Ready-Semantik

Stand: 2026-09-08T09:30:21+02:00

## Aktiver Stand

- Aktives Todo: `TD-0041`
- Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`
- Branch/HEAD bei Abschluss-Slice: `master` / `cd939670a1ca`
- Upstream: `origin/master`, Ahead/Behind vor Commit: `0/0`

## Umgesetzter Slice

Die Coverage-Ready-Metrik fuer die Kandidaten-Verifikationsqueue wurde an die bereits implementierte Verifikationsauswahl angeglichen.

- Neue zentrale Funktion in `src/JobAgent.Coverage.psm1`: `Test-JobAgentCoverageCandidateQueueEntryReady`.
- `New-JobAgentCoverageCandidateReviewQueue` berechnet `ready_total` jetzt mit dieser Funktion.
- `New-JobAgentCoverageReport` berechnet `metrics.candidate_verification_ready` ebenfalls mit dieser Funktion.
- Semantik:
  - `PENDING` + `VERIFY_OFFICIAL_SITE` ist bereit, wenn kein spaeteres `next_attempt_at` gesetzt ist oder der Zeitpunkt faellig ist.
  - `RETRY_SCHEDULED` + `VERIFY_OFFICIAL_SITE` ist nur bereit, wenn `next_attempt_at <= Now`.
  - `DISCOVER_OFFICIAL_WEBSITE`, `MANUAL_DECISION`, `ALREADY_VERIFIED_IN_STORE`, `MANUAL_REVIEW_REQUIRED`, `VERIFIED` und `RETRY_EXHAUSTED` zaehlen nicht als startbereite Kandidaten fuer die Karriere-/ATS-Verifikation.
  - Legacy-Datumswerte werden tolerant ueber `ConvertTo-JobAgentCoverageDate` gelesen.

Damit melden Coverage und `tools/Verify-JobAgentCompanyCandidates.ps1` keinen Widerspruch mehr: zukuenftige Retry-Termine erscheinen nicht mehr als sofort startbereit.

## Aktuelle Artefakte

- Coverage-JSON: `logs/jobagent/company-coverage-20260908-072653.json`
- Coverage-Markdown: `logs/jobagent/company-coverage-20260908-072653.md`
- Coverage-HTML: `html/jobagent/company-coverage.html`
- Queue: `data/jobagent/company-candidate-verification.queue.json`

Aktuelle Kernzahlen aus dem letzten Coverage-Lauf:

- `companies_total`: 487
- `official_sources`: 441
- `target_inventory_candidates_total`: 2318
- `target_inventory_gap_to_1000`: 0
- `candidate_verification_ready`: 0
- Queue `ready_total`: 0
- `RETRY_SCHEDULED`: 23
- naechster Retry: `2026-09-08T11:15:45.922Z` / `2026-09-08T13:15:45+02:00`
- Target-Inventory-Gate: `failed`
- Gate-Verletzung: `SCANNABLE_COMPANY_WITHOUT_OFFICIAL_SOURCE`

## Tests

Ausgefuehrt und gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
git -c core.pager=cat -c color.ui=false --no-pager diff --check
```

`diff --check` meldete nur CRLF-Warnungen, keine Whitespace-Fehler.

Supertest wurde nicht ausgefuehrt, weil `JA-027` fachlich noch offen ist; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Abschluss als erledigt.

## Nicht erledigt

`JA-027` ist nicht komplett abgeschlossen und wurde nicht rotiert.

Offen bleiben:

- 100er-Live-Benchmark mit tatsaechlich faelligen Kandidaten.
- 1.000 belegte offizielle Karriere-/ATS-Arbeitgeberquellen.
- Gate-Fix fuer `SCANNABLE_COMPANY_WITHOUT_OFFICIAL_SOURCE`.
- SonarQube-Reparatur: `cmd /c .\ci.cmd sonar-start` scheitert, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt; API-Check auf `http://localhost:9000/api/system/status` lief in Timeout.

## Naechster konkreter Schritt

Ab dem Retryfenster die produktiven Wiederaufnahmen starten:

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
```

Zeitanker:

- Website-Discovery-Retry ab `2026-09-08T13:15:45+02:00`
- Candidate-Verification-Retry ab `2026-09-08T13:19:32+02:00`

Wenn danach weiterhin `candidate_verification_ready=0` gilt, zuerst Queue-Eligibility und `next_attempt_at` pruefen, nicht sofort neue Quellen importieren.
