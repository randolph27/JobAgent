# Handoff latest

Stand: 2026-08-27T17:22:32.848+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `aeabf194406b`
- Upstream: `origin/master`, Ahead/Behind vor Commit `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `todo.state.json.active_id` ist `null`
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich noch offen ist.
- Supertest: vom Nutzer fuer diese Uebergabe als erledigt gesetzt; kein neuer Supertest-Lauf.

## Abgeschlossener Arbeitsschritt

- Eine weitere Website-Discovery-Welle fuer 25 Kandidaten aus der Kandidatenqueue ausgefuehrt.
- 1 Kandidat aus der offiziellen Quelle `stadt_muenchen_unternehmensbeteiligungen` hat eine offizielle Firmenwebsite erhalten.
- Kandidaten-Verifikationswelle fuer diesen Kandidaten ausgefuehrt.
- Der Kandidat wurde fail-closed als offizielle Karrierequelle verifiziert und produktiv in `data/jobagent/store.json` uebernommen.
- Coverage-JSON, Coverage-Markdown und `html/jobagent/company-coverage.html` wurden aktualisiert.
- `.\ci.cmd route-check` und `.\ci.cmd stp` wurden ausgefuehrt.

## Neu produktiv/verifiziert

- `company:lhm_services_gmbh`
  - Name: `LHM Services GmbH`
  - Status: `CAREER_URL_VERIFIED`
  - Website: `https://lhm-services.de/`
  - Karriere-URL: `https://lhm-services.de/jobs-karriere`
  - Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`

## Produktiver Datenstand

- Produktive Firmen: `45`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1832`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Queue-Cluster: `1787`
- Queue-Kandidaten: `1790`
- Verifizierte Queue-Eintraege: `13`
- Manual-Review-Queue-Eintraege: `1774`
- Verification-ready Queue-Eintraege: `0`
- Kandidaten-Review-Queue gesamt laut Coverage: `1775`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-151910.json`
- `logs/jobagent/company-candidate-verification-20260827-151942.json`
- `logs/jobagent/company-coverage-20260827-152001.json`
- `logs/jobagent/company-coverage-20260827-152001.md`
- `html/jobagent/company-coverage.html`

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgaben

1. Weitere kleine Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Danach verifizierbare Kandidaten importieren:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Falls Code geaendert wird, zuerst fokussierte Funktionstests laufen lassen; Supertest erst bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Hinweise

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register und GitHub-/OSM-Listen bleiben Discovery-Hints und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- `.\ci.cmd self-check` wurde in diesem Abschluss nicht neu ausgefuehrt; vorher bekannter Restfehler war `immutable_modified: Roadmap.md`.
