# Handoff latest

Stand: 2026-08-27T18:00:30.000+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `fef16a103431`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, ausschliesslich JA-027-Code-/Daten-/Todo-/Handoff-Aenderungen
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: nicht neu ausgefuehrt; Nutzeranweisung vom 2026-08-27: wenn Supertest nicht angefragt wurde, gilt er als erledigt.
- Devserver: vorher geprueft `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: vorher geprueft `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1` korrigiert: fail-closed Website-Discovery-Ergebnisse werden mit `last_attempt_at`, `last_status` und `last_reason` in `data/jobagent/company-candidate-verification.queue.json` persistiert.
- Bereits gepruefte `DISCOVER_OFFICIAL_WEBSITE`-Queue-Eintraege werden im naechsten Discovery-Lauf nicht sofort erneut verarbeitet.
- `src/JobAgent.SourceVerification.psm1` korrigiert: `REGIONAL_DIRECTORY` reicht nur noch mit `SECONDARY_OFFICIAL_DIRECTORY` oder `PRIMARY_OFFICIAL` als offizieller Website-Beleg.
- Reine Discovery-Hints, z. B. GitHub-Listen mit `evidence_level=DISCOVERY_HINT`, bleiben Review-Hinweise und duerfen keine produktive Firmenaufnahme begruenden.
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` erweitert: Test fuer Wiederholungs-Skip fail-closed gepruefter Website-Discovery und Test fuer Reject regionaler Discovery-Hints ohne offiziellen Evidenzlevel.
- Zwei Discovery-Wellen verarbeitet: 50 Kandidaten, davon 20 offizielle Websites gefunden; 30 Kandidaten fail-closed in Manual Review belassen.
- Verifikations-/Importwellen verarbeitet: 18 Kandidaten produktiv uebernommen.
- `36ZERO Vision` wurde wegen GitHub-Discovery-Hint nicht produktiv importiert und in Manual Review zurueckgesetzt.
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
- Queue: `32` verifiziert, `1754` Manual Review, `1711` noch unversuchte Website-Discovery-Kandidaten, `0` Pending.

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-155314.json`
- `logs/jobagent/company-candidate-verification-20260827-155337.json`
- `logs/jobagent/company-candidate-website-discovery-20260827-155508.json`
- `logs/jobagent/company-candidate-verification-20260827-155620.json`
- `logs/jobagent/company-coverage-20260827-155648.json`
- `logs/jobagent/company-coverage-20260827-155648.md`
- `html/jobagent/company-coverage.html`
- `data/jobagent/backups/store-20260827T155640436Z-pre-write.json`

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- Supertest nicht ausgefuehrt, weil JA-027 nicht abgeschlossen ist und nicht explizit angefragt wurde.

## Naechste Aufgaben

1. Weitere Discovery-Welle starten: `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidaten verifizieren/importieren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Bei weiterem Code-Eingriff zuerst fokussierte Funktionstests ausfuehren; Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell gibt es keine Pending-Queue-Eintraege; zuerst wieder Website-Discovery laufen lassen.
