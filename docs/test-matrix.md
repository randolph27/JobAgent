# JobAgent Testmatrix

Stand: 2026-08-23

Quelle der maschinenlesbaren Matrix: `docs/test-matrix.json`.

## Testvertrag

- Funktionstests laufen deterministisch mit Fixtures oder isolierten temporären Projektwurzeln.
- Live-Webrecherche ist kein Bestandteil des Supertests; `Test-JobAgentLiveScan.ps1` nutzt deterministische Adapter-/HTTP-Fixtures.
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
| JA-014 | `tests/Test-JobAgentLiveScan.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` | ja | Live-Policy, offizielle Kandidatenfilterung, Detailseitenprüfung, Retry-Protokoll |
| JA-015 | `tests/Test-JobAgentCoverage.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` | ja | Coverage-Metriken, Adapter-Backlog, Scanpriorisierung, Rotationslogik |
| JA-024 | `tests/Test-JobAgentRegisterDiscovery.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentRegisterDiscovery.ps1` | ja | Register-Fixtures, Zielgebietsfilter, Dedupe, Snapshot-Freshness, personenbezogene Feldsperre |
| JA-025 | `tests/Test-JobAgentJobBoardDiscovery.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentJobBoardDiscovery.ps1` | ja | Jobboersen-Fixtures, Source-Policy, Pagination, Dedupe, Personaldienstleister, minimale Hash-Evidenz |
| JA-026 | `tests/Test-JobAgentRegionalDiscovery.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1` | ja | Regionale Tabellen-/Karten-/JSON-Fixtures, Source-Policy, Zielgebiet, Dedupe, minimale Hash-Evidenz ohne Kontaktdaten |
| JA-027 | `tests/Test-JobAgentCompanyDedupeScale.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentCompanyDedupeScale.ps1` | ja | Skalierte Kandidaten-Cluster, starke Identitaetskeys, Konfliktflags, Review-Queue, 5.000+ Kandidaten |
| JA-029 | `tests/Test-JobAgentImportWaves.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentImportWaves.ps1` | ja | Importwellen-Konfiguration, produktive Gate-Pruefung, Rollback-Backup, fail-closed CLI ohne Store-Aenderung |

## Live-Lane

JA-014 ergänzt Live-Scan-Logik mit deterministischen Fixtures im Supertest. Echte Live-Nachweise bleiben getrennt, laufen mit begrenzter Firmenauswahl und werden unter `logs/jobagent/` geführt.
