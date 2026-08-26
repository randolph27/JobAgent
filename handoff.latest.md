# Handoff latest

Stand: 2026-08-26T12:42:52.906+02:00

## Zustand fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `5f1c3afea283`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` ist nicht abgeschlossen, weil die Kandidatenbasis mit `273` Zielgebietskandidaten weiter unter dem Zielwert `1000` liegt. `JA-027` ist nicht abgeschlossen und haengt fachlich an `JA-025`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er ohne explizite Anforderung als erledigt.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`.
- Devserver: `.\ci.cmd devserver-status` meldete `pid=38292`, `port=8500`, `listening=True`, URL `http://localhost:8500/`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die regionale Snapshot-Lane um die offizielle Quelle `source-registry:stadt_muenchen_unternehmensbeteiligungen` erweitert. Ziel war die Skalierung der unverifizierten Arbeitgeberkandidatenbasis, ohne produktive Firmen oder JobSources zu schreiben.

Konkretes Ergebnis:

- Neue Source Registry Quelle `source-registry:stadt_muenchen_unternehmensbeteiligungen` in `data/jobagent/company-discovery.sources.json`.
- Die Quelle ist als `PUBLIC_INSTITUTION_DIRECTORY`, `SECONDARY_OFFICIAL_DIRECTORY`, `FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=LOW` modelliert.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/stadt-muenchen-unternehmensbeteiligungen-snapshot.json` mit 32 unverifizierten Arbeitgeberhinweisen.
- `data/jobagent/company-discovery.snapshot.json` verarbeitet die neue Quelle in der produktiven Snapshot-Lane.
- `docs/company-discovery-operations.md` dokumentiert die kommunale Beteiligungsquelle als unverifizierte regionale Snapshot-Quelle.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html` wurden aus Snapshot-/Coverage-Lane aktualisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `discovery_hints_total=241`
- `candidate_verification_queue.clusters_total=235`
- `candidate_verification_ready=229`
- `candidate_verification_manual_review=6`
- `target_inventory_candidates_total=273`
- `target_inventory_gap_to_1000=727`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=17`
- `source_gate.processed_sources_total=17`
- `source_gate.missing_source_ids=[]`
- `source_gate.violations=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `Get-Content/ConvertFrom-Json` fuer Source Registry, Manifest und neuen Snapshot -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`, Port `8500` listening
- `.\ci.cmd stp` -> Exit `0`

## Offene Aufgaben

1. `JA-025` fortsetzen: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
2. Bevorzugte Quellen fuer den naechsten Schritt: groessere offene Register-Dumps, kommunale Standortseiten, regionale Branchen-/Clusterseiten und erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln.
3. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
4. `JA-027` erst weiterziehen, wenn `JA-025` eine ausreichend breite Kandidatenbasis liefert oder eine priorisierte Teilwelle fachlich bewusst zur offiziellen Verifikation ausgewaehlt wird.

## Quellen fuer den letzten Snapshot-Ausbau

- `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
