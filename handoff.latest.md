# Handoff latest

Stand: 2026-08-28T12:29:43+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Abschluss-Commit: `cdbbbd072a78`
- Ahead/Behind vor Abschluss-Commit: `0/0`
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
- Hauptgrund: `Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.`
- `data/jobagent/store.json` wurde fachlich nicht geaendert.
- Aktualisiert wurden `data/jobagent/company-candidate-verification.queue.json` und `data/jobagent/company-discovery.hints.json`.
- Coverage wurde neu erzeugt: `logs/jobagent/company-coverage-20260828-102727.json`, `logs/jobagent/company-coverage-20260828-102727.md`, `html/jobagent/company-coverage.html`.
- STP wurde am `2026-08-28T12:29:43+02:00` ausgefuehrt und Todo-/Handoff-Artefakte wurden synchronisiert.

## Betroffene Kandidaten der letzten Welle

- `Dube Visuelle Kommunikation`
- `Dynarep`
- `dynaware Systemberatung GmbH`
- `E.ON Digital Technology GmbH`
- `E.ON Energy Projects GmbH`
- `Easylan GmbH`
- `Eazee`
- `EAZF`
- `Eckhaus im Werksviertel`
- `Eco Clean Gebaeudereinigung`
- `Econ Referenten Agentur`
- `ECOUNT GmbH`
- `EDAG Engineering AG`
- `EDAG Testing Solutions GmbH`
- `Eder Stapler`
- `edilon)(sedra`
- `EDL Rethschulte GmbH`
- `eeEat`
- `EEP Energieconsulting GmbH`
- `EGYM SE`
- `EHT Breit`
- `Eigenheimerverband`
- `Eisbach Studios`
- `EKM`
- `Elektro Kastrati`

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
- Kandidaten-Verification-Queue: `1785` Cluster
- Queue-Status: `53 VERIFIED`, `1724 MANUAL_REVIEW_REQUIRED`, `8 RETRY_SCHEDULED`
- Bereit laut aktueller Coverage-Metrik: `8`
- Candidate Review Queue: `1732`
- Candidate Conflict Cluster: `252`
- Letzter Discovery-Run: `logs/jobagent/company-candidate-website-discovery-20260828-102709.json`

## Verifikation

- `git -c core.pager=cat -c color.ui=false --no-pager status --short --branch` -> Exit `0`; Branch `master`, Ahead/Behind `0/0` vor Commit
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
