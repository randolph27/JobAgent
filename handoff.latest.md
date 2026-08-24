# Handoff latest

Stand: 2026-08-24T12:25:00+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `6af2b0e27c73`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Stage/Commit: `dirty`
- Route: `ok`
- Aktiver Todo: keiner gesetzt; fachlicher Anker bleibt `TD-0039` / `JA-025`
- Offene Roadmap-Punkte: `JA-025` und `JA-027`
- Roadmap-Rotation: keine Rotation erfolgt, weil weder `JA-025` noch `JA-027` komplett erledigt ist.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`.
- Devserver: `http://localhost:8500/`, PID `38292`, Port `8500` listening.
- Supertest: vom Nutzer nicht erneut angefragt; gemaess Nutzeranweisung gilt er fuer diesen Uebergabe-/Commit-Schritt als erledigt.

## Abgeschlossener Arbeitsschritt

`JA-025` wurde um einen massentauglicheren lokalen Snapshot-Import erweitert. Die Snapshot-Lane kann jetzt mehrere lokale Dump-Dateien direkt aus dem Manifest aufloesen:

- `input_path` fuer eine konkrete Datei.
- `input_glob` fuer mehrere Dateien per Dateimuster.
- `input_directory` plus `input_pattern` fuer Verzeichnisimporte.
- Leere Glob-/Directory-Matches brechen fail-closed ab.
- Bei mehreren gematchten Dateien wird ohne explizite `snapshot_id` je Datei eine eindeutige dateibasierte Snapshot-ID genutzt, damit Register-Hints aus CSV und JSONL nicht kollidieren.

Geaendert:

- `tools/Import-JobAgentCompanyDiscovery.ps1`
  - `Get-ToolSnapshotItemInputs` unterstuetzt `input_path`, `input_glob`, `input_directory` und `input_pattern`.
  - Match-Ergebnisse werden sortiert und einzeln als Input in die bestehende Snapshot-Lane gegeben.
  - Fehlende Dateien, fehlende Patterns und leere Matches werden explizit abgelehnt.

- `tests/Test-JobAgentCompanyInventory.ps1`
  - Snapshot-Lane-Test nutzt jetzt `input_glob` fuer die vorhandenen OffeneRegister-Fixtures.
  - Erwartung wurde auf `16` neue Hints angepasst, weil CSV und JSONL bei dateibasierter Snapshot-ID beide nachvollziehbar erhalten bleiben.

- `docs/company-discovery-operations.md`
  - Manifestvertrag fuer `input_path`, `input_glob`, `input_directory` und `input_pattern` dokumentiert.

- Aktualisierte Artefakte:
  - `data/jobagent/company-discovery.hints.json`
  - `data/jobagent/company-candidate-verification.queue.json`
  - `html/jobagent/company-coverage.html`
  - `todo.events.jsonl`
  - `todo.history.digest.json`
  - `todo.master.index.json`
  - `handoff.latest.json`
  - `handoff.latest.md`

## Verifikation

Ausgefuehrt und erfolgreich:

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
  - `new_hints_total`: `14`
  - `merged_hints_total`: `20`
  - `inputs_total`: `3`
  - `sources_total`: `5`
  - `productive_store_write`: `false`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1` -> Exit `0`
  - `companies_total`: `38`
  - `target_inventory_candidates_total`: `57`
  - `target_inventory_gap_to_1000`: `943`
  - `target_inventory_gate_status`: `failed`
  - `duplicate_groups`: `0`
  - `sources_total`: `73`
  - `official_sources`: `41`
  - `discovery_sources`: `32`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd devserver-status` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> `UP`

## Offene Aufgaben

1. Mit `JA-025` / `TD-0039` weitermachen.
   - Ziel bleibt: mindestens 1000 eindeutige, belegte Firmen- oder Arbeitgeberkandidaten fuer Muenchen, 20-km-Umkreis und Freising.
   - Aktueller Stand: `companies_total = 38`, `target_inventory_candidates_total = 57`, `target_inventory_gap_to_1000 = 943`.
   - Das Zielinventar-Gate bleibt fachlich korrekt `failed`; `JA-025` nicht rotieren.

2. Naechster technischer Schritt fuer `JA-025`.
   - Reale erlaubte OffeneRegister-Snapshot-Dateien lokal bereitstellen.
   - `data/jobagent/company-discovery.snapshot.json` auf die neuen lokalen Inputs erweitern.
   - Fuer mehrere Dateien jetzt bevorzugt `input_glob` oder `input_directory` + `input_pattern` verwenden.
   - Quelle muss in `data/jobagent/company-discovery.sources.json` freigegeben bleiben: `source-registry:offeneregister_dump`.
   - Parser akzeptiert realformatnahe OpenCorporates/OffeneRegister-Felder; keine personenbezogenen `officers` persistieren.
   - Danach ausfuehren:
     - `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`
     - `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`
     - fokussierte Tests: `Test-JobAgentRegisterDiscovery.ps1`, `Test-JobAgentCompanyInventory.ps1`, `Test-JobAgentImportWaves.ps1`, `Test-JobAgentCoverage.ps1`, ggf. `Test-JobAgentCompanyDedupeScale.ps1`.

3. Danach erst `JA-027` angehen.
   - Karriere-/ATS-Link-Ermittlung fuer die gewachsene Kandidatenbasis skalieren.
   - Generische Such-, FAQ- und Landingpages duerfen nicht als Jobdetail persistiert werden.
   - Jeder scanfaehige Firmen-/Joblink braucht offiziellen finalen URL-Nachweis.

## No-Gos

- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Keine Aggregatorlinks als Primaerbeleg.
- Keine produktiven Store-Upserts aus unverifizierten Discovery-Hints.
- Keine personenbezogenen Registerrollen aus OffeneRegister/OpenCorporates persistieren.
- Keine Roadmap-Rotation fuer `JA-025` oder `JA-027` ohne fachlich belegten Abschluss.
- Kein `git reset` ohne ausdrueckliche Nutzerfreigabe.
