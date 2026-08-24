# Handoff latest

Stand: 2026-08-24T12:12:56+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `898ea591d5be`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Stage/Commit: `dirty`
- Route: `ok`
- Aktiver Todo: keiner gesetzt; fachlicher Anker bleibt `TD-0039` / `JA-025`
- Offene Roadmap-Punkte: `JA-025` und `JA-027`
- Roadmap-Rotation: keine Rotation erfolgt, weil kein Roadmap-Punkt komplett erledigt ist.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`.
- Devserver: `http://localhost:8500/`, PID `38292`, Port `8500` listening.
- Supertest: vom Nutzer nicht angefragt; gemaess aktueller Nutzeranweisung gilt er fuer diesen Uebergabe-/Commit-Schritt als erledigt und wurde nicht erneut ausgefuehrt.

## Abgeschlossener Arbeitsschritt

`JA-025` wurde um einen Import-Teilschritt erweitert: Register-Discovery kann jetzt das reale OffeneRegister/OpenCorporates-JSONL-Format mit verschachtelten `all_attributes`-Feldern auswerten.

Umgesetzt:

- `src/JobAgent.RegisterDiscovery.psm1`
  - neuer Helper fuer verschachtelte Objektfelder.
  - `all_attributes.registered_office` wird als Registerort gelesen, wenn kein flacher Ort vorhanden ist.
  - `all_attributes.registrar` wird als Registergericht gelesen, wenn kein flaches Registergericht vorhanden ist.
  - `native_company_number` sowie `_registerArt` + `_registerNummer` werden als Registernummern-Basis akzeptiert.
  - doppelte Gerichts-/Orts-Prefixe aus `native_company_number` werden entfernt, damit Dedupe-Keys stabil bleiben.
  - `current_status` wird als Statusfeld akzeptiert.
  - personenbezogene `officers` werden weiterhin nicht in Hints persistiert.

- `tests/Test-JobAgentRegisterDiscovery.ps1`
  - realformatnaher OpenCorporates/OffeneRegister-JSONL-Test fuer `all_attributes`.
  - prueft Zielgebiet-Erkennung aus `registered_office`.
  - prueft Registergericht und Register-Dedupe-Key.
  - prueft, dass `officers` nicht persistiert werden.

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

- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
  - `new_hints_total`: `14`
  - `merged_hints_total`: `20`
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
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd devserver-status` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> `UP`

## Offene Aufgaben

1. Mit `JA-025` / `TD-0039` weitermachen.
   - Ziel bleibt: mindestens 1000 eindeutige, belegte Firmen- oder Arbeitgeberkandidaten fuer Muenchen, 20-km-Umkreis und Freising.
   - Aktueller Stand: `companies_total = 38`, `target_inventory_candidates_total = 57`, `target_inventory_gap_to_1000 = 943`.
   - Das Zielinventar-Gate bleibt fachlich korrekt `failed`; `JA-025` nicht rotieren.

2. Naechster technischer Schritt fuer `JA-025`.
   - Reale erlaubte OffeneRegister-Snapshot-Dateien lokal bereitstellen oder importieren.
   - `data/jobagent/company-discovery.snapshot.json` auf die neuen lokalen Inputs erweitern.
   - Quelle muss in `data/jobagent/company-discovery.sources.json` freigegeben bleiben: `source-registry:offeneregister_dump`.
   - Parser akzeptiert jetzt realformatnahe OpenCorporates/OffeneRegister-Felder; keine personenbezogenen `officers` persistieren.
   - Danach ausfuehren:
     - `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`
     - `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`
     - fokussierte Tests: `Test-JobAgentRegisterDiscovery.ps1`, `Test-JobAgentImportWaves.ps1`, `Test-JobAgentCoverage.ps1`, ggf. `Test-JobAgentCompanyDedupeScale.ps1`.

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
