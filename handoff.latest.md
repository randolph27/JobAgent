# Handoff latest

Stand: 2026-08-26T12:15:56.580+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `72e2f7f0334f`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` bleibt offen, weil die Kandidatenbasis mit `157` Zielgebietskandidaten weiter deutlich unter dem Zielwert `1000` liegt. `JA-027` bleibt offen und haengt fachlich an `JA-025`.
- Supertest: in diesem Schritt nicht erneut ausgefuehrt; gemaess Nutzeranweisung gilt er ohne explizite Anforderung als erledigt.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`.
- Devserver: `./ci.cmd devserver-status` meldete `pid=38292`, `port=8500`, `listening=True`, URL `http://localhost:8500/`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die regionale Snapshot-Lane um zwei weitere erlaubte munich-business-Community-Quellen erweitert. Ziel war die Skalierung der unverifizierten Arbeitgeberkandidatenbasis, ohne produktive Firmen oder JobSources zu schreiben.

Konkretes Ergebnis:

- Neue Source Registry Quelle `source-registry:munich_business_us_companies` in `data/jobagent/company-discovery.sources.json`.
- Neue Source Registry Quelle `source-registry:munich_business_japanese_companies` in `data/jobagent/company-discovery.sources.json`.
- Beide Quellen sind als `REGIONAL_DIRECTORY`, `SECONDARY_OFFICIAL_DIRECTORY`, `FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=LOW` modelliert.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-us-snapshot.json` mit 14 unverifizierten Arbeitgeberhinweisen.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-japanese-snapshot.json` mit 13 unverifizierten Arbeitgeberhinweisen.
- `data/jobagent/company-discovery.snapshot.json` verarbeitet beide neuen Quellen in der produktiven Snapshot-Lane.
- `docs/company-discovery-operations.md` dokumentiert die erweiterten munich-business-Community-Quellen als unverifizierte regionale Snapshot-Quellen.
- `tests/Test-JobAgentCoverage.ps1` nutzt fuer den Coverage-Report mit realem Hint-Store jetzt `-MaxPriorityItems 250`, damit die vollstaendige Kandidaten-Verifikationsqueue bei aktuell mehr als 100 Clustern geprueft wird.
- Produktive Snapshot-/Coverage-Artefakte wurden aktualisiert.
- `./ci.cmd stp` wurde ausgefuehrt; Todo-State, Checkpoint und Handoff wurden konsolidiert.

Aktuelle Kennzahlen:

- `companies_total=38`
- `discovery_hints_total=125`
- `candidate_verification_queue.clusters_total=119`
- `target_inventory_candidates_total=157`
- `target_inventory_gap_to_1000=843`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=14`
- `source_gate.processed_sources_total=14`
- `source_gate.missing_source_ids=[]`
- `source_gate.violations=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `Get-Content ... | ConvertFrom-Json` fuer Source Registry, Manifest und neue Snapshot-Dateien -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 150` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`, Port `8500` listening
- `.\ci.cmd stp` -> Exit `0`

## Offene Roadmap

- `JA-025` bleibt offen. Naechster Schritt: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
- `JA-027` bleibt offen und haengt fachlich an `JA-025`. Produktive Store-Aufnahme darf erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation erfolgen.

## Naechster sinnvoller Schritt

Weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen. Bevorzugt groessere offene Register-Dumps, kommunale Standortseiten, regionale Branchen-/Clusterseiten und erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln. Keine produktive Firma aus Sekundaerquellen importieren.

