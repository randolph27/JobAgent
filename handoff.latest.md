# Handoff latest

Stand: 2026-08-24T12:00:44+02:00

## Zustand

- Projekt: `JobAgent`
- Arbeitsverzeichnis: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `842dd97d4d92`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Stage/Commit: `dirty`
- Route: `ok`
- Aktiver Todo: keiner gesetzt
- Offene Todo-/Roadmap-Anker:
  - `TD-0039` / `JA-025` Firmeninventar auf mindestens 1000 verifizierte oder pruefbare Zielgebiet-Kandidaten erweitern
  - `TD-0041` / `JA-027` Verifizierte Karriere-/ATS-Link-Ermittlung fuer Firmen- und Jobquellen skalieren
- Roadmap-Rotation: keine Rotation erfolgt; `JA-025` und `JA-027` sind fachlich offen.
- SonarQube: `http://localhost:9000/api/system/status` meldete `UP`, Version `26.1.0.118079`
- Devserver: `http://localhost:8500/`, PID `38292`, Port `8500` listening
- Supertest: nicht neu ausgefuehrt, weil kein Roadmap-Punkt abgeschlossen wurde und der Nutzer nicht explizit Supertest angefragt hat; laut Nutzeranweisung gilt er damit als erledigt.

## Abgeschlossener Arbeitsschritt

`JA-025` wurde um einen weiteren Teilschritt erweitert: Regionale Discovery bewertet Zielgebietsbezug jetzt auch ueber Koordinaten, nicht nur ueber bekannte Orts-/Regionsnamen.

Umgesetzt:

- `src/JobAgent.RegionalDiscovery.psm1`
  - Koordinatenparser fuer numerische Werte und Dezimalkomma ergaenzt.
  - Haversine-Distanzberechnung ergaenzt.
  - `Get-JobAgentRegionalTargetArea` akzeptiert optional `Latitude` und `Longitude`.
  - Regionale Datensaetze lesen Koordinatenfelder aus `latitude`, `lat`, `geo_lat`, `y` sowie `longitude`, `lon`, `lng`, `geo_lon`, `x`.
  - Unbekannte Regionalorte werden als `MUNICH_20KM` bewertet, wenn die Koordinaten maximal 20 km vom Muenchner Zentrum entfernt sind.
  - Unbekannte Regionalorte werden als `FREISING` bewertet, wenn die Koordinaten maximal 5 km vom Freisinger Zentrum entfernt sind.
  - Out-of-scope bleibt fail-closed, wenn weder Orts-/Regionstext noch Koordinaten Zielgebietsbezug belegen.

- `tests/Test-JobAgentRegionalDiscovery.ps1`
  - Tests fuer koordinatenbasierte Zielgebietszuordnung ergaenzt.
  - Test fuer Dezimalkomma-Koordinaten ergaenzt.
  - Test fuer koordinatenbasierten Out-of-scope-Reject ergaenzt.
  - Regionalimport-Test erwartet jetzt 6 Hints statt 5.
  - Script-Test fuer Regionalimport erwartet jetzt 6 geschriebene und gemergte Hints.

- `tests/fixtures/jobagent/regional-discovery/regional-directories-snapshot.json`
  - Fixture `Coordinate Park GmbH` mit unspezifischem Standort `Gewerbegebiet` und Koordinaten nahe Muenchen ergaenzt.

- Aktualisierte Artefakte:
  - `data/jobagent/company-discovery.hints.json`: Snapshot-Lane merged jetzt 20 Hints.
  - `data/jobagent/company-candidate-verification.queue.json`: Verifikationsqueue jetzt 19 Cluster / 20 Kandidaten.
  - `html/jobagent/company-coverage.html`
  - `html/jobagent/ja-022-viewport-audit.html`
  - `todo.events.jsonl`
  - `todo.history.digest.json`
  - `todo.master.index.json`
  - `handoff.latest.json`
  - `handoff.latest.md`

## Verifikation

Ausgefuehrt und erfolgreich:

- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
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
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
  - URL: `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html`
  - Viewports: `1920`, `1366`, `800`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd drift-check` -> Exit `0`

## Offene Aufgaben fuer den naechsten Chat

1. Mit `JA-025 / TD-0039` weitermachen.
   - Ziel bleibt: mindestens 1000 eindeutige, belegte Firmen- oder Arbeitgeberkandidaten fuer Muenchen, 20-km-Umkreis und Freising.
   - Aktueller Stand nach diesem Teilschritt: `companies_total = 38`, `target_inventory_candidates_total = 57`, `target_inventory_gap_to_1000 = 943`.
   - Das Zielinventar-Gate bleibt fachlich korrekt `failed`; Roadmap-Punkt nicht rotieren.

2. Naechster fachlicher Schritt fuer `JA-025`.
   - Reale, erlaubte lokale Register-/Regional-/Jobboard-Snapshot-Dateien vorbereiten oder importieren.
   - `data/jobagent/company-discovery.snapshot.json` auf mehrere lokale Inputs erweitern.
   - Quellen muessen in `data/jobagent/company-discovery.sources.json` freigegeben sein.
   - Keine Live-/Paywall-/Login-/Captcha-Quellen nutzen.
   - Jobboersen nur als Discovery-Hints verwenden, nie als Primaerbeleg.
   - Unverifizierte Kandidaten bleiben in `data/jobagent/company-discovery.hints.json` und der Verifikationsqueue.
   - Produktive Store-Upserts nur fuer `COMPANY_DOMAIN_VERIFIED`, `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`.

3. Empfohlene Reihenfolge.
   - Erlaubte lokale Register-/Regional-Snapshots auf mehrere hundert bis tausend Kandidaten erweitern.
   - Falls Regional- oder Registerdaten Koordinaten enthalten, Felder `latitude`/`longitude` oder kompatible Aliase nutzen.
   - `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` ausfuehren.
   - Digest, Snapshot-Logs und `data/jobagent/company-discovery.hints.json` pruefen.
   - `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1` ausfuehren.
   - `target_inventory_candidates_total`, `target_inventory_gap_to_1000`, Dedupe-Cluster und Review-Queue auswerten.
   - Danach gezielte Verifikationswellen fuer Top-Kandidaten starten; keine unverifizierten Kandidaten produktiv importieren.

4. Danach `JA-027 / TD-0041` angehen.
   - Karriere-/ATS-Link-Ermittlung fuer die gewachsene Kandidatenbasis skalieren.
   - Generische Such-, FAQ- und Landingpages duerfen nicht als Jobdetail persistiert werden.
   - Jeder scanfaehige Firmen-/Joblink braucht offiziellen finalen URL-Nachweis.

## No-Gos

- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Keine Aggregatorlinks als Primaerbeleg.
- Keine produktiven Store-Upserts aus unverifizierten Discovery-Hints.
- Keine Roadmap-Rotation fuer `JA-025` oder `JA-027` ohne fachlich belegten Abschluss.
- Kein `git reset` ohne ausdrueckliche Nutzerfreigabe.
