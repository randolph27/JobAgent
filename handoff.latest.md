# Handoff latest

Stand: 2026-08-27T17:46:41.009+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Commit: `80952d156465`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`, ausschliesslich JA-027-Daten-/Todo-/Handoff-Aenderungen aus der letzten Discovery-Welle
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `todo.state.json.active_id` ist `null`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich weiter offen ist.
- Supertest: nicht neu ausgefuehrt; Nutzeranweisung vom 2026-08-27: "wenn supertest nicht angefragt wurde, gilt er als erledigt."
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- Eine weitere JA-027-Discovery-Welle fuer 25 Kandidaten aus der Kandidatenqueue ausgefuehrt.
- Ergebnis Discovery: 0 Kandidaten erhielten eine offiziell verifizierte Firmenwebsite.
- Alle 25 verarbeiteten Kandidaten wurden fail-closed in `MANUAL_REVIEW_REQUIRED` belassen.
- Kandidatenverifikation anschliessend ausgefuehrt; es gab keine `ready_total`-Kandidaten, daher wurden 0 Kandidaten produktiv importiert.
- Coverage-JSON, Coverage-Markdown und `html/jobagent/company-coverage.html` wurden aktualisiert.
- `.\ci.cmd route-check` und `.\ci.cmd stp` wurden ausgefuehrt.

## Datenstand nach der Welle

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
- Quellen gesamt: `1871`
- Offizielle Quellen: `51`
- Discovery-Quellen: `1820`

## Wichtige fachliche Beobachtung

- Die verarbeiteten Kandidaten hatten entweder keine zulaessige absolute Quell-URL fuer automatische Website-Ermittlung oder keine eindeutig namenspassende Firmenwebsite auf der offiziellen Quellseite.
- Wiederholtes Muster: regionale oder oeffentliche Uebersichtsseiten nennen grosse Arbeitgeber, enthalten aber keinen eindeutig automatisierbaren Firmenwebsite-Beleg nach aktuellem Fail-Closed-Policy-Vertrag.
- Beispiel `stadt_muenchen_unternehmensbeteiligungen_mgh_muenchener_gewerbehof_und_technologiegesellschaft_muenchen`: Es wurden mehrere moegliche URLs auf `mgh-muc.de` erkannt; automatische Auswahl blieb korrekt fail-closed, weil mehrere Treffer nicht eindeutig genug sind.
- `Verify-JobAgentCompanyCandidates.ps1` fand weiterhin keine verifikationsbereiten Kandidaten; der naechste Agent sollte daher zuerst weitere Website-Discovery laufen lassen oder gezielt die Manual-Review-Faelle fachlich verbessern.

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-154249.json`
- `logs/jobagent/company-candidate-verification-20260827-154314.json`
- `logs/jobagent/company-coverage-20260827-154325.json`
- `logs/jobagent/company-coverage-20260827-154325.md`
- `html/jobagent/company-coverage.html`
- `logs/terminal/route-check-20260827-174634.log`

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
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
2. Falls `verified_total > 0` oder `ready_total > 0`, danach verifizierbare Kandidaten importieren:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Bei Codeaenderungen zuerst fokussierte Funktionstests ausfuehren; Supertest nur bei Roadmap-Abschluss oder expliziter Anforderung.
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell gibt es keine verification-ready Queue-Eintraege; zuerst wieder Website-Discovery oder gezielte Verbesserung der Review-Faelle.
