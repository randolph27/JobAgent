# JobAgent Testmatrix

Stand: 2026-08-17

Quelle der maschinenlesbaren Matrix: `docs/test-matrix.json`.

## Testvertrag

- Funktionstests laufen deterministisch mit Fixtures oder isolierten temporären Projektwurzeln.
- Live-Webrecherche ist kein Bestandteil des Supertests und bleibt bis JA-014 eine getrennte Lane.
- `.\ci.cmd supertest` bündelt nur abgeschlossene, einzeln grüne Kernfunktionen.
- Neue Roadmap-Funktionen erhalten zuerst einen fokussierten Funktionstest; danach wird `docs/test-matrix.json` und zuletzt der Supertest erweitert.

## Matrix

| Roadmap | Testdatei | Command | Supertest | Fokus |
|---|---|---|---:|---|
| JA-002 | `tests/Test-JobAgentSchema.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` | ja | Schema, Pflichtfelder, negative Fixtures, Statusvarianten |
| JA-003 | `tests/Test-JobAgentPersistence.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` | ja | Store, Transaktion, Backup, Migration, Locks, Pfadschutz |
| JA-004 | `tests/Test-JobAgentCompanyInventory.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` | ja | Seed, Idempotenz, Deduplikation, fehlende Karriere-URL |
| JA-005 | `tests/Test-JobAgentSourceAdapters.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` | ja | Adaptervertrag, Fixture-Adapter, HTML-Fixture, Fehlerklassen |
| JA-006 | `tests/Test-JobAgentSourceVerification.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` | ja | Kanonisierung, offizielle Quellen, Aggregator-Ablehnung |
| JA-007 | `tests/Test-JobAgentClassification.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentClassification.ps1` | ja | MATCH/POSSIBLE/REJECTED, Standort, Grenz- und Negativrollen |
| JA-008 | `tests/Test-JobAgentDeduplication.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` | ja | Identitätspriorität, Update, alternative URL, Neuausschreibung |
| JA-009 | `tests/Test-JobAgentStatusMachine.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` | ja | NEW/ACTIVE/UPDATED/REMOVED, Fehlerläufe, invalide Treffer |
| JA-010 | `tests/Test-JobAgentDailyRun.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` | ja | Daily-Run, isolierte Firmenfehler, Persistenz, CLI-Fixture |
| JA-011 | `tests/Test-JobAgentReport.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` | ja | Reportsektionen, Priorisierung, Filter, Leerzustand |
| JA-012 | `tests/Test-JobAgentOperations.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1` | ja | Betriebswrapper, Status, Logrotation, Parallelstartschutz |
| JA-013 | `tests/Test-JobAgentTestMatrix.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` | ja | Matrixvollständigkeit, Supertest-Synchronität, Live-Lane-Trennung |

## Live-Lane

JA-014 darf Live-Scans ergänzen, aber nicht als deterministisches Pflichtgate in `.\ci.cmd supertest` aufnehmen. Live-Nachweise werden mit begrenzter Firmenauswahl, Timeouts und separaten Artefakten unter `logs/jobagent/` geführt.
