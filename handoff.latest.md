# Handoff latest

Stand: 2026-08-27T18:50:23.234+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `2399e531b8c9`
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

- `.\ci.cmd stp` wurde ausgefuehrt.
- Eine weitere Website-Discovery-Welle verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `0` offizielle Websites verifiziert, `25` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Es wurde keine Verifikations-/Importwelle ausgefuehrt, weil `verified_total = 0`.
- Coverage wurde erneut erzeugt und `html/jobagent/company-coverage.html` aktualisiert.

## Letzte Discovery-Welle

- Log: `logs/jobagent/company-candidate-website-discovery-20260827-164818.json`
- Verarbeitete Kandidaten: `25`
- Verifizierte Kandidaten: `0`
- Manual Review: `25`
- Unverified: `0`
- Typische Gruende:
  - `Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.`
  - `Keine eindeutig namenspassende Firmenwebsite auf der offiziellen Quellseite gefunden.`
- Wichtige Folge: keine produktiven Store-Upserts, keine neuen Firmen, keine neuen offiziellen Karriere-/ATS-Quellen.

## Datenstand nach Coverage

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
- Kandidatenqueue: `1786` Cluster, `1790` Kandidaten.
- Queue-Status laut Coverage: `3` Ready, `35` Verified, `1748` Manual Review, `0` Retry exhausted.
- Inventory-State laut Coverage: `25` Manual Review, `34` Never Scanned, `1` Retry Required, `2` Stale Scan, `5` Verified Website Only.

## Geaenderte Dateien fuer Abschlusscommit

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-164818.json`
- `logs/jobagent/company-coverage-20260827-164841.json`
- `logs/jobagent/company-coverage-20260827-164841.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> nicht neu ausgefuehrt; laut Nutzeranweisung als erledigt zu behandeln, wenn nicht explizit angefragt.

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Verifikation/Import starten:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren:
   `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
   `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
- Aktuell wurden in der letzten Welle keine Kandidaten verifiziert; zuerst wieder Website-Discovery laufen lassen.
