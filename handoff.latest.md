# Handoff latest

Stand: 2026-08-23T10:52:00.000+02:00

## Zustand

- Active: ``
- Status: `done`
- Ziel: JA-026 abgeschlossen und rotiert: regionale Branchen-, Kommunal- und Arbeitgeberlisten werden als unverifizierte Discovery-Hints importiert, in Coverage beruecksichtigt und im Supertest gefuehrt.
- Branch: `master`
- HEAD: `e9f8cd6db7f0`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Abgeschlossener Punkt

JA-026 ist fachlich abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. Die neue Lane verarbeitet regionale Snapshot-Quellen nur als unverifizierte Kandidatenhinweise; der bestehende offizielle Regionalfeed bleibt getrennt.

## Naechster Punkt

JA-027 ist der naechste aktive Punkt. Fokus: skalierbarer Kandidaten-Merge fuer Register-, Jobboersen- und Regional-Hints mit stabilen Clustern, Konfliktflags, Standortbasis und Review-Queue.

## Wichtige Artefakte

- `src/JobAgent.RegionalDiscovery.psm1`: Source-Guards, Parser, Zielgebietslogik, Hint-Erzeugung.
- `tools/Import-JobAgentRegionalDirectories.ps1`: CLI-Import, Ausgabe `data/jobagent/company-discovery.regional-hints.json`, Merge nach `company-discovery.hints.json`.
- `tests/Test-JobAgentRegionalDiscovery.ps1`: Funktionstest fuer Source-Policy, Tabellen-/Karten-/JSON-Parser, Dedupe, Zielgebiet, Hash-Evidenz, Kontaktfeldsperre.
- `docs/company-discovery-regional-directories.md`: Betriebsvertrag fuer regionale Verzeichnisse.
- `src/JobAgent.Coverage.psm1` und `tests/Test-JobAgentCoverage.ps1`: Coverage kennt `REGIONAL_DISCOVERY_HINT`.

## Versionierte Aenderungen
- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-discovery.regional-hints.json`
- `docs/company-discovery-regional-directories.md`
- `docs/test-matrix.json`
- `docs/test-matrix.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `Roadmap_archive.md`
- `Roadmap.md`
- `src/JobAgent.Coverage.psm1`
- `src/JobAgent.RegionalDiscovery.psm1`
- `tests/fixtures/jobagent/regional-discovery/`
- `tests/Test-JobAgentCoverage.ps1`
- `tests/Test-JobAgentRegionalDiscovery.ps1`
- `tests/Test-JobAgentSupertest.ps1`
- `tests/Test-JobAgentTestMatrix.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Import-JobAgentRegionalDirectories.ps1`

## Verifikation
- `pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd sonar-start` -> Exit `1` (sonar.cmd fehlt im Projektroot; Port 9000 lauscht, API-Status timed out)

## Offene Risiken

- SonarQube-API auf `:9000` hat getimeoutet; Port lauscht, aber `.\ci.cmd sonar-start` ist nicht nutzbar, weil `sonar.cmd` im Projektroot fehlt.
- Regionale Quellen sind selektive Hinweise, keine Vollstaendigkeits- oder Karrierequellenbelege.
- JA-027 muss falsche Merges verhindern; Review-Queue ist wichtiger als aggressive automatische Verschmelzung.

## Naechster Anker

JA-027: Deduplikation, Standortlogik und Kandidatenqualitaet fuer tausende Firmen skalieren. Start mit Kandidatenmodell/Schema fuer identity_cluster_id, dedupe_keys, conflict_flags, target_area_basis, source_count, first_seen_at, last_seen_at und review_queue_reason.
