# Handoff latest

Stand: 2026-08-28T13:24:57.110+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `67df7deddef0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt; `JA-027` ist fachlich nicht abgeschlossen.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt.
- Devserver: `http://localhost:8500/`, Status zuletzt `listening=True`, PID `23568`
- SonarQube: `http://localhost:9000/api/system/status`, Status zuletzt `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Fuer `JA-027` wurde eine weitere Website-Discovery-Welle verarbeitet.
- Verarbeitet wurden `25` Kandidaten.
- Ergebnis der Welle: `0` offizielle Website-Treffer, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`, `0` produktive Store-Upserts.
- Hauptgrund bei allen 25 Kandidaten: `Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.`
- `data/jobagent/store.json` wurde fachlich nicht geaendert.
- Aktualisiert wurden `data/jobagent/company-candidate-verification.queue.json` und `data/jobagent/company-discovery.hints.json`.
- Coverage wurde neu erzeugt: `logs/jobagent/company-coverage-20260828-112217.json`, `logs/jobagent/company-coverage-20260828-112217.md`, `html/jobagent/company-coverage.html`.
- STP wurde am `2026-08-28T13:24:57+02:00` ausgefuehrt und Todo-/Handoff-Artefakte wurden synchronisiert.

## Betroffene Kandidaten der letzten Welle

- `goyellow GmbH`
- `Graf Dichtungen GmbH`
- `Graphik Buero Andrea Schmidt`
- `GRAPHISOFT`
- `Grauberger Massivbau GmbH`
- `Green City e.V.`
- `Green City Projekt GmbH`
- `Greenyard`
- `GRIN Verlag GmbH`
- `GRUMA`
- `Grunwald Kommunikation und Marketingdienstleistungen GmbH & Co. KG`
- `GRV Versorgungstechnik`
- `GWG Muenchen Hausverwaltung Berg am Laim Ramersdorf`
- `H. Gautzsch Muenchen F. Piotrowski GmbH & Co. KG`
- `H&D Unternehmensberatung`
- `H&Z Unternehmensberatung AG`
- `HAGA Bauvision`
- `Hallo Verlag GmbH & Co. KG`
- `Hand- und Fusspflege Studio mit O.P.I`
- `Hannover Leasing GmbH & Co. KG`
- `Hans Brandl`
- `Hansmann PR Brunnthaler & Geisler GmbH`
- `Happy People GmbH`
- `Harry Kuhn Installationshaustechnik`
- `Hase und Igel Verlag`

## Datenstand nach Coverage und Queue

- Produktive Firmen: `85`
- Target-Inventory-Kandidaten: `1870`
- Target-Inventory-Gap zu 1000: `0`
- Target-Inventory-Gate: `failed`
- Backlog Items: `85`
- Duplicate Groups: `0`
- Source Inventory: `1904` Quellen
- Offizielle Quellen: `84`
- Discovery-Quellen: `1820`
- Import Waves: `4`
- Letzter Discovery-Run: `logs/jobagent/company-candidate-website-discovery-20260828-112158.json`

## Verifikation

- `.\ci.cmd devserver-status` -> Exit `0`; Port `8500` listening `True`
- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `0`; Status `UP`; Version `26.1.0.118079`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 0 offizielle Website-Treffer; 25 Manual Review
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; Coverage aktualisiert; target_inventory_gate_status=`failed`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=`True`
- `.\ci.cmd stp` -> Exit `0`; Todo/Handoff synchronisiert
- `.\ci.cmd supertest` wurde nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt.

## Dateien fuer Abschluss-Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Naechste Aufgaben

1. Weiter mit `JA-027`: naechste Website-Discovery-Welle starten: `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`.
2. Wenn `verified_total > 0`, Kandidatenverifikation starten: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`.
3. Danach Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`.
4. Danach fokussierte Funktionstests ausfuehren: `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`.
5. Danach `.\ci.cmd route-check` und `.\ci.cmd stp` ausfuehren.
6. `JA-027` erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
