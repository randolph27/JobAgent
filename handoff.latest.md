# Handoff latest

Stand: 2026-08-24T11:47:45+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `9be4ac42e754`
- Upstream: `origin/master`
- Worktree vor Commit: `dirty`
- Route: `ok`
- Aktiver Todo: keiner gesetzt
- Offene Roadmap-Punkte: `JA-025`, `JA-027`
- Roadmap-Rotation: keine Rotation erfolgt, weil kein aktiver Roadmap-Punkt fachlich komplett erledigt ist.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`
- Devserver: `http://localhost:8500/`, PID `38292`, Port `8500` listening

## Abgeschlossener Arbeitsschritt

JA-025 wurde um eine massentauglichere Snapshot-Lane erweitert. Das ist ein Teilschritt, kein kompletter Abschluss von JA-025.

Umgesetzt:

- `tools/Import-JobAgentCompanyDiscovery.ps1`
  - Snapshot-Manifest-Items koennen jetzt mehrere Eingaben ueber `inputs[]` enthalten.
  - Legacy-Manifestformat mit `input_path`, `snapshot_id`, `snapshot_date` auf Item-Ebene bleibt kompatibel.
  - Pro Input werden Pfad, Source-ID, Snapshot-ID und Snapshot-Datum normalisiert und fail-closed validiert.
  - Register-, Regional- und Jobboard-Snapshots werden pro Input verarbeitet.
  - Snapshot-Logs enthalten jetzt den Eingabedateinamen im Logpfad, damit Mehrfachinputs derselben Quelle nicht kollidieren.
  - Snapshot-Digest enthaelt neu `inputs_total` als Nachweis, wie viele konkrete Dateien verarbeitet wurden.

- `tests/Test-JobAgentCompanyInventory.ps1`
  - Snapshot-Lane-Test nutzt jetzt ein Multi-Input-Register-Item mit JSONL- und CSV-Fixture.
  - Der Test prueft `inputs_total == 4`, `sources_total == 6`, `new_hints_total == 15` und gemergte `hints_total == 15`.
  - Damit ist belegt, dass mehrere lokale Register-Snapshots in einer Lane verarbeitet werden koennen.

- Aktualisierte Artefakte durch Coverage-/STP-Laeufe:
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
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd drift-check` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Hinweis: `.\ci.cmd supertest` wurde in diesem Arbeitsschritt nicht neu ausgefuehrt. Laut aktueller Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt. Letzter gespeicherter Supertest-Nachweis im Handoff/Verify-Digest bleibt Exit `0`.

## Offene Aufgaben fuer den naechsten Chat

1. Mit `JA-025 / TD-0039` weitermachen.
   - Ziel bleibt: mindestens 1000 eindeutige, belegte Firmen- oder Arbeitgeberkandidaten fuer Muenchen, 20-km-Umkreis und Freising.
   - Aktueller produktiver Store enthaelt weiterhin deutlich weniger als 1000 Firmen; das Zielinventar-Gate ist absichtlich noch nicht gruen.
   - Die neue Multi-Input-Snapshot-Lane schafft die technische Grundlage, groessere lokale Snapshot-Dateien reproduzierbar einzuspeisen.

2. Naechster fachlicher Schritt fuer JA-025:
   - Reale, erlaubte Snapshot-Dateien fuer Register-/Regional-/Jobboard-Discovery vorbereiten oder importieren.
   - `data/jobagent/company-discovery.snapshot.json` so erweitern, dass pro Quelle mehrere lokale Inputs ueber `inputs[]` referenziert werden koennen.
   - Keine Live-/Paywall-/Login-/Captcha-Quellen nutzen.
   - Jobboersen nur als Discovery-Hints verwenden, nie als Primaerbeleg.
   - Unverifizierte Kandidaten in `data/jobagent/company-discovery.hints.json` und Verifikationsqueue halten.
   - Produktive Store-Upserts nur fuer `COMPANY_DOMAIN_VERIFIED`, `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`.

3. Konkrete empfohlene Reihenfolge:
   - Erst Snapshot-Fixtures oder lokale erlaubte Dumps auf mehrere hundert bis tausend Kandidaten erweitern.
   - Danach `tools/Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` ausfuehren und Digest/Hint-Store pruefen.
   - Danach `tools/Measure-JobAgentCompanyCoverage.ps1` ausfuehren und `target_inventory_candidates_total`, `target_inventory_gap_to_1000`, Dedupe-Cluster und Review-Queue auswerten.
   - Danach gezielte Verifikationswellen fuer Top-Kandidaten starten; keine unverifizierten Kandidaten produktiv importieren.

4. Danach `JA-027 / TD-0041` angehen.
   - Karriere-/ATS-Link-Ermittlung fuer die gewachsene Kandidatenbasis skalieren.
   - Generische Such-, FAQ- und Landingpages duerfen nicht als Jobdetail persistiert werden.
   - Jeder scanfaehige Firmen-/Joblink braucht offiziellen finalen URL-Nachweis.

## Wichtige Dateien

- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `tools/Import-JobAgentCompanyDiscovery.ps1`
- `tools/Measure-JobAgentCompanyCoverage.ps1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `src/JobAgent.CompanyInventory.psm1`
- `src/JobAgent.Coverage.psm1`
- `src/JobAgent.RegisterDiscovery.psm1`
- `src/JobAgent.RegionalDiscovery.psm1`
- `src/JobAgent.JobBoardDiscovery.psm1`
- `tests/Test-JobAgentCompanyInventory.ps1`
- `tests/Test-JobAgentRegisterDiscovery.ps1`
- `tests/Test-JobAgentCoverage.ps1`
- `tests/Test-JobAgentImportWaves.ps1`
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
- `data/jobagent/company-discovery.snapshot.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`

## No-Gos

- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Keine Aggregatorlinks als Primaerbeleg.
- Keine produktiven Store-Upserts aus unverifizierten Discovery-Hints.
- Keine Roadmap-Rotation fuer JA-025 oder JA-027 ohne fachlich belegten Abschluss.
- Kein `git reset` ohne ausdrueckliche Nutzerfreigabe.
