# Handoff latest

Stand: 2026-08-27T19:23:37.476+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `2c5ac935c63a`
- Upstream: `origin/master`
- Ahead/Behind vor Abschluss-Commit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: laut Nutzeranweisung als erledigt behandelt; nicht neu ausgefuehrt.
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Weitere Website-Discovery-Welle fuer JA-027 verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `0` offizielle Website-Treffer, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Keine Kandidatenverifikation ausgefuehrt, weil `verified_total=0`.
- Produktiv hinzugefuegt: `0` Firmen.
- Coverage aktualisiert: `companies_total=69`, `job_sources_total=69`, `duplicate_groups=0`, `target_inventory_gate_status=failed`.
- STP ausgefuehrt: Todo-/Handoff-Artefakte synchronisiert.

## Datenstand

- Produktive Firmen: `69`
- JobSources: `69`
- Kandidatenqueue: `1786` Cluster, `1790` Kandidaten
- Queue ready: `0`
- Queue-Aktionen: `1740` DISCOVER_OFFICIAL_WEBSITE, `41` VERIFY_OFFICIAL_SITE, `4` REJECT_DUPLICATE, `1` MANUAL_DECISION
- Source Inventory: `1891` Quellen, davon `71` offizielle Quellen und `1820` Discovery-Quellen
- Target-Inventory-Gate: `failed`

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-172054.json`
- `logs/jobagent/company-coverage-20260827-172118.json`
- `logs/jobagent/company-coverage-20260827-172118.md`
- `html/jobagent/company-coverage.html`
- `logs/terminal/route-check-20260827-192214.log`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 0 offizielle Website-Treffer; 25 Manual Review
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=69; sources_total=1891; target_inventory_gate_status=failed
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=True
- `.\ci.cmd stp` -> Exit `0`; Todo/Handoff synchronisiert

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten: `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidatenverifikation starten: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Danach Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren: `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
