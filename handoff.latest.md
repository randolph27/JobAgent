# Handoff latest

Stand: 2026-08-27T17:27:13.425+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `f3d673c13ccb`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `todo.state.json.active_id` ist `null`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: nicht neu ausgefuehrt; Nutzeranweisung vom 2026-08-27: "wenn supertest nicht angefragt wurde, gilt er als erledigt."
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- Eine weitere JA-027-Discovery-Welle fuer 25 Kandidaten aus der Kandidatenqueue ausgefuehrt.
- Ergebnis Discovery: 1 Kandidat erhielt eine offizielle Firmenwebsite; 24 Kandidaten wurden fail-closed in Manual Review belassen.
- Der verifizierbare Kandidat wurde anschliessend mit offizieller Karrierequelle geprueft.
- Der Kandidat wurde produktiv in `data/jobagent/store.json` uebernommen.
- Coverage-JSON, Coverage-Markdown und `html/jobagent/company-coverage.html` wurden aktualisiert.
- `./ci.cmd route-check` und `./ci.cmd stp` wurden ausgefuehrt.

## Neu produktiv/verifiziert

- `company:messe_muenchen_gmbh`
  - Name: `Messe Muenchen GmbH`
  - Status: `CAREER_URL_VERIFIED`
  - Website: `https://messe-muenchen.de/`
  - Karriere-URL: `https://messe-muenchen.de/de/karriere`
  - Offizielle Discovery-Quelle: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
  - Discovery-Kandidat: `regional-hint:stadt_muenchen_unternehmensbeteiligungen_messe_muenchen_gmbh_muenchen`
  - Entscheidung: `PRODUCTIVE_UPSERT_ALLOWED`
  - Begruendung: Karriere-URL liegt auf offizieller Firmendomain und wurde per Link/HTTP belegt.

## Produktiver Datenstand

- Produktive Firmen: `46`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1833`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Queue-Cluster: `1787`
- Queue-Kandidaten: `1790`
- Verifizierte Queue-Eintraege: `14`
- Manual-Review-Queue-Eintraege: `1773`
- Verification-ready Queue-Eintraege: `0`
- Kandidaten-Review-Queue gesamt laut Coverage: `1775`
- Quellen gesamt: `1871`
- Offizielle Quellen: `51`
- Discovery-Quellen: `1820`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-152524.json`
- `logs/jobagent/company-candidate-verification-20260827-152553.json`
- `logs/jobagent/company-coverage-20260827-152606.json`
- `logs/jobagent/company-coverage-20260827-152606.md`
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
2. Danach nur verifizierbare Kandidaten importieren:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Bei Codeaenderungen fokussierte Funktionstests zuerst ausfuehren; Supertest nur bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Hinweise

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Aktuell gibt es keine verification-ready Queue-Eintraege; der naechste Agent sollte zuerst wieder Website-Discovery laufen lassen.
- `.\ci.cmd self-check` wurde in diesem Abschluss nicht neu ausgefuehrt; frueher bekannter Restfehler war `immutable_modified: Roadmap.md`.
