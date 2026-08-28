# Handoff latest

Stand: 2026-08-28T07:10:36.191+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Commit: `57e1494a1b95`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 noch nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- Devserver: `http://localhost:8500/`, Status vor Abschluss `listening=True`
- SonarQube: `http://localhost:9000/api/system/status`, Status vor Abschluss `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Eine weitere Website-Discovery-Welle fuer JA-027 verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `0` offizielle Website-Treffer, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Kandidatenverifikation nicht ausgefuehrt, weil `verified_total=0`.
- Produktiv hinzugefuegte Firmen in diesem Schritt: `0`.
- Die Kandidatenqueue wurde aktualisiert: die 25 verarbeiteten Cluster haben `last_attempt_at=2026-08-28T05:09:09.46Z`, `last_status=MANUAL_REVIEW_REQUIRED` und konkrete `last_reason`-Werte.
- Typische Gruende: keine eindeutig namenspassende Firmenwebsite auf der offiziellen Quellseite gefunden oder Quellentyp nicht als offizieller Website-Ermittlungsbeleg zugelassen.

## Datenstand nach Coverage

- Produktive Firmen: `81`
- Backlog-Items: `81`
- Candidate-Hints: `1790`
- Kandidatenqueue: `1785` Cluster
- Queue ready: `7`
- Queue verified total: `49`
- Queue manual review total: `1729`
- Queue retry scheduled/exhausted: `0` exhausted; Retry-Details weiter in der Queue pruefen
- Target-Inventory-Kandidaten: `1866`
- Source Inventory: `1900` Quellen, davon `80` offizielle Quellen und `1820` Discovery-Quellen
- Target-Inventory-Gate: `failed`
- Duplicate Groups: `0`
- Import Waves: `4`

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260828-050909.json`
- `logs/jobagent/company-coverage-20260828-050935.json`
- `logs/jobagent/company-coverage-20260828-050935.md`
- `logs/jobagent/company-coverage-20260828-051002.json`
- `html/jobagent/company-coverage.html`
- `logs/terminal/route-check-20260828-071030.log`

## Verifikation

- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `0`; Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`; Port `8500` listening `True`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 0 offizielle Website-Treffer; 25 Manual Review
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=81; target_inventory_gate_status=failed
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=True
- `.\ci.cmd stp` -> Exit `0`; Todo/Handoff synchronisiert

## Naechste Aufgaben

1. Weiter mit JA-027: neue Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidatenverifikation starten:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Danach Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren:
   `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
   `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. Danach `.\ci.cmd route-check` und `.\ci.cmd stp` ausfuehren.
6. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
