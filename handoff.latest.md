# Handoff latest

Stand: 2026-08-27T18:22:25.173+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `faf2509d477c`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, nur JA-027-Code-/Daten-/Todo-/Handoff-Aenderungen
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: nicht neu ausgefuehrt; Nutzeranweisung vom 2026-08-27: wenn Supertest nicht angefragt wurde, gilt er als erledigt.
- Devserver: zuletzt geprueft `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: zuletzt geprueft `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- Zwei weitere Website-Discovery-Wellen verarbeitet: 50 Kandidaten, davon 2 offizielle Websites gefunden und 48 Kandidaten fail-closed in Manual Review belassen.
- `All Nippon Airways` wurde ueber die Muenchen-Japan-Community-Quellseite als offizielle Website `https://ana.co.jp/` erkannt, aber nicht produktiv importiert, weil kein offiziell belegter Karriere- oder ATS-Link gefunden wurde.
- `Astellas Pharma GmbH` wurde ueber die Muenchen-Japan-Community-Quellseite als offizielle Website `https://astellas.com/` erkannt, aber nicht produktiv importiert, weil kein offiziell belegter Karriere- oder ATS-Link gefunden wurde.
- Beide Kandidaten stehen mit zukuenftigem `next_attempt_at` auf `RETRY_SCHEDULED`.
- Regression in der Candidate-Review-Queue behoben: `RETRY_SCHEDULED`-Eintraege werden beim Queue-Rebuild bis zum faelligen `next_attempt_at` nicht sofort wieder zu `PENDING`.
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` enthaelt jetzt einen Regressionstest fuer den Retry-Skip bis `next_attempt_at`.
- Coverage-JSON, Coverage-Markdown und `html/jobagent/company-coverage.html` aktualisiert.
- `.\ci.cmd stp` wurde ausgefuehrt.

## Datenstand

- Produktive Firmen: `64`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1850`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Offizielle Quellen: `68`
- Discovery-Quellen: `1820`
- Queue: `32` verifiziert, `1752` Manual Review, `2` Retry geplant, `0` Pending.

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.Coverage.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-161618.json`
- `logs/jobagent/company-candidate-verification-20260827-161640.json`
- `logs/jobagent/company-candidate-website-discovery-20260827-161714.json`
- `logs/jobagent/company-candidate-verification-20260827-161737.json`
- `logs/jobagent/company-candidate-verification-20260827-161853.json`
- `logs/jobagent/company-coverage-20260827-161906.json`
- `logs/jobagent/company-coverage-20260827-161906.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0` (2 Laeufe)
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0` (3 Laeufe; letzter Lauf `processed_total=0`)
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- Supertest nicht ausgefuehrt, weil JA-027 nicht abgeschlossen ist und laut Nutzeranweisung ohne explizite Anfrage als erledigt gilt.

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten: `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidaten verifizieren/importieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Bei Code-Eingriff zuerst fokussierte Funktionstests ausfuehren; Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell gibt es keine Pending-Queue-Eintraege; zuerst wieder Website-Discovery laufen lassen.
