# Handoff latest

Stand: 2026-08-17T15:56:15+02:00

## Status

- Projekt: JobAgent
- Branch: `master`
- HEAD vor STP-Commit: `00043b6`
- Upstream: `origin/master`
- Active: _(none)_
- Status: `open`
- Abgeschlossen und rotiert: JA-014 / TD-0012
- Offener Roadmap-/Todo-Anker: TD-0013 / JA-015

## Erledigter Stand

JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll ist vollständig umgesetzt, validiert, archiviert und im Commit `00043b6 Complete JA-014 live pilot` enthalten.

Wichtig: Der Live-Pilot ist bewusst eine getrennte Lane und kein deterministischer Supertest-Bestandteil. Der Supertest bleibt mock-/fixture-basiert.

## Umgesetzte Dateien/Funktionen

- `src/JobAgent.LiveScan.psm1`
  - Live-Scan-Policy mit `timeout_seconds`, `max_retries`, `max_companies`, `max_results_per_source`, `max_detail_fetches_per_source` und User-Agent.
  - Offizielle Quellenbindung: Aggregatoren/Jobbörsen werden als Primärquelle abgelehnt.
  - Karrierequellenabruf über `Invoke-WebRequest` mit Timeout, User-Agent und Retry-Protokoll.
  - Kandidatenfilter aus offiziellen Karrierequellen.
  - Detailseitenabruf als Voraussetzung für RawJob-Erzeugung.
  - Live-Pilot-Zusammenfassung mit `official_detail_pages_checked` und `verified_matching_jobs`.

- `tools/Invoke-JobAgentLivePilot.ps1`
  - CLI für begrenzte Live-Pilot-Läufe.
  - Nutzt den bestehenden Daily-Run-Orchestrator und Betriebswrapper.
  - Schreibt `logs/jobagent/live-pilot-<date>.json`, Daily-Run-JSON, Markdown-Report, Statusdatei und Run-Log.

- `tests/Test-JobAgentLiveScan.ps1`
  - Deterministischer Funktionstest ohne Live-Webzugriff.
  - Deckt Policy-Limits, offizielle Kandidatenfilterung, Aggregator-Ausschluss, Detailseitenverifikation, `NO_JOBS_FOUND` und Retry-Versuchslogs ab.

- `src/JobAgent.DailyRun.psm1`
  - Leere Adapterresultate werden sauber verarbeitet.
  - `companies_scanned` und `company_ids` sind auch bei leeren Arrays robust.

- `src/JobAgent.StatusMachine.psm1`
  - `Invoke-JobAgentStatusMachine` akzeptiert leere Adapterresultate.

- `src/JobAgent.SourceAdapters.psm1`
  - `http_status` darf bei nicht verfügbarer HTTP-Antwort `null` bleiben.

- `.ci/bin/modules/core-utils.ps1`
  - atomarer CI-Write-Fallback überschreibt vorhandene Zieldateien robust; `devserver-status` funktioniert wieder.

- `docs/test-matrix.json`, `docs/test-matrix.md`, `tests/Test-JobAgentTestMatrix.ps1`
  - JA-014 ist dokumentiert als `separate-live-pilot`, `include_in_supertest=false`.

- `Roadmap.md`, `Roadmap_archive.md`, `Roadmap_index.md`, `todo.*`
  - JA-014 wurde aus der aktiven Roadmap entfernt und archiviert.
  - TD-0012 ist erledigt.
  - TD-0013 ist der einzige offene aktuelle Todo.

## Live-Pilot-Evidence

Ausgeführter Live-Pilot:

```powershell
pwsh -NoProfile -Command "& .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -CompanyIds @('company:siemens_ag','company:stadtwerke_muenchen_gmbh') -MaxCompanies 2 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 5 -MaxDetailFetchesPerSource 2"
```

Ergebnis:

- Status: `SUCCESS`
- ScanRun: `scanrun:20260817T134912490Z`
- Firmen: `company:siemens_ag`, `company:stadtwerke_muenchen_gmbh`
- Adapterversuche: 2
- Offizielle Detailseiten geprüft: 3
- Technische Fehler: 0
- `verified_matching_jobs`: 0

Interpretation:

- Es wurden offizielle Seiten geprüft, aber keine geprüfte Seite wurde als passende IT-Führungsrolle (`MATCH` oder `POSSIBLE`) klassifiziert.
- Es wurden keine Stellen erfunden und keine unklaren Treffer als passend ausgegeben.

Artefakte:

- `logs/jobagent/live-pilot-20260817.json`
- `logs/jobagent/daily-run-20260817T134912490Z.json`
- `logs/jobagent/daily-run-20260817T134912490Z.md`

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd runtime-update` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `.\ci.cmd devserver-status` -> Exit 0, `port=8300`, `listening=True`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> `UP`
- `.\ci.cmd stp` -> Exit 0

## Nächste Aufgabe

TD-0013 / JA-015 Kontinuierliche Firmenabdeckung und Adapter-Erweiterung priorisieren.

Fachlicher Einstieg:

1. Coverage-Metriken aus `data/jobagent/store.json` ableiten:
   - Firmen gesamt
   - Firmen mit/ohne Karriere-URL
   - erfolgreich gescannt
   - fehlerhaft gescannt
   - ohne passende Stellen
   - mit passenden Stellen
   - seit X Tagen ungeprüft

2. Adapter-/Portal-Backlog aus Live-Pilot-Befunden erzeugen:
   - Dynamische ATS-/Karriereseiten getrennt erfassen.
   - Generische Navigationsseiten nicht als passende Stellen ausgeben.
   - Nächsten technischen Adapter-Schritt je Portal/Firma dokumentieren.

3. Scanpriorisierung erweitern:
   - lange nicht geprüfte Firmen höher priorisieren
   - fehlerhafte Firmen in kontrollierte Retry-Lane setzen
   - kürzlich geprüfte Firmen rotieren lassen
   - Coverage-Prozentwerte ausdrücklich als Annäherung markieren

4. Erwartete neue Tests für JA-015:
   - Priorisierung unbekannter Firmen
   - Priorisierung lange nicht geprüfter Firmen
   - Behandlung fehlerhafter Portale
   - Rotation kürzlich geprüfter Firmen
   - Coverage-Report ohne Vollständigkeitsbehauptung

No-Gos für den nächsten Chat:

- Keine Vollständigkeitsbehauptung über den Arbeitsmarkt.
- Keine Jobbörsen oder Aggregatoren als Primärnachweis.
- Keine passende Stelle ohne offizielle Detailseite und MATCH/POSSIBLE-Klassifikation.
- Keine Bewerbung, Kontaktaufnahme oder externe Schreibaktion.
