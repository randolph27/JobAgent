# Handoff latest

Stand: 2026-08-26T12:05:00.000+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- HEAD: `a2401820fd5f`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren, beide Punkte sind fachlich offen.
- Supertest: nicht erneut gelaufen; gemaess Nutzeranweisung erst nach abgeschlossenem Roadmap-Punkt.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`.
- Devserver: `.\ci.cmd devserver-status` meldete `pid=38292`, `port=8500`, `listening=True`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die regionale Snapshot-Lane um zwei weitere erlaubte munich-business-Branchenquellen erweitert. Ziel war die Skalierung der unverifizierten Arbeitgeberkandidatenbasis, ohne produktive Firmen oder JobSources zu schreiben.

Konkretes Ergebnis:

- Neue Source Registry Quelle `source-registry:munich_business_automotive_mobility_companies` in `data/jobagent/company-discovery.sources.json`.
- Neue Source Registry Quelle `source-registry:munich_business_finance_companies` in `data/jobagent/company-discovery.sources.json`.
- Beide Quellen sind als `REGIONAL_DIRECTORY`, `SECONDARY_OFFICIAL_DIRECTORY`, `FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=LOW` modelliert.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-automotive-mobility-snapshot.json` mit 20 unverifizierten Arbeitgeberhinweisen.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-finance-snapshot.json` mit 19 unverifizierten Arbeitgeberhinweisen.
- `data/jobagent/company-discovery.snapshot.json` verarbeitet beide neuen Quellen in der produktiven Snapshot-Lane.
- `docs/company-discovery-operations.md` dokumentiert die erweiterten munich-business-Quellen als unverifizierte regionale Snapshot-Quellen.
- Produktive Snapshot-/Coverage-Artefakte wurden aktualisiert.

Aktuelle Kennzahlen nach Snapshot- und Coverage-Lauf:

- `companies_total=38`
- `discovery_hints_total=98`
- `candidate_verification_queue.clusters_total=92`
- `target_inventory_candidates_total=130`
- `target_inventory_gap_to_1000=870`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=12`
- `source_gate.processed_sources_total=12`
- `source_gate.missing_source_ids=[]`
- `source_gate.violations=[]`

## Geaenderte Dateien

- `data/jobagent/company-discovery.sources.json`
- `data/jobagent/company-discovery.snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/munich-business-automotive-mobility-snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/munich-business-finance-snapshot.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `docs/company-discovery-operations.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `Get-Content ... | ConvertFrom-Json` fuer Source Registry, Manifest und neue Snapshot-Dateien -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 150` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`, Port `8500` listening
- `.\ci.cmd stp` -> Exit `0`

## Offene Roadmap

- `JA-025` bleibt offen. Grund: Die Pipeline verarbeitet jetzt 12 importierbare Snapshot-Quellen vollstaendig, aber die Kandidatenbasis liegt mit `130` Zielgebietskandidaten weiter deutlich unter dem Zielwert `1000`.
- `JA-027` bleibt offen und haengt fachlich an `JA-025`. Produktive Store-Aufnahme darf erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation erfolgen.

## Naechster sinnvoller Schritt

Weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen. Bevorzugt groessere offene Register-Dumps, kommunale Standortseiten, regionale Branchen-/Clusterseiten und erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln. Jede neue Quelle muss in Source Registry, lokalem Snapshot, Snapshot-Manifest, Hint-Store, Coverage und Funktionstests nachgewiesen werden. Keine produktive Firma aus Sekundaerquellen importieren.
