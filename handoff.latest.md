# Handoff latest

Stand: 2026-08-27T07:18:55.051+02:00

## Aktiver Roadmap-/Todo-Stand

- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`.
- Offenes Todo: `TD-0041`; `todo.state.json.active_id` ist aktuell `null`, `todo.current.md` listet `TD-0041` als `open`.
- JA-027 ist nicht komplett erledigt und wurde deshalb nicht nach `Roadmap_archive.md` rotiert.
- Supertest gilt gemaess Nutzeranweisung als erledigt; in dieser Arbeitswelle wurden nur funktionsbezogene Tests ausgefuehrt.

## Umgesetzter Arbeitsschritt

- `src/JobAgent.SourceVerification.psm1` akzeptiert fuer Kandidaten ohne `known_company_domain` jetzt eine verifizierte `official_website_url` beziehungsweise `verified_official_website_url` als Domain-Ermittlungsbasis.
- Die neue Domain-Ermittlung ist fail-closed: unbelegte Website-URLs, ungueltige URLs und Aggregator-URLs erzeugen keine automatische Firmenstub-Erstellung.
- Verifizierte Website-URLs werden kanonisiert, `www.` wird entfernt, und `canonical_domain` wird aus dem finalen Website-Host abgeleitet.
- Bestehende Kandidaten mit `known_company_domain` behalten den bisherigen Pfad.
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` deckt jetzt ab:
  - verifizierte offizielle Website ohne `known_company_domain` wird zur Karriere-/Domainverifikation genutzt;
  - unbelegte `official_website_url` bleibt `MANUAL_REVIEW_REQUIRED`;
  - ungueltige `official_website_url` bleibt `MANUAL_REVIEW_REQUIRED`;
  - bestehende Karriere-, ATS-, Domain-only-, Timeout-, 404-, JS-only- und Aggregator-Faelle bleiben stabil.

## Aktualisierte Artefakte

- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.json`
- `handoff.latest.md`

## Validierung

Ausgefuehrt und erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
.\ci.cmd stp
```

SonarQube-Status vor der Arbeitswelle: `http://localhost:9000/api/system/status` lieferte `UP`.

Devserver-Status vor der Arbeitswelle: `.\ci.cmd devserver-status` meldete `http://localhost:8500/` als listening.

## Produktiver Datenstand

- Die Queue zaehlt weiterhin 1788 Cluster und 1790 Kandidaten.
- Statusverteilung nach der Arbeitswelle:
  - `VERIFIED`: 5
  - `MANUAL_REVIEW_REQUIRED`: 3
  - `PENDING`: 1780
- Es wurde keine neue Live-Verifikationswelle gegen echte Websites ausgefuehrt.
- Es wurden keine weiteren Firmen produktiv in `data/jobagent/store.json` uebernommen.

## Naechste konkrete Aufgaben

1. Domain-Ermittlungsstufe fuer Kandidaten ohne Domain weiter ausbauen: Kandidaten mit vorhandener, aber noch unbelegter Website-Quelle muessen zuerst offizielle Website-Evidenz erhalten, bevor `official_website_url` fuer den Upsert genutzt wird.
2. Quellen fuer die Website-Evidenz definieren und testen: zulaessig sind nur belegte offizielle Firmenwebsite-/Impressum-/Namens-/Standortsignale; Jobboersen, Register und regionale Verzeichnisse bleiben Discovery-Hints, keine Primaerbelege.
3. Danach kleine Verifikationswelle starten, nicht alle Kandidaten auf einmal:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3
```

4. Ergebnislog unter `logs/jobagent/company-candidate-verification-*.json` pruefen: produktive Upserts nur bei `COMPANY_DOMAIN_VERIFIED`, `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`; unklare Faelle muessen `MANUAL_REVIEW_REQUIRED`, `RETRY_SCHEDULED` oder `RETRY_EXHAUSTED` bleiben.
5. Coverage aktualisieren:

```powershell
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
```

6. Funktionsbezogene Tests erneut ausfuehren:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
```

7. JA-027 erst abschliessen und rotieren, wenn alle Akzeptanzbedingungen aus `Roadmap.md` belegt sind: offizielle Website-/Karriere-/ATS-Evidenz pro produktiv hinzugefuegter Firma, nicht uebernommene Kandidaten mit Review-/Reject-Grund, Coverage-/Report-Artefakte aktualisiert und Abschluss-Gates gruen.

## Bekannte Risiken

- Die neue Website-URL-Nutzung setzt voraus, dass vorgelagerte Ermittlung die Website wirklich als offiziell belegt. Ohne diese Evidenz bleibt der Pfad absichtlich gesperrt.
- Viele Kandidaten besitzen weiterhin keinen belastbaren Domain- oder Website-Hinweis und bleiben fail-closed.
- Die Coverage-Testausfuehrung hat Zeitstempel in `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html` aktualisiert.

## Git-Anker vor Commit

- Branch: `master`
- HEAD vor Commit: `4d49d553fa5d`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
