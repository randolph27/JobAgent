# Handoff latest

Stand: 2026-08-27T18:38:31+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `70c6fffdcc5b`
- Upstream: `origin/master`
- Ahead/Behind vor Abschlusscommit: `0/0`
- Worktree vor Abschlusscommit: `dirty`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; nach Nutzeranweisung vom 2026-08-27 gilt Supertest als erledigt, wenn er nicht explizit angefragt wurde.
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- `.\ci.cmd stp` ausgefuehrt.
- Eine Website-Discovery-Welle verarbeitet: `25` Kandidaten.
- Ergebnis der Welle: `1` offizielle Website verifiziert, `24` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Verifizierter Kandidat: `regional-hint:munich_business_indian_companies_cipla_deutschland_muenchen`
- Produktiver Store-Upsert: `company:cipla_deutschland`
- Verifikationsstatus: `COMPANY_DOMAIN_VERIFIED`
- Offizielle Website: `https://cipla.com/`
- Karriere-/ATS-Quelle: keine belegt; Firma wurde ohne JobSource aufgenommen.
- Coverage erneut erzeugt und `html/jobagent/company-coverage.html` aktualisiert.

## Datenstand

- Produktive Firmen: `65`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1851`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Offizielle Quellen: `68`
- Discovery-Quellen: `1820`
- Queue: `0` Pending, `1751` Manual Review, `2` Retry geplant, `33` Verified.

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-163434.json`
- `logs/jobagent/company-candidate-verification-20260827-163454.json`
- `logs/jobagent/company-coverage-20260827-163514.json`
- `logs/jobagent/company-coverage-20260827-163514.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `1`, Issues: `immutable_modified: Roadmap.md` plus Handoff-Invarianten vor STP-Sync. Nicht repariert, weil das eine separate Integritaets-/Pin-Entscheidung ist.

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
