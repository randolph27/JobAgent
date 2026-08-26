# Handoff latest

Stand: 2026-08-26T07:25:16.523+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-025` Arbeitgeberkandidatenbasis aus erlaubten Quellen weiter skalieren.
- Branch: `master`
- HEAD vor Commit: `0184c8c85bea`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, nur erwartete Projektdateien.
- Route: `True`
- Roadmap-Rotation: nicht ausgefuehrt, weil `JA-025` und `JA-027` fachlich offen bleiben.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die Snapshot-Lane um ein Source-Gate erweitert. Ziel war nicht, neue produktive Firmen aufzunehmen, sondern die Verarbeitung aller erlaubten Snapshot-Quellen sichtbar und pruefbar zu machen.

Konkretes Ergebnis:

- `tools/Import-JobAgentCompanyDiscovery.ps1` erzeugt im Snapshot-Digest jetzt `source_gate`.
- `source_gate` vergleicht alle importierbaren Snapshot-Quellen aus `data/jobagent/company-discovery.sources.json` mit den eindeutig verarbeiteten Quellen.
- Importierbar fuer die Snapshot-Lane sind Quellen mit `import_mode=BULK_SNAPSHOT` oder `FIXTURE_OR_SNAPSHOT_ONLY` und Source-Klassen `OPEN_REGISTER_DUMP`, `REGIONAL_DIRECTORY`, `PUBLIC_INSTITUTION_DIRECTORY`, `JOB_BOARD_DISCOVERY`.
- Ein vollstaendiger produktiver Manifest-Lauf meldet `source_gate.status=passed`, `expected_sources_total=7`, `processed_sources_total=7`, keine fehlenden Quellen und keine Violations.
- Ein partielles Testmanifest bleibt als Funktionstest erlaubt, meldet aber fehlende importierbare Quellen fail-closed mit `status=failed` und `SNAPSHOT_IMPORTABLE_SOURCES_MISSING`.
- `docs/company-discovery-operations.md` dokumentiert das neue Gate.
- `tests/Test-JobAgentCompanyInventory.ps1` prueft das Gate fuer ein partielles Multi-Input-/Glob-Manifest.
- Produktive Snapshot-/Coverage-Artefakte wurden aktualisiert.

Aktuelle Kennzahlen nach dem letzten Coverage-Lauf:

- `companies_total=38`
- `target_inventory_candidates_total=58`
- `target_inventory_gap_to_1000=942`
- `target_inventory_gate_status=failed`
- `discovery_hints_total=26`
- `candidate_verification_queue.clusters_total=20`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=7`
- `source_gate.processed_sources_total=7`

## Geaenderte Dateien

- `tools/Import-JobAgentCompanyDiscovery.ps1`
- `tests/Test-JobAgentCompanyInventory.ps1`
- `docs/company-discovery-operations.md`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Supertest wurde nicht erneut ausgefuehrt; nach aktueller Nutzeranweisung gilt er als erledigt, wenn er nicht separat angefragt wurde.

## Offene Roadmap

- `JA-025` bleibt offen. Grund: Die Pipeline verarbeitet jetzt alle erlaubten Snapshot-Quellen nachvollziehbar, aber die Kandidatenbasis ist mit `58` Zielgebietskandidaten noch weit unter dem Ziel von `1000`.
- `JA-027` bleibt offen und haengt fachlich weiter an `JA-025`. Produktive Firmen duerfen erst nach offizieller Website-/Karriere-/ATS-Verifikation aufgenommen werden.

## Naechster sinnvoller Schritt

1. `data/jobagent/company-discovery.sources.json` auf weitere erlaubte, snapshot-faehige Arbeitgeberquellen pruefen, ohne Terms, Robots, Login, Captcha oder Paywalls zu umgehen.
2. Zusaetzliche lokale Snapshots/Fixtures fuer erlaubte Register-, Regional-, StepStone- und BA-Suchmatrizen anlegen; Jobboersen bleiben nur Arbeitgeber-Hinweise.
3. `data/jobagent/company-discovery.snapshot.json` um diese Inputs erweitern.
4. `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` ausfuehren und auf `source_gate.status=passed` pruefen.
5. Danach fokussiert testen: Register, JobBoard, Regional, DedupeScale, Coverage.
6. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`.
7. Erst wenn `JA-025` fachlich erfuellt ist, Roadmap-Rotation pruefen und dann `JA-027` fortsetzen.

## Naechster Anker

Aktive Punkte: JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen #comment: Alle erlaubten Quellen sollen Arbeitgebernamen liefern, nicht Stellenanzeigen; produktiv hinzugefuegt wird erst nach offizieller Karriere-/Jobs-Webseitenverifikation.
