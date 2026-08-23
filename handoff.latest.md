# Handoff latest

Stand: 2026-08-23T08:13:46.030+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `1a597cd5540b`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Active: ``
- Status: `open`
- Letzter abgeschlossener Roadmap-Punkt: `JA-023 Quellenkatalog fuer maximale Firmen-Discovery nach Evidenzklasse erstellen`
- Naechster aktiver Roadmap-Punkt: `JA-024 Offizielle regionale Arbeitgeberlisten in Discovery-Feed importieren`

## Abgeschlossen

`JA-023` ist fachlich fertig und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.

Erstellt oder erweitert:

- `data/jobagent/company-discovery.sources.json`: Discovery Source Registry mit 12 Quellen.
- `schemas/jobagent.discovery-source.schema.json`: JSON-Schema fuer den Quellenkatalog.
- `src/JobAgent.Coverage.psm1`: `New-JobAgentDiscoverySourceCoverageReport` fuer Quellebene.
- `tests/Test-JobAgentCoverage.ps1`: Schema-, Coverage- und Guardrail-Tests fuer den Quellenkatalog.
- `docs/data-model.md`: Abschnitt `Discovery Source Registry`.
- `logs/jobagent/ja-023-source-coverage.json`: Coverage-Nachweis.

Coverage-Stand `JA-023`:

- Quellen gesamt: `12`
- `OFFICIAL_DIRECTORY`: `2`
- `PUBLIC_JOBBOARD_HINT`: `3`
- `BUSINESS_NETWORK_HINT`: `1`
- `REGISTER_HINT`: `2`
- `STARTUP_CLUSTER_HINT`: `1`
- `SECTOR_CLUSTER_HINT`: `1`
- `MANUAL_REVIEW_ONLY`: `1`
- `REJECTED`: `1`
- Importierbar: `8`
- Manual Review: `9`
- Offene Verifikationsluecken: `11`
- Abgelehnt: `source-registry:linkedin_jobs`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0` vor `stp`; nach `stp` nicht erneut ausgefuehrt.

Sonar-Hinweis:

- `curl`/`Invoke-RestMethod` gegen `http://localhost:9000/api/system/status` bekam keine API-Antwort innerhalb des Timeouts.
- `.\ci.cmd sonar-start` schlug fehl, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt.
- Port `9000` wurde von Windows als `Listen` gesehen, aber nicht als funktionierende Sonar-API bestaetigt.

## Naechste Aufgabe

Mit `JA-024` fortfahren.

Ziel:

- `data/jobagent/company-discovery.regional.json` erstellen.
- Kandidaten aus priorisierten offiziellen/regionalen Quellen kuratieren.
- Pro Kandidat offizielle Website und Karrierepfad direkt belegen oder `career_url = null` setzen.
- Keine unverifizierte Quelle als `JobSource` erzeugen.
- Deduplikation gegen bestehende 20 Store-Firmen sicherstellen.

Priorisierte Quellen fuer `JA-024`:

- Stadt Muenchen boersennotierte Unternehmen:
  `source-registry:stadt_muenchen_boersennotierte_unternehmen`
- Landkreis Freising Wirtschaft:
  `source-registry:landkreis_freising_wirtschaft`
- Stadt Freising Weihenstephan:
  `source-registry:stadt_freising_weihenstephan`
- EMM Mitglieder:
  `source-registry:emm_members`
- EMM Innovation/Cluster:
  `source-registry:emm_innovation_mapping`

Kandidaten laut Roadmap-Ist-Stand fuer erste Welle:

- Scout24
- Siemens Energy
- CTS Eventim
- HENSOLDT
- Nemetschek
- TRATON
- Wacker Chemie
- ATOSS
- CANCOM
- Dermapharm
- Deutsche Pfandbriefbank
- Mutares
- Nagarro
- ProSiebenSat.1
- SFC Energy
- Siltronic
- Sixt
- SUSS MicroTec
- Wacker Neuson
- Flughafen Muenchen
- Texas Instruments Deutschland
- Jungheinrich Moosburg
- Fraunhofer IVV
- IZB
- Staatsbrauerei/Molkerei Weihenstephan
- Krones/Steinecker

Funktionstest fuer `JA-024`:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1
pwsh -NoProfile -File tools\Import-JobAgentCompanyDiscovery.ps1 -FeedPath data\jobagent\company-discovery.regional.json
```

Supertest nach gruenem Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1
```

## Offene aktive Roadmap

- `JA-024`: Offizielle regionale Arbeitgeberlisten in Discovery-Feed importieren.
- `JA-025`: Sekundaere Job- und Unternehmensverzeichnisse als Hinweisquellen operationalisieren.
- `JA-026`: Automatische Karrierepfad- und ATS-Verifikation fuer Firmenkandidaten bauen.
- `JA-027`: Firmen-Coverage-Audit und priorisierte Importwellen fuer maximale Abdeckung einfuehren.
