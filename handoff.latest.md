# Handoff latest

Stand: 2026-08-28T12:54:32+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Abschluss-Commit: `a59ccb54318744ec021134ce089a1c47e9c88190`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt; `JA-027` ist fachlich nicht abgeschlossen.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt.
- Devserver: `http://localhost:8500/`, zuletzt `listening=True`, PID `23568`
- SonarQube: `http://localhost:9000/api/system/status`, zuletzt `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Fuer `JA-027` wurde eine weitere Website-Discovery-Welle verarbeitet.
- Verarbeitet wurden `25` Kandidaten.
- Ergebnis der Welle: `0` offizielle Website-Treffer, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`, `0` produktive Store-Upserts.
- Hauptgrund bei allen 25 Kandidaten: `Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.`
- `data/jobagent/store.json` wurde fachlich nicht geaendert.
- Aktualisiert wurden `data/jobagent/company-candidate-verification.queue.json` und `data/jobagent/company-discovery.hints.json`.
- Coverage wurde neu erzeugt: `logs/jobagent/company-coverage-20260828-105213.json`, `logs/jobagent/company-coverage-20260828-105213.md`, `html/jobagent/company-coverage.html`.
- Die Funktionstests haben anschliessend eine weitere Test-Coverage-Datei erzeugt: `logs/jobagent/company-coverage-20260828-105259.json`.
- STP wurde am `2026-08-28T12:54:32+02:00` ausgefuehrt und Todo-/Handoff-Artefakte wurden synchronisiert.

## Betroffene Kandidaten der letzten Welle

- `FGV Schmidle GmbH`
- `FIBU-MED GmbH`
- `FID`
- `Fidelity Information Services GmbH`
- `Filmproduktion Artjom Baranov`
- `financial.com`
- `Fink Dachtechnik GmbH`
- `Fink Gebaeudetechnik GmbH & Co. KG`
- `Fiori Chiari`
- `Fireball Labs`
- `Fischer Vroni Karl Winter OHG`
- `FlixBus`
- `Florian Wackerbauer Heizung Sanitaer Solar Service`
- `FlowCAD`
- `Fluppisoft GmbH`
- `Foerder- und Lernzentrum Aubing`
- `Forever Living Productions`
- `Formycon`
- `Forschungsgesellschaft fuer Energiewirtschaft mbH`
- `Forschungsstelle fuer Energiewirtschaft e.V.`
- `FQP`
- `FRAMOS GmbH`
- `Franka Emika GmbH`
- `Franz Augustin Bauunternehmung`
- `Franz Rudolf Borsch Berater und Gruendercoach`

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
- Kandidaten-Verification-Queue: `1785` Cluster, `1790` Kandidaten
- Queue-Status: `53 VERIFIED`, `1724 MANUAL_REVIEW_REQUIRED`, `8 RETRY_SCHEDULED`
- Queue-Aktionen: `1719 DISCOVER_OFFICIAL_WEBSITE`, `60 VERIFY_OFFICIAL_SITE`, `5 REJECT_DUPLICATE`, `1 MANUAL_DECISION`
- Ready Total: `0`
- Letzter Discovery-Run: `logs/jobagent/company-candidate-website-discovery-20260828-105155.json`

## Verifikation

- `.\ci.cmd devserver-status` -> Exit `0`; Port `8500` listening `True`
- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `0`; Status `UP`; Version `26.1.0.118079`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 0 offizielle Website-Treffer; 25 Manual Review
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; Coverage aktualisiert; target_inventory_gate_status=`failed`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=True
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
