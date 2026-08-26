# Handoff latest

Stand: 2026-08-26T19:13:13.426+02:00

## Startkontext fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch vor Commit: `master`
- HEAD vor Commit: `1715ab70152a`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` ist weiter offen, weil `target_inventory_candidates_total=523` unter Zielwert `1000` liegt. `JA-027` ist nicht abgeschlossen und haengt fachlich an `JA-025`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er ohne explizite Anforderung als erledigt.
- Devserver: HTML-Viewport-Audit erreichte `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html` mit HTTP `200`.
- SonarQube: laut Projektvorgabe bereits auf `:9000`; in diesem Arbeitsschritt nicht neu geprueft, weil keine Sonar-Analyse beauftragt war.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die produktive regionale Snapshot-Lane um eine weitere erlaubte oeffentliche Arbeitgeberquelle erweitert: die Klimapakt-3-Unternehmensliste der Landeshauptstadt Muenchen / munich business.

Ziel war, die Kandidatenbasis fuer Muenchen, 20-km-Umkreis und Freising mit belegten Arbeitgeberhinweisen zu vergroessern, ohne produktive Firmen oder JobSources anzulegen. Alle neuen Eintraege bleiben unverifizierte Kandidaten und benoetigen spaeter offizielle Firmenwebsite-/Karriere-/ATS-Verifikation.

Konkretes Ergebnis:

- Neue Source Registry: `source-registry:munich_business_klimapakt3_companies` in `data/jobagent/company-discovery.sources.json`.
- Neuer produktiver Snapshot: `tests/fixtures/jobagent/regional-discovery/munich-business-klimapakt3-snapshot.json`.
- Neuer Snapshot-Manifest-Eintrag in `data/jobagent/company-discovery.snapshot.json`.
- Neuer Funktionstestfall `production_klimapakt3_snapshot` in `tests/Test-JobAgentRegionalDiscovery.ps1`.
- `docs/company-discovery-operations.md` dokumentiert die neue Klimapakt-3-Quelle.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json`, `html/jobagent/company-coverage.html` und `html/jobagent/ja-022-viewport-audit.html` wurden aus Snapshot-/Coverage-/Audit-Lane aktualisiert.
- `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`, `handoff.latest.md` und `handoff.latest.json` wurden durch STP/Handoff aktualisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `job_sources_total=39`
- `discovery_hints_total=487`
- `munich_business_klimapakt3_companies_hints=20`
- `candidate_verification_queue.clusters_total=485`
- `target_inventory_candidates_total=523`
- `target_inventory_gap_to_1000=477`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=20`
- `source_gate.processed_sources_total=20`
- `source_gate.missing_source_ids=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `pwsh -NoProfile -Command <JSON validation for registry, manifest and Klimapakt snapshot>` -> Exit `0`
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
2. Priorisierte naechste Quellen: groessere offene Register-Dumps, weitere kommunale Standortseiten, regionale Branchen-/Clusterseiten, erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln.
3. Ziel fuer `JA-025`: Kandidatenbasis Richtung mindestens `1000` Zielgebietskandidaten bringen. Aktuelle Luecke: `477`.
4. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
5. `JA-027` erst weiterziehen, wenn `JA-025` eine ausreichend breite Kandidatenbasis liefert oder eine priorisierte Teilwelle fachlich bewusst zur offiziellen Verifikation ausgewaehlt wird.
6. Bei jedem weiteren Quellenimport: erst Source Registry/Manifest/Snapshot, dann passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit. Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.

## Quellen fuer diesen Snapshot-Ausbau

- `https://www.munich-business.eu/standort-muenchen/klimaschutz-ressourcen/klimapakt3.html`
