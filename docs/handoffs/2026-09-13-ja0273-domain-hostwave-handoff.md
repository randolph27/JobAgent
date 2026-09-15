# Handoff JA-027.3 Domain-only und Hostwellen

Stand: 2026-09-13T19:59:07+02:00

## Ergebnis

- Domain-only-Bestandsfirmen mit fehlender `career_url` werden in `New-JobAgentCoverageCandidateReviewQueueEntry` nicht mehr dauerhaft als `ALREADY_VERIFIED_IN_STORE`/`VERIFIED` ausgeblendet, sondern als `VERIFY_CAREER_SOURCE` mit `PENDING` reaktiviert.
- `Verify-JobAgentCompanyCandidates.ps1` akzeptiert `VERIFY_CAREER_SOURCE` als startbare Queue-Aktion.
- HostConcurrency kuerzt den logischen Batch nicht mehr: die vorherige Nachauswahl ueber `Select-ToolHostLimitedCandidates` wurde aus dem Ablauf genommen; stattdessen wird `logical_host_waves` protokolliert.
- Batchsummary und Metriken weisen offizielle Karriere-/ATS-Erfolge und Domain-only-Erfolge getrennt aus: `official_career_verified_total`, `domain_only_verified_total`, `official_career_verified_candidate_ids`, `domain_only_candidate_ids`.
- Wenn ein reiner Karrierequellen-Pruefauftrag erneut nur Domain-Erreichbarkeit bestaetigt, bleibt der Queueeintrag als `MANUAL_REVIEW_REQUIRED` mit `CAREER_SOURCE_MISSING_AFTER_DOMAIN_VERIFICATION` sichtbar und wird nicht als erledigte Karrierequelle gezaehlt.

## Dateien

- `src/JobAgent.Coverage.psm1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `logs/jobagent/JA-027-acquisition-20260913-195907.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`

## Blocker

- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `1`
- Ursache: lokaler Chrome-Headless-Abbruch bei 1920 px mit `GPU process isn't usable`.
- JA-027 bleibt deshalb offen und wird nicht archiviert; Supertest wurde nicht gestartet.

## Naechster Anker

Viewport-Audit-Lane stabilisieren oder alternative lokale Browser-Lane konfigurieren; danach JA-027-Abschlussgate und Supertest erneut ausfuehren.
