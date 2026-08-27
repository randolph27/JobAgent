# Handoff latest

Stand: 2026-08-27T19:44:45.030+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Commit: `cdbaef6db206`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- Devserver zuletzt geprueft: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube zuletzt geprueft: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Weitere Website-Discovery-Welle fuer JA-027 verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `3` offizielle Website-Treffer, `22` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Kandidatenverifikation ausgefuehrt, weil `verified_total=3`.
- Produktiv hinzugefuegt: `2` Firmen.
- Retry geplant: `1` Kandidat (`LTM`, `next_attempt_at=2026-08-28T17:41:16.488Z`), weil kein offiziell belegter Karriere- oder ATS-Link gefunden wurde.
- Neu in `data/jobagent/store.json`:
  - `KPIT Technologies GmbH`, `company:kpit_technologies_gmbh`, offizielle Website `https://kpit.com/`, Karriere-URL `https://kpit.com/careers-overview`, Status `CAREER_URL_VERIFIED`, JobSource `source:kpit_technologies_gmbh_career_url`.
  - `Larsen & Toubro Limited`, `company:larsen_and_toubro_limited`, offizielle Website `https://larsentoubro.com/`, Karriere-URL `https://larsentoubro.com/careers`, Status `CAREER_URL_VERIFIED`, JobSource `source:larsen_and_toubro_limited_career_url`.
- Coverage aktualisiert: `companies_total=73`, `sources_total=1894`, `official_sources=74`, `discovery_sources=1820`, `duplicate_groups=0`, `target_inventory_gate_status=failed`.
- STP ausgefuehrt: Todo-/Handoff-Artefakte synchronisiert; Route-Check war gruen.

## Datenstand

- Produktive Firmen: `73`
- Kandidatenqueue: `1786` Cluster, `1790` Kandidaten
- Queue ready: `0`
- Queue verarbeitet in letzter Verifikation: `3`
- Queue verified total: `41`
- Queue retry scheduled total: `5`
- Queue manual review total: `1740`
- Source Inventory: `1894` Quellen, davon `74` offizielle Quellen und `1820` Discovery-Quellen
- Target-Inventory-Gate: `failed`

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

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-174055.json`
- `logs/jobagent/company-candidate-verification-20260827-174116.json`
- `logs/jobagent/company-coverage-20260827-174138.json`
- `logs/jobagent/company-coverage-20260827-174138.md`
- `logs/terminal/route-check-20260827-194249.log`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 3 offizielle Website-Treffer; 22 Manual Review
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`; 3 Kandidaten verarbeitet; 2 produktive Upserts erlaubt; 1 Retry geplant
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=73; sources_total=1894; target_inventory_gate_status=failed
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
