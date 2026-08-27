# Handoff latest

Stand: 2026-08-27T12:05:00+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschlusscommit: `4939fbe0246a`
- Upstream: `origin/master`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`
- `Roadmap.md` wurde nicht rotiert, weil JA-027 fachlich noch nicht abgeschlossen ist.
- SonarQube war erreichbar: `http://localhost:9000/api/system/status` meldete `UP`.
- Devserver war erreichbar: `.\ci.cmd devserver-status` meldete `http://localhost:8500/` listening.

## In dieser Arbeitswelle umgesetzt

- Die Kandidaten-Verifikationsqueue wurde fail-closed nach Aktionsfaehigkeit getrennt.
- `src/JobAgent.Coverage.psm1` erzeugt fuer Kandidaten ohne `known_company_domain`/`canonical_domain` und ohne Website jetzt `DISCOVER_OFFICIAL_WEBSITE`.
- Kandidaten mit `official_website_url`, aber ohne belegte Website-Evidenz, bekommen `VERIFY_OFFICIAL_WEBSITE_EVIDENCE` und bleiben `MANUAL_REVIEW_REQUIRED`.
- Nur Kandidaten mit belastbarer Domain bleiben `PENDING` + `VERIFY_OFFICIAL_SITE`.
- `tools/Verify-JobAgentCompanyCandidates.ps1` verarbeitet nur noch `PENDING` + `VERIFY_OFFICIAL_SITE`; nicht-aktionable Manual-Review-Kandidaten werden nicht mehr live gegen Websites geprueft.
- `tests/Test-JobAgentCoverage.ps1` prueft die drei Queue-Pfade `VERIFY_OFFICIAL_SITE`, `VERIFY_OFFICIAL_WEBSITE_EVIDENCE`, `DISCOVER_OFFICIAL_WEBSITE`.
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` prueft, dass Manual-Review-Kandidaten ohne Aktionsfaehigkeit nicht vom Script als verarbeitet gezaehlt werden.

## Aktueller Datenstand

- `data/jobagent/store.json`: weiterhin 38 produktive Firmen.
- Es wurden in dieser Arbeitswelle keine neuen Firmen produktiv upserted.
- Letzte kleine Live-Verifikationswelle:
  - Command: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3`
  - Log: `logs/jobagent/company-candidate-verification-20260827-100236.json`
  - Ergebnis: `processed_total=0`, `ready_total=0`, keine produktiven Upserts.
- Letzte Coverage:
  - Command: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`
  - JSON: `logs/jobagent/company-coverage-20260827-100236.json`
  - Markdown: `logs/jobagent/company-coverage-20260827-100236.md`
  - HTML: `html/jobagent/company-coverage.html`

## Queue-Stand nach der Aenderung

- Cluster: 1788
- Kandidaten: 1790
- `ready_total`: 0
- Status:
  - `MANUAL_REVIEW_REQUIRED`: 1783
  - `VERIFIED`: 5
- Aktionen:
  - `DISCOVER_OFFICIAL_WEBSITE`: 1780
  - `MANUAL_DECISION`: 1
  - `REJECT_DUPLICATE`: 2
  - `VERIFY_OFFICIAL_SITE`: 5

## Validierung

Erfolgreich ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
.\ci.cmd stp
```

Supertest wurde in dieser Arbeitswelle nicht neu ausgefuehrt. Laut Nutzeranweisung gilt er, wenn nicht explizit angefragt, als erledigt.

## Naechste konkrete Aufgaben

1. Offizielle Website-Ermittlung fuer `DISCOVER_OFFICIAL_WEBSITE` implementieren.
   - Ziel: Kandidaten ohne Domain/Website bekommen nur dann `official_website_url`, wenn eine zulaessige Evidenzquelle den Firmenbezug belegt.
   - Betroffene Stellen voraussichtlich: `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.Coverage.psm1`, neues oder erweitertes Tool unter `tools/`.
   - No-Go: keine Suchmaschinen- oder Jobboersen-URL als offizieller Beleg, keine globale ATS-Allowlist ohne Firmenlink.

2. Website-Evidenzmodell fuer Kandidaten festziehen.
   - Benoetigt werden Felder wie `official_website_evidence`, `official_website_verification_status`, `verification_url`, `verified_by_url`, `evidence_type`, `observed_at`, Hash/Excerpt.
   - Akzeptierte Status fuer automatische Weiterverarbeitung bleiben nur `VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `OFFICIAL_WEBSITE_VERIFIED`.

3. Kleine Fixture-Tests fuer Website-Ermittlung bauen.
   - Faelle: offizielle Firmenwebsite belegt, unbelegte Website abgelehnt, Aggregator abgelehnt, Namenskonflikt fail-closed, Standort unsicher fail-closed.
   - Funktionstests vor Supertest.

4. Danach kleine Verifikationswelle erneut starten.
   - Erst wenn einzelne Kandidaten aus `DISCOVER_OFFICIAL_WEBSITE` in `VERIFY_OFFICIAL_SITE` ueberfuehrt wurden:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3
```

5. Coverage aktualisieren und HTML pruefen.

```powershell
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
```

6. JA-027 erst rotieren, wenn alle Akzeptanzbedingungen belegt sind:
   - produktive Firmen haben offizielle Website-/Karriere-/ATS-Evidenz,
   - nicht uebernommene Kandidaten haben Review-/Reject-Grund,
   - Coverage-/Report-Artefakte sind aktuell,
   - funktionsbezogene Tests sind gruen,
   - Supertest gilt gemaess Nutzerfreigabe oder wurde explizit ausgefuehrt.

## Geaenderte Dateien vor Commit

- `data/jobagent/company-candidate-verification.queue.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.Coverage.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `tests/Test-JobAgentCoverage.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
