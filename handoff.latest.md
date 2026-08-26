# Handoff latest

Stand: 2026-08-26T18:45:42.821+02:00

## Zustand fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `6cd2c5a4dff9`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, danach Stage/Commit/Push ausfuehren.
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` ist weiter offen, weil die Kandidatenbasis mit `479` Zielgebietskandidaten unter dem Zielwert `1000` liegt. `JA-027` ist nicht abgeschlossen und haengt fachlich an `JA-025`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er ohne explizite Anforderung als erledigt.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`.
- Devserver: `.\ci.cmd devserver-status` meldete `pid=38292`, `port=8500`, `listening=True`, URL `http://localhost:8500/`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde eine neue lokale Snapshot-Quelle fuer Muenchner Tech-Arbeitgeber aus der oeffentlichen, MIT-lizenzierten GitHub-Liste `rmellojunior/tech_companies_munich` integriert. Ziel war, die unverifizierte Arbeitgeberkandidatenbasis zu vergroessern, ohne produktive Firmen oder JobSources zu schreiben.

Konkretes Ergebnis:

- Neue Source Registry Quelle `source-registry:tech_companies_munich_github` in `data/jobagent/company-discovery.sources.json`.
- Die Quelle ist als `REGIONAL_DIRECTORY`, `DISCOVERY_HINT`, `FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=MEDIUM` modelliert.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/tech-companies-munich-github-snapshot.json` mit 86 extrahierten Muenchner Tech-Arbeitgeberhinweisen.
- `data/jobagent/company-discovery.snapshot.json` verarbeitet die neue Quelle in der produktiven Snapshot-Lane.
- `tests/Test-JobAgentRegionalDiscovery.ps1` prueft die neue Community-Tech-Quelle, Mindestanzahl, Quellzuordnung, Muenchen-Zielgebiet und Nicht-Persistenz von Website-/Karriere-Hint-Feldern.
- `docs/company-discovery-operations.md` dokumentiert die neue Quelle und ihre Fail-Closed-Grenzen.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html` wurden aus Snapshot-/Coverage-Lane aktualisiert.
- `handoff.latest.md`, `handoff.latest.json`, `todo.events.jsonl`, `todo.history.digest.json` und `todo.master.index.json` wurden per STP/Handoff aktualisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `job_sources_total=39`
- `discovery_hints_total=447`
- `tech_companies_munich_github_hints=84`
- `candidate_verification_queue.clusters_total=441`
- `candidate_verification_ready=435`
- `target_inventory_candidates_total=479`
- `target_inventory_gap_to_1000=521`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=19`
- `source_gate.processed_sources_total=19`
- `source_gate.missing_source_ids=[]`
- `source_gate.violations=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `Get-Content/ConvertFrom-Json` fuer Source Registry, Manifest und neuen Snapshot -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`, Port `8500` listening
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> nicht neu ausgefuehrt; gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet.

## Offene Aufgaben

1. `JA-025` fortsetzen: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
2. Priorisierte naechste Quellen: groessere offene Register-Dumps, weitere kommunale Standortseiten, regionale Branchen-/Clusterseiten und erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln.
3. Ziel fuer `JA-025`: Kandidatenbasis Richtung mindestens `1000` Zielgebietskandidaten bringen. Aktuelle Luecke: `521`.
4. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
5. `JA-027` erst weiterziehen, wenn `JA-025` eine ausreichend breite Kandidatenbasis liefert oder eine priorisierte Teilwelle fachlich bewusst zur offiziellen Verifikation ausgewaehlt wird.
6. Bei jedem weiteren Quellenimport: erst Source Registry/Manifest/Snapshot, dann `Test-JobAgentRegionalDiscovery.ps1` oder passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit. Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.

## Quellen fuer diesen Snapshot-Ausbau

- `https://github.com/rmellojunior/tech_companies_munich`
- `https://raw.githubusercontent.com/rmellojunior/tech_companies_munich/master/README.md`
- `https://raw.githubusercontent.com/rmellojunior/tech_companies_munich/master/LICENSE`
