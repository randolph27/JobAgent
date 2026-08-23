# Handoff latest

Stand: 2026-08-23T10:56:49.388+02:00

## Zustand

- Active: `TD-0027`
- Status: `in-progress`
- Ziel: JA-027 Deduplikation, Standortlogik und Kandidatenqualitaet fuer tausende Firmen skalieren.
- Branch: `master`
- HEAD vor Abschluss-Commit: `3b3906f6385b`
- Upstream: `origin/master`
- STP: `.\ci.cmd stp` lief am 2026-08-23T10:56:49+02:00 mit Exit `0`.

## Aktueller Arbeitsstand

JA-027 ist nicht vollstaendig abgeschlossen und wurde nicht aus `Roadmap.md` rotiert. Erledigt ist der erste belastbare Teil: ein skalierbarer Kandidaten-Merge fuer Register-, Jobboersen- und Regional-Hints mit stabilen Clustern, starken Identitaetskeys, Review-Queue-Gruenden und Performance-Test mit 5.008 Kandidaten.

Implementiert:

- `src/JobAgent.CompanyInventory.psm1`
  - `ConvertTo-JobAgentCompanyCandidateRecord`
  - `Resolve-JobAgentCompanyCandidateClusters`
  - Mapping fuer `target_area_basis`: `REGISTER_SEAT_IN_TARGET`, `JOB_LOCATION_IN_TARGET`, `BRANCH_HINT_IN_TARGET`, `REMOTE_WITH_TARGET_REFERENCE`, `TARGET_UNCERTAIN`, `OUT_OF_SCOPE`
  - Konfliktflags: `NAME_MATCH_WITHOUT_STRONG_IDENTITY`, `STAFFING_AGENCY_REVIEW`, `TARGET_AREA_UNCERTAIN`, `OUT_OF_SCOPE_HINT`
  - starke Merge-Keys nur fuer `domain:*`, `register:*`, `company_id:*`; reine Namensgleichheit erzeugt Review-Konflikt statt automatischem Merge.
- `schemas/jobagent.schema.json`
  - optionale Company-Felder fuer `identity_cluster_id`, `dedupe_keys`, `conflict_flags`, `target_area_basis`, `source_count`, `first_seen_at`, `last_seen_at`, `review_queue_reason`.
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
  - deckt Register-ID-Merge, Domain-Merge, Nicht-Merge bei gleicher Firma ohne starke Identitaet, Personaldienstleister-Flag, unsicheren Zielraum, stabile Cluster-IDs und 5.000+ Kandidaten ab.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`, 5.008 Kandidaten, 5.006 Cluster, ca. 5.086 ms
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` wurde in diesem Schritt nicht angefragt und gemaess Nutzeranweisung nicht als Blocker gewertet.

## Nicht erledigt fuer JA-027

- Cluster-Report ist noch nicht in `src/JobAgent.Coverage.psm1` integriert.
- `data/jobagent/company-discovery.hints.json` wird noch nicht dauerhaft um Cluster-IDs oder Review-Queue-Ergebnisse angereichert.
- Es gibt noch kein Tool/CLI-Artefakt fuer Dedupe-Report, Konfliktliste und Performance-Messung ausser dem Funktionstest.
- `docs/test-matrix.json` und Supertest-Lane enthalten `Test-JobAgentCompanyDedupeScale.ps1` noch nicht; erst aufnehmen, wenn JA-027 vollstaendig abgeschlossen wird.
- Roadmap-Unterpunkte fuer JA-027 sind noch nicht abgehakt; keine Rotation nach `Roadmap_archive.md`.

## Naechster konkreter Schritt

1. `Resolve-JobAgentCompanyCandidateClusters` an reale Hint-Stores anbinden: `data/jobagent/company-discovery.hints.json` einlesen, Cluster-Report erzeugen, Review-Queue schreiben.
2. `src/JobAgent.Coverage.psm1` erweitern: Clusterzahlen, Konfliktliste, `target_area_basis`, `source_count` und Review-Queue in Coverage-Metriken aufnehmen.
3. CLI/Tool fuer Dedupe-Report erstellen, z.B. `tools/Measure-JobAgentCompanyCandidateDedupe.ps1`, mit JSON-/Markdown-Artefakt unter `logs/jobagent/`.
4. Danach Funktionstests erweitern und erst bei Abschluss `docs/test-matrix.*`, `tests/Test-JobAgentSupertest.ps1`, `Roadmap.md`, Todo und Archiv konsistent aktualisieren.

## Geaenderte Dateien

- `src/JobAgent.CompanyInventory.psm1`
- `schemas/jobagent.schema.json`
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
- `handoff.latest.md`
- `handoff.latest.json`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Risiken

- Die neue Clusterlogik ist aktuell ein fachlicher Baustein, noch kein produktiver Import-Gate.
- Reine Namensgleichheit wird bewusst fail-closed behandelt; dadurch entstehen mehr Review-Faelle, aber weniger falsche Merges.
- Schemafelder sind optional, damit bestehende Store-Fixtures nicht migriert werden muessen.
