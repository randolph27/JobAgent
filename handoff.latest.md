# Handoff latest

Stand: 2026-08-27T19:05:28.106+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Repo: `https://github.com/randolph27/JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `5f54ca5ab777`
- Upstream: `origin/master`
- Ahead/Behind vor Abschlusscommit: `0/0`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`, Status `open`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 nicht komplett erledigt ist.
- Supertest: nicht neu ausgefuehrt; laut Nutzeranweisung gilt er als erledigt, wenn nicht explizit angefragt.
- Devserver: `http://localhost:8500/`, PID `23568`, listening `True`
- SonarQube: `http://localhost:9000/api/system/status`, Status `UP`, Version `26.1.0.118079`

## Abgeschlossener Arbeitsschritt

- Eine weitere Website-Discovery-Welle verarbeitet: `25` Kandidaten.
- Ergebnis der Discovery-Welle: `3` offizielle Website-Treffer, `22` Kandidaten fail-closed in `MANUAL_REVIEW_REQUIRED`.
- Kandidatenverifikation verarbeitet: `3` Kandidaten.
- Produktiv hinzugefuegt/beibehalten: `Glenmark Arzneimittel GmbH` mit offizieller Karrierequelle `https://glenmark.de/karriere`.
- Retry geplant: `Fujitsu Germany GmbH` wegen HTTP `429`/fehlendem Karriere- oder ATS-Beleg.
- Fail-closed bereinigt: `Google Deutschland` wurde aus dem Store entfernt, weil der vermeintliche Website-Beleg ein Suchmaschinen-Redirect `google.de/url` auf ein PDF war und keine offizielle Firmenwebsite.
- Code-Guard ergaenzt: Website-Discovery verwirft Suchmaschinen-Redirects und Dokumentdateien als offizielle Firmenwebsite-Kandidaten.
- Regressionstest ergaenzt: `search_redirect_rejected_for_website_discovery`.
- Coverage aktualisiert: `companies_total=68`, `job_sources_total=68`, `duplicate_groups=0`, `target_inventory_gate_status=failed`.

## Datenstand

- Produktive Firmen: `68`
- JobSources: `68`
- Glenmark vorhanden: `1`
- Google Deutschland vorhanden: `0`
- Kandidatenqueue: `1786` Cluster, `1790` Kandidaten
- Queue-Status: `0` Pending/Ready, `36` Verified, `1746` Manual Review, `4` Retry Scheduled
- Discovery-Hints: `1790`

## Geaenderte Dateien fuer Abschlusscommit

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

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-165744.json`
- `logs/jobagent/company-candidate-verification-20260827-165806.json`
- `logs/jobagent/company-coverage-20260827-170136.json`
- `logs/jobagent/company-coverage-20260827-170136.md`
- `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`; 25 Kandidaten verarbeitet; 3 offizielle Website-Treffer; 22 Manual Review
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`; 3 Kandidaten verarbeitet; Glenmark produktiv uebernommen; Fujitsu Retry; Google nach Redirector-Fund fail-closed bereinigt
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`; companies_total=68; duplicate_groups=0; target_inventory_gate_status=failed
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`; 24 Faelle bestanden inkl. search_redirect_rejected_for_website_discovery
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`; 28 Faelle bestanden
- `.\ci.cmd route-check` -> Exit `0`; route_ok=True
- `.\ci.cmd stp` -> Exit `0`; Todo/Handoff synchronisiert
- `.\ci.cmd supertest` -> Exit `0`; nicht neu ausgefuehrt; laut Nutzeranweisung als erledigt behandeln, wenn nicht explizit angefragt

## Naechste Aufgaben

1. Weitere Website-Discovery-Welle starten:
   `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8`
2. Wenn `verified_total > 0`, Kandidatenverifikation starten:
   `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3`
3. Danach Coverage aktualisieren:
   `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
4. Danach fokussierte Funktionstests ausfuehren:
   `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
   `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`
5. JA-027 erst rotieren, wenn alle Kandidaten verarbeitet sind oder jeder offene Rest einen belastbaren Review-/Reject-/Retry-Grund hat und alle Akzeptanzbedingungen belegt sind.

## Guardrails fuer den naechsten Agenten

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, GitHub-/OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Suchmaschinen-Redirects wie `google.de/url` und Dokumentdateien wie PDF/DOC/XLS/PPT duerfen keine offizielle Firmenwebsite verifizieren.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen/URLs/Job-IDs.
