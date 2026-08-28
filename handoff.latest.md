# Handoff latest

Stand: 2026-08-28T07:16:42.864+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD vor Commit: `b8cbf09daea5`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`, `active_id=null`
- Roadmap-Rotation: nicht ausfuehren; JA-027 ist noch nicht komplett erledigt.
- Supertest: nicht neu angefragt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- Devserver: `http://localhost:8500/`, zuletzt `listening=True`
- SonarQube: `http://localhost:9000/api/system/status`, zuletzt `UP`, Version `26.1.0.118079`

## Letzter abgeschlossener Arbeitsschritt

- Eine weitere Website-Discovery-Welle fuer JA-027 verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `2` offizielle Website-Treffer, `23` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Website-verifizierte Kandidaten:
  - `regional-hint:munich_business_indian_companies_tata_consultancy_services_deutschland_gmbh_muenchen` -> offizielle Website `https://tcs.com/`
  - `regional-hint:munich_business_japanese_companies_tdk_electronics_ag_muenchen` -> offizielle Website `https://tdk-electronics.tdk.com/`
- Kandidatenverifikation danach ausgefuehrt: `2` Kandidaten.
- Produktiv hinzugefuegte Firma in diesem Schritt: `TDK Electronics AG`, `company:tdk_electronics_ag`, Karriere-URL `https://tdk-electronics.tdk.com/en/2302050/careers`, Status `CAREER_URL_VERIFIED`.
- Nicht produktiv hinzugefuegt: `Tata Consultancy Services Deutschland GmbH`; offizielle Website antwortete beim Karriere-/Sitemap-Check mit `403`, daher fail-closed `UNVERIFIED` und `RETRY_SCHEDULED` fuer `2026-08-29T05:13:11.337Z`.
- Store wurde aktualisiert und mit Backup geschrieben.

## Datenstand nach Coverage

- Produktive Firmen: `82`
- Backlog-Items: `82`
- Candidate-Hints: `1790`
- Kandidatenqueue: `1785` Cluster
- Queue ready: `8`
- Queue verified total: `50`
- Queue manual review total: `1727`
- Queue retry scheduled: `1`
- Queue retry exhausted: `0`
- Target-Inventory-Kandidaten: `1867`
- Source Inventory: `1901` Quellen, davon `81` offizielle Quellen und `1820` Discovery-Quellen
- Target-Inventory-Gate: `failed`
- Duplicate Groups: `0`
- Import Waves: `4`

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

- `logs/jobagent/company-candidate-website-discovery-20260828-051250.json`
- `logs/jobagent/company-candidate-verification-20260828-051311.json`
- `logs/jobagent/company-coverage-20260828-051344.json`
- `logs/jobagent/company-coverage-20260828-051344.md`
- `html/jobagent/company-coverage.html`
- `logs/terminal/route-check-20260828-071449.log`

## Verifikation

- `curl.exe -s http://localhost:9000/api/system/status` -> Exit `0`; Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`; Port `8500` listening `True`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 2 offizielle Website-Treffer; 23 Manual Review
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`; 2 Kandidaten verarbeitet; 1 produktiver Upsert erlaubt; 1 Retry deferred
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=82; target_inventory_gate_status=failed
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=True
- `.\ci.cmd stp` -> Exit `0`; Todo/Handoff synchronisiert
- `.\ci.cmd supertest` wurde nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt.

## Naechste Aufgaben

1. Weiter mit JA-027: naechste Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidatenverifikation starten:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Danach Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren:
   `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
   `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. Danach `.\ci.cmd route-check` und `.\ci.cmd stp` ausfuehren.
6. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
