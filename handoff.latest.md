# Handoff latest

Stand: 2026-08-26T19:29:37.579+02:00

## Startkontext fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD: `64f00db97f77`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` ist weiter offen, weil `target_inventory_candidates_total=553` unter Zielwert `1000` liegt. `JA-027` haengt fachlich weiter an `JA-025`.
- Supertest: nicht ausgefuehrt; gemaess Nutzeranweisung erst nach Roadmap-Abschluss.
- Devserver: HTML-Viewport-Audit erreichte `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html` mit HTTP `200`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die produktive regionale Snapshot-Lane um die Munich-Startup-Plattform als erlaubte regionale Arbeitgeber-Hinweisquelle erweitert.

Konkretes Ergebnis:

- Neue Source Registry: `source-registry:munich_startup_platform_ecosystem` in `data/jobagent/company-discovery.sources.json`.
- Neuer produktiver Snapshot: `tests/fixtures/jobagent/regional-discovery/munich-startup-platform-ecosystem-snapshot.json`.
- Neuer Snapshot-Manifest-Eintrag in `data/jobagent/company-discovery.snapshot.json`.
- Neuer Funktionstestfall `production_munich_startup_snapshot` in `tests/Test-JobAgentRegionalDiscovery.ps1`.
- `docs/company-discovery-operations.md` dokumentiert die neue Munich-Startup-Quelle.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json`, `html/jobagent/company-coverage.html` und `html/jobagent/ja-022-viewport-audit.html` wurden aus Snapshot-/Coverage-/Audit-Lane aktualisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `job_sources_total=39`
- `new_hints_total=516`
- `merged_hints_total=517`
- `candidate_verification_queue.clusters_total=515`
- `candidate_verification_queue.candidates_total=517`
- `target_inventory_candidates_total=553`
- `target_inventory_gap_to_1000=447`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=21`
- `source_gate.processed_sources_total=21`
- `source_gate.missing_source_ids=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `pwsh -NoProfile -Command <JSON validation for registry, manifest and Munich Startup snapshot>` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Offene Aufgaben

1. `JA-025` fortsetzen: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
2. Ziel fuer `JA-025`: Kandidatenbasis Richtung mindestens `1000` Zielgebietskandidaten bringen. Aktuelle Luecke: `447`.
3. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
4. `JA-027` erst weiterziehen, wenn `JA-025` eine ausreichend breite Kandidatenbasis liefert oder eine priorisierte Teilwelle fachlich bewusst zur offiziellen Verifikation ausgewaehlt wird.
5. Bei jedem weiteren Quellenimport: erst Source Registry/Manifest/Snapshot, dann passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit. Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.

## Quellen fuer diesen Snapshot-Ausbau

- `https://www.munich-startup.de/en/startups-and-ecosystem`
- `https://www.munich-startup.de/en/about`
