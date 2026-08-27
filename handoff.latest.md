# Handoff latest

Stand: 2026-08-27T18:44:23.278+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `286ab9325bf8`
- Upstream: `origin/master`
- Ahead/Behind vor Abschlusscommit: `0/0`
- Worktree vor Abschlusscommit: `dirty`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt, wenn nicht explizit angefragt.
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- `.\ci.cmd stp` ausgefuehrt.
- Eine weitere Website-Discovery-Welle verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `3` offizielle Websites verifiziert, `22` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Verifizierte Discovery-Kandidaten:
  - `regional-hint:munich_business_japanese_companies_daiichi_sankyo_europe_gmbh_muenchen`
  - `regional-hint:munich_business_japanese_companies_denso_automotive_deutschland_gmbh_muenchen`
  - `regional-hint:munich_business_japanese_companies_dmg_mori_emea_holding_gmbh_muenchen`
- Verifikations-/Importwelle verarbeitet: `3` Kandidaten.
- Produktive Store-Upserts:
  - `company:daiichi_sankyo_europe_gmbh`, Status `CAREER_URL_VERIFIED`, offizielle Website `https://daiichi-sankyo.de/`, Karrierequelle `https://daiichi-sankyo.de/karriere`
  - `company:dmg_mori_emea_holding_gmbh`, Status `COMPANY_DOMAIN_VERIFIED`, offizielle Website `https://de.dmgmori.com/`, keine belegte Karriere-/ATS-Quelle
- Nicht importiert: `company:denso_automotive_deutschland_gmbh`, Status `RETRY_SCHEDULED`, Grund: kein offiziell belegter Karriere- oder ATS-Link gefunden; naechster Versuch `2026-08-28T16:42:02.020Z`.
- Coverage erneut erzeugt und `html/jobagent/company-coverage.html` aktualisiert.

## Datenstand

- Produktive Firmen: `67`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1853`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.
- Quellen gesamt: `1889`
- Offizielle Quellen: `69`
- Karrierequellen: `68`
- ATS-Quellen: `1`
- Discovery-Hinweise: `1820`
- Queue laut aktualisierter Verifikationsqueue: `1786` Cluster, `1790` Kandidaten, `1748` Manual Review, `35` Verified, `3` Retry geplant, `0` Ready.

## Geaenderte Dateien fuer Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-164140.json`
- `logs/jobagent/company-candidate-verification-20260827-164202.json`
- `logs/jobagent/company-coverage-20260827-164215.json`
- `logs/jobagent/company-coverage-20260827-164215.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> nicht neu ausgefuehrt; laut aktueller Nutzeranweisung als erledigt zu behandeln, wenn nicht explizit angefragt.

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten: `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Verifikation/Import ausfuehren: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren: `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell gibt es keine Ready-Queue-Eintraege; zuerst wieder Website-Discovery laufen lassen.
