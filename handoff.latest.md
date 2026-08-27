# Handoff latest

Stand: 2026-08-27T06:40:38.240+02:00

## Abgeschlossener Arbeitsschritt

JA-025 wurde um zwei erlaubte regionale GitHub-Snapshot-Quellen erweitert:

- `source-registry:remote_jobs_germany_github` mit `8` unverifizierten Arbeitgeberhinweisen.
- `source-registry:awesome_geospatial_companies_github` mit `14` unverifizierten Arbeitgeberhinweisen.

Es gab keine produktiven Store- oder JobSource-Writes. Alle neuen Eintraege bleiben Discovery-Hints mit Pflicht zur offiziellen Firmenwebsite-/Karriere-/ATS-Verifikation.

## Konkrete Aenderungen

- `data/jobagent/company-discovery.sources.json`: zwei neue Source-Registry-Eintraege mit `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`, `retention_policy`, `import_mode=FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=MEDIUM`.
- `data/jobagent/company-discovery.snapshot.json`: Manifest um beide regionale Snapshot-Inputs erweitert.
- `tests/fixtures/jobagent/regional-discovery/remote-jobs-germany-github-snapshot.json`: lokaler Snapshot aus der MIT-lizenzierten GitHub-Liste `danielbayerlein/remote-jobs-germany`; beruecksichtigt nur Eintraege mit Muenchen-/Unterfoehring-/Ismaning-Bezug.
- `tests/fixtures/jobagent/regional-discovery/awesome-geospatial-companies-github-snapshot.json`: lokaler Snapshot aus der MIT-lizenzierten GitHub-Liste `chrieke/awesome-geospatial-companies`; beruecksichtigt nur Eintraege mit Muenchen- oder 20-km-Bezug.
- `tests/Test-JobAgentRegionalDiscovery.ps1`: Funktionstests `production_remote_jobs_germany_snapshot` und `production_awesome_geospatial_companies_snapshot` hinzugefuegt; prueft Quelle, Hint-Anzahl, Zuordnung, unverifizierten Status, Zielgebiet und Verbot offizieller Linkpersistenz.
- `docs/company-discovery-operations.md`: Snapshot-Lane-Dokumentation um beide Quellen ergaenzt.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json`, `html/jobagent/company-coverage.html`, `html/jobagent/ja-022-viewport-audit.html`: aus Snapshot-/Coverage-/HTML-Audit-Lane neu generiert.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`, `handoff.latest.json`, `handoff.latest.md`: STP-/Handoff-Artefakte synchronisiert.

## Aktuelle Kennzahlen

- `companies_total=38`
- `merged_hints_total=628`
- `candidate_verification_queue.clusters_total=626`
- `candidate_verification_queue.candidates_total=628`
- `target_inventory_candidates_total=664`
- `target_inventory_gap_to_1000=336`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=24`
- `source_gate.processed_sources_total=24`
- `productive_store_write=false`
- `official_verification_required=true`

## Roadmap-Status

- `JA-025` bleibt offen. Der Zielwert `1000` Zielgebietskandidaten ist mit `664` nicht erreicht; es fehlen `336`.
- `JA-027` bleibt offen und fachlich nachgelagert. Offizielle Firmenwebsite-/Karriere-/ATS-Verifikation darf erst nach ausreichend breiter Kandidatenbasis oder explizit priorisierter Teilwelle weitergezogen werden.
- Keine Roadmap-Rotation ausgefuehrt, weil kein aktiver Roadmap-Punkt komplett erledigt ist.
- Supertest wurde nicht neu ausgefuehrt; gemaess aktueller Nutzeranweisung gilt der nicht angefragte Supertest fuer diesen Abschluss als erledigt.

## Verifikation

- `pwsh -NoProfile -Command <JSON validation for registry, manifest and new snapshots>` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechster Anker

1. `JA-025` fortsetzen: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und fail-closed in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
2. Ziel fuer `JA-025`: Kandidatenbasis von `664` auf mindestens `1000` Zielgebietskandidaten bringen; aktuelle Luecke `336`.
3. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
4. Jede neue Quelle braucht vollstaendige Registry-Felder: `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`, `retention_policy`, `evidence_level`, `import_mode`, `review_required`, `legal_risk`.
5. Fuer jede weitere Quelle: erst Source Registry/Manifest/Snapshot, dann passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit.
6. `JA-027` erst bearbeiten, wenn `JA-025` genug Kandidaten liefert oder der User eine konkrete Teilwelle zur offiziellen Verifikation priorisiert.

## Quellen dieses Arbeitsschritts

- `https://github.com/danielbayerlein/remote-jobs-germany`
- `https://github.com/chrieke/awesome-geospatial-companies`
