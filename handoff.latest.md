# Handoff latest

Stand: 2026-08-26T19:44:52.016+02:00

## Startkontext fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Commit: `8c4eacbed4da`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. Kein aktiver Roadmap-Punkt ist komplett erledigt.
- `JA-025` ist weiter offen, weil `target_inventory_candidates_total=642` unter Zielwert `1000` liegt.
- `JA-027` haengt fachlich weiter an `JA-025` und darf erst nach ausreichend breiter Kandidatenbasis oder bewusst priorisierter Teilwelle weitergezogen werden.
- Supertest: nicht erneut ausgefuehrt; gemaess aktueller Nutzeranweisung gilt der nicht angefragte Supertest fuer diesen Abschluss als erledigt.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die produktive regionale Snapshot-Lane um die GitHub-Liste `awesome-machine-learning-startups-munich` als erlaubte regionale AI-/ML-Arbeitgeber-Hinweisquelle erweitert.

Konkretes Ergebnis:

- Neue Source Registry: `source-registry:awesome_ml_startups_munich_github` in `data/jobagent/company-discovery.sources.json`.
- Neuer produktiver Snapshot: `tests/fixtures/jobagent/regional-discovery/awesome-ml-startups-munich-github-snapshot.json` mit `89` unverifizierten Muenchner AI-/ML-Arbeitgeberhinweisen.
- Neuer Snapshot-Manifest-Eintrag in `data/jobagent/company-discovery.snapshot.json`.
- Neuer Funktionstestfall `production_awesome_ml_startups_munich_snapshot` in `tests/Test-JobAgentRegionalDiscovery.ps1`.
- `docs/company-discovery-operations.md` dokumentiert die neue Quelle.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json`, `html/jobagent/company-coverage.html` und `html/jobagent/ja-022-viewport-audit.html` wurden aus Snapshot-/Coverage-/Audit-Lane aktualisiert.
- `.\ci.cmd stp` wurde ausgefuehrt und Todo-/Handoff-Artefakte wurden synchronisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `merged_hints_total=606`
- `candidate_verification_queue.clusters_total=604`
- `candidate_verification_queue.candidates_total=606`
- `target_inventory_candidates_total=642`
- `target_inventory_gap_to_1000=358`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=22`
- `source_gate.processed_sources_total=22`
- `source_gate.missing_source_ids=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `pwsh -NoProfile -Command <JSON validation for registry, manifest and Awesome-ML snapshot>` -> Exit `0`
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
2. Ziel fuer `JA-025`: Kandidatenbasis auf mindestens `1000` Zielgebietskandidaten bringen. Aktuelle Luecke: `358`.
3. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
4. Jede neue Quelle fail-closed bewerten: erlaubte Nutzung, verbotene Nutzung, Rate-Limit-Policy, Robots-/Terms-Notiz, Retention, Evidenzklasse, Importmodus und Reviewpflicht muessen in `data/jobagent/company-discovery.sources.json` stehen.
5. Fuer jeden Quellenimport: erst Source Registry/Manifest/Snapshot, dann passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit.
6. `JA-027` erst bearbeiten, wenn `JA-025` genug Kandidaten liefert oder eine explizit priorisierte Teilwelle offiziell verifiziert werden soll.

## Quellen fuer diesen Snapshot-Ausbau

- `https://github.com/alxschwrz/awesome-machine-learning-startups-munich`
