# Handoff latest

Stand: 2026-08-26T11:58:30.000+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `b3983e7e2bf6`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Stage/Commit: `dirty`
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren, beide Punkte sind fachlich offen.
- Supertest: nicht erneut gelaufen; nach Nutzeranweisung gilt er als erledigt, wenn nicht separat angefragt.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`.
- Devserver: `.\ci.cmd devserver-status` meldete `pid=38292`, `port=8500`, `listening=True`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die regionale Snapshot-Lane um zwei weitere erlaubte munich-business-Branchenquellen erweitert. Ziel war die Skalierung der unverifizierten Arbeitgeberkandidatenbasis, ohne produktive Firmen oder JobSources zu schreiben.

Konkretes Ergebnis:

- Neue Source Registry Quelle `source-registry:munich_business_ikt_companies` in `data/jobagent/company-discovery.sources.json`.
- Neue Source Registry Quelle `source-registry:munich_business_life_sciences_companies` in `data/jobagent/company-discovery.sources.json`.
- Beide Quellen sind als `REGIONAL_DIRECTORY`, `SECONDARY_OFFICIAL_DIRECTORY`, `FIXTURE_OR_SNAPSHOT_ONLY`, `review_required=true`, `legal_risk=LOW` modelliert.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-ikt-snapshot.json`.
- Neuer lokaler Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-life-sciences-snapshot.json`.
- Der vorher bereits vorhandene neue Snapshot `tests/fixtures/jobagent/regional-discovery/munich-business-international-snapshot.json` bleibt Teil derselben uncommitted Arbeitsserie.
- `data/jobagent/company-discovery.snapshot.json` verarbeitet die munich-business-Quellen in der produktiven Snapshot-Lane.
- `docs/company-discovery-operations.md` dokumentiert die munich-business-Quellen als unverifizierte regionale Snapshot-Quellen.
- `tests/Test-JobAgentCoverage.ps1` nutzt fuer den wachsenden Hint-Store `-MaxPriorityItems 100`, damit Queue-Metrik und Clusteranzahl bei dieser Datengroesse nicht durch das Testlimit divergieren.
- Produktive Snapshot-/Coverage-Artefakte wurden aktualisiert.

Aktuelle Kennzahlen nach Snapshot- und Coverage-Lauf:

- `companies_total=38`
- `discovery_hints_total=59`
- `candidate_verification_queue.clusters_total=53`
- `candidate_verification_queue.queue.Count=53`
- `target_inventory_candidates_total=91`
- `target_inventory_gap_to_1000=909`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=10`
- `source_gate.processed_sources_total=10`
- `source_gate.missing_source_ids=[]`
- `source_gate.violations=[]`

## Geaenderte Dateien

- `data/jobagent/company-discovery.sources.json`
- `data/jobagent/company-discovery.snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/munich-business-international-snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/munich-business-ikt-snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/munich-business-life-sciences-snapshot.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `docs/company-discovery-operations.md`
- `tests/Test-JobAgentCoverage.ps1`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 100` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`, Port `8500` listening
- `.\ci.cmd stp` -> Exit `0`

## Offene Roadmap

- `JA-025` bleibt offen. Grund: Die Pipeline verarbeitet jetzt 10 importierbare Snapshot-Quellen vollstaendig, aber die Kandidatenbasis liegt mit `91` Zielgebietskandidaten weiter deutlich unter dem Zielwert `1000`.
- `JA-027` bleibt offen und haengt fachlich an `JA-025`. Produktive Store-Aufnahme darf erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation erfolgen.

## Naechster sinnvoller Schritt

Weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen. Bevorzugt oeffentliche regionale Wirtschaftsseiten, kommunale Standortseiten, erlaubte Branchen-/Clusterseiten und erlaubte Register-Dumps. Jede neue Quelle muss in Source Registry, lokalem Snapshot, Snapshot-Manifest, Hint-Store, Coverage und Funktionstests nachgewiesen werden. Keine produktive Firma aus Sekundaerquellen importieren.
