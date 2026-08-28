# Handoff latest

Stand: 2026-08-28T08:43:25.239+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Abschluss-Commit: `d7ece7a21d80`
- Ahead/Behind vor Abschluss-Commit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt; `JA-027` ist fachlich noch nicht komplett erledigt.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt, sofern nicht explizit angefragt.
- Devserver: `http://localhost:8500/`, zuletzt `listening=True`
- SonarQube: `http://localhost:9000/api/system/status`, zuletzt `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Eine weitere Website-Discovery-Welle fuer `JA-027` verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `0` offizielle Website-Treffer, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Grund fuer alle 25 Kandidaten dieser Welle: `Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.`
- Es wurde kein Kandidat produktiv in `data/jobagent/store.json` uebernommen.
- Store blieb fachlich unveraendert.
- Queue und Hint-Status wurden aktualisiert:
  - `data/jobagent/company-candidate-verification.queue.json`
  - `data/jobagent/company-discovery.hints.json`
- Coverage wurde neu erzeugt:
  - `logs/jobagent/company-coverage-20260828-064220.json`
  - `logs/jobagent/company-coverage-20260828-064220.md`
  - `html/jobagent/company-coverage.html`
- STP wurde ausgefuehrt; Todo-/Checkpoint-/Handoff-Dateien sind synchronisiert.

## Betroffene Kandidaten der letzten Welle

- `Automaten Seitz Vertrieb und Kundendienst GmbH`
- `automatic Systeme GmbH`
- `Avedo`
- `Aviva Munich`
- `AWA`
- `AXA Versicherung`
- `Axcorn`
- `Axxiome`
- `B.I.G. and STEALEX GmbH`
- `B.L.F. Verlagsgesellschaft mbH`
- `B2X Care Solutions`
- `Bain and Company`
- `Balsan Cosmetic`
- `Baobab Social Business GmbH`
- `Barrelbrothers`
- `basismedia`
- `Basycon Unternehmensberatung GmbH`
- `Bauer and Kusterer`
- `Bauer Media Group`
- `Baugeschaeft Fendt and Behringer`
- `Bausch and Lomb`
- `Bavaria Entertainment GmbH`
- `Bavaria Film GmbH`
- `Bavaria Group`
- `Bavaria Petrol`

## Datenstand nach Coverage

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
- Letzter Discovery-Run: `logs/jobagent/company-candidate-website-discovery-20260828-064157.json`

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

## Geaenderte Dateien fuer Abschluss-Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Naechste Aufgaben

1. Weiter mit `JA-027`: naechste Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidatenverifikation starten:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Danach Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren:
   `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
   `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. Danach `.\ci.cmd route-check` und `.\ci.cmd stp` ausfuehren.
6. `JA-027` erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
