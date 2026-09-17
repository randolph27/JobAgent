# Roadmap Index

Stand: 2026-09-17. Aktiver Backlog: SQ-007 und SQ-008. SQ-006 dokumentiert den fail-closed SonarQube-Lieferkettenvertrag; die Artefakte sind bewusst noch nicht installiert. QA-007 dokumentiert die sicherheitsverträgliche CI-005-Testkorrektur und QA-008 das kanonisch regenerierte Funktionsinventar.

- `Roadmap.md`: enthält nur die aktiven Punkte SQ-007 und SQ-008.
- `docs/reviews/SQ-006-analysis-supply-chain.md` und `docs/reviews/SQ-006-toolchain.json`: Quellen, Analysegrenzen, zugelassene Projektwurzel und geplanter, noch nicht installierter Artefaktvertrag.
- `docs/reviews/QA-007-acceptance.md`: Ursache, sicherheitsverträgliche Teständerung und sekretfreies Ergebnis des vollständigen Supertests.
- `docs/reviews/QA-008-acceptance.md`: Inventardiffklasse, Generatorlauf und Matrix-/Runner-Vertrag.
- `docs/reviews/2026-09-15-supertest-roadmap-plan.json`: Struktur-/Quellnachweis dieses Planungsschnitts; kein Produktabnahmetest.
- `docs/reviews/2026-09-13-ja027-roadmap-before.md`: unveraenderter vorheriger Plan mit saemtlichen historischen Fortschritten; alte IT-/Mengenziele gelten nicht als aktuelle Anforderungen.
- `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`: lokaler Datenbestand und Inputhashes, kein neuer Livebeleg.
- `docs/reviews/2026-09-13-ja027-plan-validation.json`: aktueller Struktur-/Synchronisationsnachweis.
- `docs/handoffs/2026-09-13-ja027-acquisition-plan.md`: Planungsabschluss und naechster Implementierungsanker.
- `Roadmap_archive.md`: historische Abschlüsse einschließlich SQ-001 (2026-09-16), QA-003, QA-002 und QA-001 sowie JA-042, UI-001, JA-041 und JA-027 (2026-09-15), JA-040/CI-001. Wiederverwendete IDs nur mit Titel/Datum interpretieren.
- `docs/reviews/2026-09-05-webreview.md` und `docs/reviews/2026-09-05-baseline.json`: historische UI-Befunde; UI-001 behaelt alle gebundenen Screenshotpfade.
- `docs/reviews/2026-09-05-roadmap-before.md`: aelterer vollstaendiger Plan.
- `docs/ROADMAP.md`: mitgefuehrter Bootstrapplan, kein konkurrierender JobAgent-Backlog.

Gebiet unveraendert: Muenchen mit bestehendem 20-km-Bereich und Freising; kein neuer Freising-Radius angenommen. Berufsprofile filtern die Anzeige, nicht den Firmenbestand.

- 2026-09-15: QA-001 nach Roadmap_archive.md rotiert; Evidenz: docs/reviews/QA-001-function-inventory.json, docs/reviews/QA-001-gap-register.md.
- 2026-09-15: QA-002 nach Roadmap_archive.md rotiert; Evidenz: acht fokussierte Funktionstests mit Exit 0, einschliesslich `report_and_coverage_share_a_fixed_persisted_store_generation`.
- 2026-09-15: QA-003 nach Roadmap_archive.md rotiert; Evidenz: 14 fokussierte Funktionstests, CI-Contract, frischer Zweiwurzel-CLI-Hashvergleich und `./ci.cmd supertest` Exit 0.
- 2026-09-16: QA-004 nach Roadmap_archive.md rotiert; Evidenz: `Test-JobAgentReport.ps1`, `Test-JobAgentCoverage.ps1` und `Test-JobAgentUiBrowserAudit.ps1` Exit 0, isolierter Browsernachweis unter `logs/jobagent/QA-004/qa004-f8b0fc7bbe1043e5a287b594afd1c8bf/browser-cases.json`. Supertest ist nach Nutzerregel als erledigt markiert, weil er nicht angefragt wurde.

- 2026-09-16: QA-005 nach Roadmap_archive.md rotiert; Evidenz: docs/reviews/QA-005-acceptance.md, vier versionierte Screenshotreferenzen und Supertest Exit 0 in 755,67 s.

- 2026-09-16: CI-002 bis CI-004 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/CI-004-acceptance.md, projektlokale Playwright-Laufzeitpins und fokussierte Funktionstests. Vollsupertest gemäß Nutzerregel als erledigt.
- 2026-09-16: CI-005 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/CI-005-acceptance.md, zielgerichtete Immutable-Snapshot-Synchronisierung und vier isolierte Negativtests. Vollsupertest gemäß Nutzerregel nicht ausgeführt.
- 2026-09-16: SQ-001 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/SQ-001-acceptance.md, SonarQube 9.9.8 `UP`, gültiger externer Token/API-Read, offizielle 9.9-Sprachübersicht ohne PowerShell und 31/31 funktionsbezogene Tests. Kein Codescan oder Quality Gate wird behauptet; Vollsupertest gemäß Nutzerregel als erledigt bewertet.

- 2026-09-17: SQ-002 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/SQ-002-acceptance.md, Token-Normalisierung und `./ci.cmd sonar-auth` mit `valid:true`. Kein Codescan oder Quality Gate wird behauptet; Vollsupertest gemäß Nutzerregel als erledigt bewertet.
- 2026-09-17: QA-007 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/QA-007-acceptance.md, `Test-Ci005Invariants.ps1` ohne Fixture-Kopien, Datei-Mutationen, rekursive Löschung oder verschachtelte CI-Starts sowie `./ci.cmd supertest` mit 29/29 Fällen und Exit 0 in 692,59 s.
- 2026-09-17: QA-008 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/QA-008-acceptance.md, kanonisch durch `-WriteInventory` erzeugtes QA-001-Inventar mit 577 Einträgen, Matrix- und Runner-Vertrag mit Exit 0 sowie derselbe Vollsupertest 29/29.
- 2026-09-17: SQ-006 nach Roadmap_archive.md rotiert; Evidence: docs/reviews/SQ-006-analysis-supply-chain.md, docs/reviews/SQ-006-toolchain.json, fail-closed `Test-SonarToolchain.ps1` und Supertest 29/29. Die Toolchain bleibt ohne separat autorisierte Beschaffung `not-installed`.

