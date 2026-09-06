# Handoff latest

Stand: 2026-09-06T22:55:00+02:00. STP wurde ausgefuehrt. Fuer den naechsten Chat/Agent zuerst `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md` lesen. Projektwurzel ist `D:\_Scripte\JobAgent`.

## Aktiver Status

- Active: `TD-0041` / `JA-027`
- Status: `in-progress`
- Ziel: Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD: `6ad4c25b5d3e`
- Upstream: `origin/master`
- Worktree: `dirty`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: vom Nutzer fuer diesen Stand freigestellt; gilt fuer diesen Slice als erledigt/nicht erforderlich, aber nicht als ausgefuehrter Supertestlauf.

## Abgeschlossener Slice

JA-027.2 wurde mit einem schreibenden Snapshot-Refresh weitergefuehrt. Die Inventur-Reconciliation wurde korrigiert: Queue-Abdeckung zaehlt jetzt `candidate_id` und alle `candidate_ids` eines Identitaetsclusters. Dadurch werden sekundaere Cluster-Hints nicht mehr faelschlich als fehlende Queueeintraege gewertet.

Neue regionale Snapshot-Quellen:

- `source-registry:izb_startups`: 27 Hints
- `source-registry:landkreis_muenchen_gruenderzentren`: 4 Hints
- `source-registry:stadt_muenchen_gruenderzentren`: 12 Hints

Aktueller Datenstand nach Snapshot-Lane:

- 35 Registry-Quellen
- 29 Snapshot-Manifesteintraege
- 1.833 Discovery-Hints
- 1.831 Queue-Cluster
- 2.312 dauerhafte Discovery-Funde
- 1.401 dauerhafte URL-Funde
- 479 produktive Firmen unveraendert
- 439 JobSources unveraendert
- `hints_without_queue = 0`
- `queue_without_hint = 0`

Queue-Zusammenfassung:

- `ALREADY_VERIFIED_IN_STORE = 666`
- `DISCOVER_OFFICIAL_WEBSITE = 1164`
- `MANUAL_DECISION = 1`
- Status: `VERIFIED = 667`, `MANUAL_REVIEW_REQUIRED = 1163`, `RETRY_EXHAUSTED = 1`, `PENDING = 0`

## Geaenderte Hauptdateien

- `tools/Measure-JobAgentDiscoverySourceInventory.ps1`
- `tests/Test-JobAgentDiscoverySourceInventory.ps1`
- `tests/Test-JobAgentRegionalDiscovery.ps1`
- `data/jobagent/company-discovery.sources.json`
- `data/jobagent/company-discovery.snapshot.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.regional-hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `tests/fixtures/jobagent/regional-discovery/izb-startups-snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/landkreis-muenchen-gruenderzentren-snapshot.json`
- `tests/fixtures/jobagent/regional-discovery/stadt-muenchen-gruenderzentren-snapshot.json`
- `Roadmap.md`, `todo.state.json`, `todo.current.md`, `todo.checkpoint.json`, `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`

## Evidence

- `logs/jobagent/company-discovery-snapshot-digest-20260906-203726.json`
- `logs/jobagent/JA-027-source-inventory.json`
- `logs/jobagent/JA-027-source-research.json`
- `logs/jobagent/JA-027-candidate-reconciliation.json`
- `html/jobagent/company-coverage.html`

## Verifikation

Gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1
cmd /c .\ci.cmd self-check
git -c core.pager=cat -c color.ui=false --no-pager diff --check
cmd /c .\ci.cmd stp
```

Nicht erfolgreich:

```powershell
curl.exe -s --max-time 5 http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

Grund: SonarQube antwortet lokal nicht auf `:9000`; `sonar-start` scheitert, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt. Wegen Nutzerregel wurde Sonar nicht anders gestartet.

## Naechste Aufgabe

Naechster Hotspot bleibt `JA-027.2`, nicht `JA-041`.

1. HWK-Handwerkersuche, BioM-Firmendatenbank, Stadt-Freising-Wirtschaft und IHK-Standortportal nach Source-Contract final entscheiden.
2. Je Quelle entweder Snapshot-/Parser-Lane ergaenzen und importieren oder mit reproduzierbarem Grund parken/blockieren.
3. Danach `tools/Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`, Coverage und Inventur erneut ausfuehren.
4. Erst nach stabiler Quellen-Nachfuehrung `JA-027.3` starten: offizielle Firmen-/Karriereverifikation und 100er Benchmark.

## Grenzen

- Neue Hints sind keine offiziellen Karrierequellen und keine produktiven Firmen.
- Jobboersen, Register, OSM, Community- und Regionalquellen liefern nur Hinweise.
- Keine Bewerbungen, Nachrichten, Login-/Captcha-/Paywall-Umgehung oder kostenpflichtigen Zugaenge.
- Devserver und Sonar nur ueber `.\ci.cmd`, Server im Hintergrund.
