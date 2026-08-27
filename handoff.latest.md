# Handoff latest

Stand: 2026-08-27T18:40:00+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `e9e85826311f`
- Upstream: `origin/master`
- Ahead/Behind vor Abschlusscommit: `0/0`
- Worktree vor Abschlusscommit: `dirty`, nur JA-027-Daten-/Todo-/Handoff-Aenderungen
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: nicht neu ausgefuehrt; Nutzeranweisung vom 2026-08-27: wenn Supertest nicht angefragt wurde, gilt er als erledigt.
- Devserver: zuletzt geprueft `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: zuletzt geprueft `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- Zwei weitere Website-Discovery-Wellen verarbeitet: `50` Kandidaten.
- Ergebnis der Wellen: `0` offizielle Websites verifiziert, `50` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Keine produktiven Firmen in `data/jobagent/store.json` importiert.
- Keine Roadmap-Rotation, weil JA-027 weiterhin offene Review-/Verifikationsarbeit enthaelt.
- Coverage erneut erzeugt und `html/jobagent/company-coverage.html` aktualisiert.
- `.\ci.cmd stp` wurde ausgefuehrt.

## Datenstand

- Produktive Firmen: `64`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1850`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Offizielle Quellen: `68`
- Discovery-Quellen: `1820`
- Queue: `0` Pending, `1752` Manual Review, `2` Retry geplant.

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-162821.json`
- `logs/jobagent/company-candidate-website-discovery-20260827-162924.json`
- `logs/jobagent/company-coverage-20260827-162947.json`
- `logs/jobagent/company-coverage-20260827-162947.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0` (2 Laeufe)
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `1`, einzig verbleibende Issue: `immutable_modified: Roadmap.md`. Das wurde nicht repariert, weil es eine separate Integritaets-/Pin-Entscheidung ist.

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidaten verifizieren/importieren:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Bei Code-Eingriff zuerst fokussierte Funktionstests ausfuehren; Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell gibt es keine Pending-Queue-Eintraege; zuerst wieder Website-Discovery laufen lassen.
