# Handoff latest

Stand: 2026-08-27T12:20:57+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`
- `Roadmap.md` wurde nicht rotiert, weil JA-027 fachlich noch nicht abgeschlossen ist.
- SonarQube war erreichbar: `http://localhost:9000/api/system/status` meldete `UP`.
- Devserver war erreichbar: `.\ci.cmd devserver-status` meldete `http://localhost:8500/` listening.
- Supertest wurde gemaess Nutzeranweisung nicht neu ausgefuehrt; er gilt fuer diese Uebergabe als erledigt.

## In dieser Arbeitswelle umgesetzt

- Neues Tool `tools/Discover-JobAgentCompanyCandidateWebsites.ps1` eingefuehrt.
- `src/JobAgent.SourceVerification.psm1` erweitert:
  - `Resolve-JobAgentCandidateOfficialWebsiteDiscovery`
  - Website-Linkextraktion aus zulaessigen Verzeichnisseiten
  - Namens-/Token-Matching fuer Kandidat zu Linktext/URL
  - fail-closed Ablehnung fuer Jobboersen, Aggregatoren, Namenskonflikte, fehlende Quell-URL und Mehrdeutigkeit
  - tolerantere URL-Kanonisierung fuer percent-encodierte externe Links
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` erweitert:
  - offizielles Verzeichnis verifiziert Firmenwebsite
  - Aggregator-Link wird fuer Website-Ermittlung abgelehnt
  - Namenskonflikt bleibt Manual Review
  - Jobboerse darf kein Website-Beleg sein
  - Tool aktualisiert Hint-Store und Queue
- Kleine Live-Welle ausgefuehrt:
  - Website-Ermittlung fand `aquabench GmbH` ueber die offizielle Muenchner Beteiligungsseite.
  - Danach wurde die offizielle Karriere-URL verifiziert.
  - `aquabench GmbH` wurde produktiv in `data/jobagent/store.json` aufgenommen.

## Aktueller Datenstand

- Produktive Firmen: `39`
- Neu produktiv:
  - `company:aquabench_gmbh`
  - Website: `https://aquabench.de/`
  - Karriere-URL: `https://aquabench.de/karriere.html`
  - Website-Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
  - Karriere-Beleg: `https://aquabench.de/`
- Queue:
  - `VERIFY_OFFICIAL_SITE` + `VERIFIED`: 6
  - `DISCOVER_OFFICIAL_WEBSITE` + `MANUAL_REVIEW_REQUIRED`: 1779
  - `MANUAL_DECISION` + `MANUAL_REVIEW_REQUIRED`: 1
  - `REJECT_DUPLICATE` + `MANUAL_REVIEW_REQUIRED`: 2
- Coverage:
  - `target_inventory_candidates_total`: 1827
  - `target_inventory_gap_to_1000`: 0
  - `target_inventory_gate_status`: `failed`, weil noch Review-/Verifikationsbedingungen offen sind
  - `duplicate_groups`: 0

## Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-101509.json`
- `logs/jobagent/company-candidate-website-discovery-20260827-101653.json`
- `logs/jobagent/company-candidate-verification-20260827-101713.json`
- `logs/jobagent/company-coverage-20260827-101727.json`
- `logs/jobagent/company-coverage-20260827-101727.md`
- `html/jobagent/company-coverage.html`

## Validierung

Erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 5 -TimeoutSeconds 2
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 5 -TimeoutSeconds 8 -MaxRetries 3
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
.\ci.cmd stp
```

## Geaenderte Dateien

- `Roadmap.md`
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
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`

## Naechste konkrete Aufgaben

1. `Discover-JobAgentCompanyCandidateWebsites.ps1` fuer weitere Quellmuster ausbauen.
   - Naechste sinnvolle Quellen: strukturierte Regionalverzeichnisse mit externen Firmenlinks und Detailseiten.
   - Ziel: mehr Kandidaten aus `DISCOVER_OFFICIAL_WEBSITE` nach `VERIFY_OFFICIAL_SITE` ueberfuehren.
   - No-Go: keine Suchmaschinen-Ergebnisse, keine Jobboersen-/Arbeitsagentur-URLs als offizieller Firmenbeleg.

2. Mehrdeutige Quellen besser klassifizieren.
   - Aktuell bleiben Seiten mit mehreren moeglichen Trefferlinks fail-closed.
   - Sinnvoller naechster Schritt: pro Kandidat Detailseiten-URL aus dem Verzeichnis extrahieren und nur diese Detailseite auswerten.

3. Danach kleine Welle erneut laufen lassen.

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 10 -TimeoutSeconds 8
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
```

4. JA-027 erst rotieren, wenn alle Akzeptanzbedingungen belegt sind.
   - Alle produktiv aufgenommenen Firmen haben offizielle Website-/Karriere-/ATS-Evidenz.
   - Nicht uebernommene Kandidaten haben Review-/Reject-Grund.
   - Coverage-/Report-Artefakte sind aktuell.
   - Funktionstests sind gruen.
   - Supertest gilt durch Nutzerfreigabe oder wurde explizit ausgefuehrt.
