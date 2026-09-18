# JobAgent Testmatrix

Stand: 2026-09-15 — QA-001

Quelle der maschinenlesbaren Matrix: `docs/test-matrix.json`.

## Testvertrag

- Funktionstests laufen deterministisch mit Fixtures oder isolierten temporären Projektwurzeln.
- Live-Webrecherche ist kein Bestandteil des Supertests; `Test-JobAgentLiveScan.ps1` nutzt deterministische Adapter-/HTTP-Fixtures.
- `.\ci.cmd supertest` bündelt nur abgeschlossene, einzeln grüne Kernfunktionen.
- Neue Roadmap-Funktionen erhalten zuerst einen fokussierten Funktionstest; danach wird `docs/test-matrix.json` und zuletzt der Supertest erweitert.
- Jede Fall-ID in der Matrix enthält Funktions- oder Control-Referenzen, Fixture, Eingabe, Sollwirkung, Negativfall, Lane, Abhängigkeiten und Status. `planned` ist kein bestandener Test.
- Deterministische Bedingungen: `UTC`, fixer Bezugspunkt `2026-01-15T12:00:00Z`, Locale `de-DE`, Seed `jobagent-qa-fixture-v1` und ausschließlich vorab geprüfte lokale Tools. Sonar ist `not-supported`; Android ist für den Webbericht `not-applicable`.
- Das kanonische, hashgebundene AST-/Control-Inventar steht in `docs/reviews/QA-001-function-inventory.json`. Es enthält Produktmodule, JobAgent-CLI-Tools, HTML-Controls sowie die Kategorie jeder JobAgent-Testdatei.

## QA-Fallzuordnung

| Fall-ID | Verantwortlich | Lane | Funktionsbereich | Status |
|---|---|---|---|---|
| QA001-CONTRACT-001 bis QA001-CONTRACT-002 | QA-002 | deterministic-fixture | Persistenz, Identität, Status | planned |
| QA001-CONTRACT-003 bis QA001-CONTRACT-005 | QA-003 | contract / deterministic-fixture | Quellen, Adapter, Retry, Daily-Run | planned |
| QA001-UI-001 bis QA001-UI-002 | QA-004 | local-browser | Suche, Tabs, Pagination, Reset | planned |
| QA001-ACCESSIBILITY-001 | QA-005 | local-browser | 390/800/1366/1920, Fokus und Geometrie | planned |
| QA001-AGGREGATOR-001 | QA-006 | contract | Matrixauswahl und Aggregator | planned |

Die detaillierten Vorbedingungen, Eingaben, Sollwerte und Negativfälle sind maschinenlesbar in `docs/test-matrix.json` hinterlegt. Die geplanten Fälle werden erst durch ihren jeweiligen QA-Punkt implementiert und ausgeführt.

## Matrix

| Roadmap | Testdatei | Command | Supertest | Fokus |
|---|---|---|---:|---|
| JA-002 | `tests/Test-JobAgentSchema.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` | ja | Schema, Pflichtfelder, negative Fixtures, Statusvarianten |
| CI-002 | `tests/Test-JobAgentSchemaTooling.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSchemaTooling.ps1` | ja | Projektlokale AJV-CLI, Cache-Isolation, Umgebungsrestauration, fehlende CLI fail-closed |
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
| JA-027.2 | `tests/Test-JobAgentDiscoverySourceInventory.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentDiscoverySourceInventory.ps1` | ja | Quelleninventur, Hint-/Queue-Abgleich, kleine Bestaende, Recherchematrix, fail-closed Quellen |
| JA-029 | `tests/Test-JobAgentImportWaves.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentImportWaves.ps1` | ja | Importwellen-Konfiguration, produktive Gate-Pruefung, Rollback-Backup, fail-closed CLI ohne Store-Aenderung |
| JA-045 | `tests/Test-JobAgentUserState.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentUserState.ps1` | ja | Browserlokaler v1-Zustand, vier Markierungskombinationen, Feldzeitstempel, Export/Import, Speicherfehler und Tab-Synchronisation |
| JA-053 | `tests/Test-JobAgentChangeHistoryBrowserAudit.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentChangeHistoryBrowserAudit.ps1` | ja | Isolierte Quellenchronik mit 0/20/21 Eintraegen, Vorher/Nachher-Klartext, Tastatur, Erweiterung, Viewports und Bediennetzwerk-Guard |
| JA-053-Projektion | `tests/Test-JobAgentChangeHistory.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentChangeHistory.ps1` | ja | Deterministische Snapshot-/Event-Projektion, Mehrfelddiff, fehlender Altsnapshot, 20-von-21-Grenze und Idempotenz |
| JA-049-Publikation | `tests/Test-JobAgentPublication.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentPublication.ps1` | nein | Stabiler Einstieg, einheitlicher Generationshash und atomarer Unterbrechungsschutz |
| JA-054-Kalender | `tests/Test-JobAgentCalendar.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentCalendar.ps1` | nein | Retry- und Tagesprojektion, geplante Pruefung, stabile Reportreferenz und HTML-Vertrag |
| JA-054-Kalender-Browser | `tests/Test-JobAgentCalendarBrowserAudit.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentCalendarBrowserAudit.ps1` | nein | Lokale Kalenderbedienung, Tastaturpfad, vier Viewports und kein Produktnetzwerk |
| JA-056 | `tests/Test-JobAgentSavedSearches.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentSavedSearches.ps1` | ja | Baseline, generationengebundene Treffer, expliziter Sichtungsstand, kanonischer Filterresolver |
| UI-001 | `tests/Test-JobAgentUiBrowserAudit.ps1` | `pwsh -NoProfile -File tests\Test-JobAgentUiBrowserAudit.ps1` | ja | Lokale Browser-Fixture mit 251 Firmen/256 Stellen, Filterkombinationen, UNKNOWN, Umlautsuche, Pagination, Reset, Ruecknavigation, Store- und Request-Invarianz sowie 390/800/1366/1920 px |

## Live-Lane

JA-014 ergänzt Live-Scan-Logik mit deterministischen Fixtures im Supertest. UI-001 nutzt ausschliesslich eine lokal erzeugte HTML-Fixture auf dem CI-Devserver; es findet keine Live-Webrecherche statt. Echte Live-Nachweise bleiben getrennt, laufen mit begrenzter Firmenauswahl und werden unter `logs/jobagent/` geführt.
