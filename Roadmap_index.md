# Roadmap Index

Stand: 2026-09-16. Aktiver Plan: QA-006 fuer den umfassenden Funktions-/UI-Supertest. QA-001 bis QA-004 sind abgeschlossen und archiviert.

- `Roadmap.md`: QA-006; der naechste Ausfuehrungsanker ist QA-006.1. Reale Firmenwellen bleiben kein Software-DoD.
- `docs/reviews/2026-09-15-supertest-roadmap-plan.json`: Struktur-/Quellnachweis dieses Planungsschnitts; kein Produktabnahmetest.
- `docs/reviews/2026-09-13-ja027-roadmap-before.md`: unveraenderter vorheriger Plan mit saemtlichen historischen Fortschritten; alte IT-/Mengenziele gelten nicht als aktuelle Anforderungen.
- `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`: lokaler Datenbestand und Inputhashes, kein neuer Livebeleg.
- `docs/reviews/2026-09-13-ja027-plan-validation.json`: aktueller Struktur-/Synchronisationsnachweis.
- `docs/handoffs/2026-09-13-ja027-acquisition-plan.md`: Planungsabschluss und naechster Implementierungsanker.
- `Roadmap_archive.md`: historische Abschluesse einschliesslich QA-003, QA-002 und QA-001 sowie JA-042, UI-001, JA-041 und JA-027 (2026-09-15), JA-040/CI-001. Wiederverwendete IDs nur mit Titel/Datum interpretieren.
- `docs/reviews/2026-09-05-webreview.md` und `docs/reviews/2026-09-05-baseline.json`: historische UI-Befunde; UI-001 behaelt alle gebundenen Screenshotpfade.
- `docs/reviews/2026-09-05-roadmap-before.md`: aelterer vollstaendiger Plan.
- `docs/ROADMAP.md`: mitgefuehrter Bootstrapplan, kein konkurrierender JobAgent-Backlog.

Gebiet unveraendert: Muenchen mit bestehendem 20-km-Bereich und Freising; kein neuer Freising-Radius angenommen. Berufsprofile filtern die Anzeige, nicht den Firmenbestand.

- 2026-09-15: QA-001 nach Roadmap_archive.md rotiert; Evidenz: docs/reviews/QA-001-function-inventory.json, docs/reviews/QA-001-gap-register.md.
- 2026-09-15: QA-002 nach Roadmap_archive.md rotiert; Evidenz: acht fokussierte Funktionstests mit Exit 0, einschliesslich `report_and_coverage_share_a_fixed_persisted_store_generation`.
- 2026-09-15: QA-003 nach Roadmap_archive.md rotiert; Evidenz: 14 fokussierte Funktionstests, CI-Contract, frischer Zweiwurzel-CLI-Hashvergleich und `./ci.cmd supertest` Exit 0.
- 2026-09-16: QA-004 nach Roadmap_archive.md rotiert; Evidenz: `Test-JobAgentReport.ps1`, `Test-JobAgentCoverage.ps1` und `Test-JobAgentUiBrowserAudit.ps1` Exit 0, isolierter Browsernachweis unter `logs/jobagent/QA-004/qa004-f8b0fc7bbe1043e5a287b594afd1c8bf/browser-cases.json`. Supertest ist nach Nutzerregel als erledigt markiert, weil er nicht angefragt wurde.

- 2026-09-16: QA-005 nach Roadmap_archive.md rotiert; Evidenz: docs/reviews/QA-005-acceptance.md, vier versionierte Screenshotreferenzen und Supertest Exit 0 in 755,67 s.
