# Handoff latest

Stand: 2026-08-27T19:59:42.279+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Commit: `bcf32d054911`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Zwei weitere Website-Discovery-Wellen fuer JA-027 verarbeitet: insgesamt `50` Kandidaten.
- Ergebnis der Discovery-Wellen: `5` offizielle Website-Treffer, `45` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Kandidatenverifikation ausgefuehrt, weil `verified_total > 0`.
- Produktiv hinzugefuegt: `4` Firmen.
- Nicht produktiv hinzugefuegt: `Olympus Europa GmbH`, weil keine offiziell belegte Karriere- oder ATS-Quelle gefunden wurde; Retry geplant fuer `2026-08-28T17:56:18.170Z`.

## Neu in `data/jobagent/store.json`

- `NTT Data Deutschland SE`, `company:ntt_data_deutschland_se`
  - Offizielle Website: `https://de.nttdata.com/`
  - Karriere-URL: `https://de.nttdata.com/karriere`
  - Status: `CAREER_URL_VERIFIED`
- `Panacea Biotec GmbH`, `company:panacea_biotec_gmbh`
  - Offizielle Website: `https://panacea-biotec.com/`
  - Karriere-URL: `https://panacea-biotec.com/en/career`
  - Status: `CAREER_URL_VERIFIED`
- `Panasonic Industry Europe GmbH`, `company:panasonic_industry_europe_gmbh`
  - Offizielle Website: `https://industry.panasonic.eu/`
  - Karriere-URL: `https://industry.panasonic.eu/careers`
  - Status: `CAREER_URL_VERIFIED`
- `PININFARINA Deutschland GmbH`, `company:pininfarina_deutschland_gmbh`
  - Offizielle Website: `https://pininfarina.de/`
  - Karriere-URL: `https://pininfarina.de/careers`
  - Status: `CAREER_URL_VERIFIED`

## Datenstand

- Produktive Firmen: `79`
- Kandidatenqueue: `1786` Cluster, `1790` Kandidaten
- Queue ready: `0`
- Queue verarbeitet in letzter Verifikation: `3`
- Queue verified total: `47`
- Queue retry scheduled total: `6`
- Queue manual review total: `1733`
- Source Inventory: `1898` Quellen, davon `78` offizielle Quellen und `1820` Discovery-Quellen
- Target-Inventory-Gate: `failed`
- Duplicate Groups: `0`

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

- `logs/jobagent/company-candidate-website-discovery-20260827-175555.json`
- `logs/jobagent/company-candidate-verification-20260827-175618.json`
- `logs/jobagent/company-coverage-20260827-175636.json`
- `logs/jobagent/company-coverage-20260827-175636.md`
- `logs/jobagent/company-candidate-website-discovery-20260827-175732.json`
- `logs/jobagent/company-candidate-verification-20260827-175752.json`
- `logs/jobagent/company-coverage-20260827-175810.json`
- `logs/jobagent/company-coverage-20260827-175810.md`
- `logs/terminal/route-check-20260827-195907.log`

## Verifikation

- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `0`; Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`; Port `8500` listening `True`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 2 offizielle Website-Treffer; 23 Manual Review
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`; 2 Kandidaten verarbeitet; 1 produktiver Upsert erlaubt; 1 Retry
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=76; target_inventory_gate_status=failed
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 3 offizielle Website-Treffer; 22 Manual Review
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`; 3 Kandidaten verarbeitet; 3 produktive Upserts erlaubt
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=79; target_inventory_gate_status=failed
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
