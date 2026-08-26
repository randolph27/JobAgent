# Handoff latest

Stand: 2026-08-26T19:03:00.000+02:00

## Zustand fuer neuen Chat/Agent

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `3a45474ca072`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, danach Stage/Commit/Push ausfuehren.
- Aktive Roadmap: `JA-025` und `JA-027`
- Roadmap-Rotation: nicht ausfuehren. `JA-025` ist weiter offen, weil `target_inventory_candidates_total=503` unter Zielwert `1000` liegt. `JA-027` ist nicht abgeschlossen und haengt fachlich an `JA-025`.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er ohne explizite Anforderung als erledigt.
- Devserver: HTML-Viewport-Audit erreichte `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html` mit HTTP `200`.

## Abgeschlossener Arbeitsschritt

Fuer `JA-025` wurde die produktive regionale Snapshot-Lane bereinigt und um belegte Arbeitgeber-Snapshots aus offiziellen kommunalen Seiten erweitert. Ziel war, die Kandidatenbasis mit echten Arbeitgeberhinweisen zu vergroessern und gleichzeitig alte lokale Testfirmen aus produktiven Hints zu entfernen.

Konkretes Ergebnis:

- Neuer produktiver Snapshot `tests/fixtures/jobagent/regional-discovery/stadt-muenchen-boersennotierte-unternehmen-snapshot.json` mit 26 Arbeitgeberhinweisen aus der oeffentlichen Muenchner Wirtschaftsfoerderungsseite zu DAX/MDAX/SDAX/TecDAX-Unternehmen am Standort Muenchen und Region.
- Neuer produktiver Snapshot `tests/fixtures/jobagent/regional-discovery/landkreis-freising-wirtschaft-snapshot.json` mit 5 namentlich genannten grossen Arbeitgebern von der oeffentlichen Wirtschaftsseite des Landkreises Freising.
- `data/jobagent/company-discovery.snapshot.json` nutzt fuer `source-registry:stadt_muenchen_boersennotierte_unternehmen` und `source-registry:landkreis_freising_wirtschaft` jetzt produktive Snapshots statt des lokalen Parser-Testfixtures.
- `tools/Import-JobAgentCompanyDiscovery.ps1` ersetzt beim Snapshot-Refresh bestehende Hints der erneut verarbeiteten Quellen. Dadurch bleiben alte Test- oder Stale-Hints derselben Quellen nicht im produktiven Hint-Store.
- `tests/Test-JobAgentRegionalDiscovery.ps1` prueft die beiden produktiven Snapshots, Zielgebietsbezug und Ausschluss der lokalen Testfirmennamen.
- `docs/company-discovery-operations.md` dokumentiert die produktiven Quellen und die Replace-Semantik der Snapshot-Lane.
- `data/jobagent/company-discovery.hints.json`, `data/jobagent/company-candidate-verification.queue.json`, `html/jobagent/company-coverage.html` und `html/jobagent/ja-022-viewport-audit.html` wurden aus Snapshot-/Coverage-/Audit-Lane aktualisiert.
- Es gab keine produktiven Store- oder JobSource-Writes.

Aktuelle Kennzahlen:

- `companies_total=38`
- `job_sources_total=39`
- `discovery_hints_total=467`
- `stadt_muenchen_boersennotierte_unternehmen_hints=26`
- `landkreis_freising_wirtschaft_hints=5`
- `fake_hints_after_refresh=0`
- `candidate_verification_queue.clusters_total=465`
- `target_inventory_candidates_total=503`
- `target_inventory_gap_to_1000=497`
- `target_inventory_gate_status=failed`
- `source_gate.status=passed`
- `source_gate.expected_sources_total=19`
- `source_gate.processed_sources_total=19`
- `source_gate.missing_source_ids=[]`
- `productive_store_write=false`
- `official_verification_required=true`

## Verifikation

- `pwsh -NoProfile -Command <JSON validation for manifest and new snapshots>` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -Command <fake hint guard>` -> Exit `0`, `fake_hints=0`, `hints_total=467`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Offene Aufgaben

1. `JA-025` fortsetzen: weitere erlaubte, snapshot-faehige Arbeitgeberquellen fuer Muenchen, 20-km-Umkreis und Freising suchen und in Source Registry, lokalem Snapshot, Manifest, Hint-Store, Coverage und Funktionstests nachweisen.
2. Priorisierte naechste Quellen: groessere offene Register-Dumps, weitere kommunale Standortseiten, regionale Branchen-/Clusterseiten, erlaubte Firmenverzeichnisse mit klaren Nutzungsregeln.
3. Ziel fuer `JA-025`: Kandidatenbasis Richtung mindestens `1000` Zielgebietskandidaten bringen. Aktuelle Luecke: `497`.
4. Keine produktive Firma aus Sekundaerquellen importieren. Produktiver Store und JobSources duerfen erst nach offizieller Firmenwebsite-/Karriere-/ATS-Verifikation beschrieben werden.
5. `JA-027` erst weiterziehen, wenn `JA-025` eine ausreichend breite Kandidatenbasis liefert oder eine priorisierte Teilwelle fachlich bewusst zur offiziellen Verifikation ausgewaehlt wird.
6. Bei jedem weiteren Quellenimport: erst Source Registry/Manifest/Snapshot, dann passender Funktionstest, danach Snapshot-Lane, Dedupe, Coverage und HTML-Audit. Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.

## Quellen fuer diesen Snapshot-Ausbau

- `https://stadt.muenchen.de/lhm-ms-wirtschaftsfoerderung/standort-muenchen/boersennotierte_unternehmen.html`
- `https://www.kreis-freising.de/buergerservice/abteilungen-und-sachgebiete/wirtschaftliche-und-digitale-entwicklung.html`
