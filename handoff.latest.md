# Handoff latest

Stand: 2026-09-06T17:33:22+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD: `304b38e349dd`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `clean`
- Route: `True`

## Ergebnis dieses Arbeitsschritts

JA-027.1 Retention-Schnitt ist umgesetzt, aber JA-027 bleibt offen. `jobagent/v1` enthaelt jetzt `discovery_inventory` und `discovered_urls`; Seed-/Discovery-Importe schreiben dauerhafte Firmen- und URL-Funde idempotent mit Herkunft, Zeitstempeln, Hash und Status. Snapshot-Refreshes loeschen nicht erneut beobachtete Hints nicht mehr, sondern markieren sie als `NOT_OBSERVED_IN_SOURCE`. Unverifizierte Name-only-Hints werden als dauerhafte Company-Kandidaten mit `promoted_to_company=false` gespeichert, ohne produktive `companies` oder `job_sources` vorzutäuschen.

Produktivmigration: `data/jobagent/store.json` wurde mit Backups `data/jobagent/backups/store-20260906T110833936Z-ja027-retention-migration.json` und `data/jobagent/backups/store-20260906T152824952Z-ja027-hint-retention-migration.json` migriert. Ergebnis: 479 Firmen vorher/nachher, 439 JobSources vorher/nachher, 2.269 Discovery-Funde, 1.401 URL-Funde, unbegruendeter Firmenverlust 0.

Evidence: `logs/jobagent/JA-027-retention-migration.json`, `logs/jobagent/JA-027-retention-regression.json`.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentPersistence.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit 0
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0
- `cmd /c .\ci.cmd stp` -> Exit 0

Supertest wurde gemaess Nutzerregel nicht ausgefuehrt, weil JA-027 nicht abgeschlossen ist.

## Naechster Anker

Naechster fachlicher Schritt: JA-027.2 Quellenerschliessung/Source-Inventur und danach JA-027.3 Verifikation/Benchmark. JA-027 bleibt bis 1.000 belegte offizielle Karrierequellen offen.
