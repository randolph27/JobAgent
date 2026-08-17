# Handoff latest

Stand: 2026-08-17T15:52:00+02:00

## Status

- Projekt: JobAgent
- Branch: master
- HEAD vor Commit: `5c1aa92`
- Worktree vor Commit: dirty
- Active: _(none)_
- Status: open
- Abgeschlossen und rotiert: JA-014 / TD-0012
- Nächster Einstieg: TD-0013 / JA-015 Kontinuierliche Firmenabdeckung und Adapter-Erweiterung priorisieren

## Abgeschlossen

JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll ist umgesetzt, validiert und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.

Umgesetzt:

- `src/JobAgent.LiveScan.psm1`: Live-Policy, offizieller Karrierequellenabruf, Retry-Protokoll, Aggregator-Ausschluss, Kandidatenfilterung, Detailseitenabruf und Live-Pilot-Zusammenfassung.
- `tools/Invoke-JobAgentLivePilot.ps1`: separate Live-Lane mit verwaltetem Daily-Run, Statusdatei, Run-Log, Daily-Report und `live-pilot-<date>.json`.
- `tests/Test-JobAgentLiveScan.ps1`: deterministischer Funktionstest ohne Live-Webzugriff für Policy, Kandidatenfilter, Detailseitenprüfung, NO_JOBS_FOUND und Retry-Logs.
- `src/JobAgent.DailyRun.psm1` / `src/JobAgent.StatusMachine.psm1`: leere Adapterresultate werden sauber als `SKIPPED` verarbeitet.
- `src/JobAgent.SourceAdapters.psm1`: `http_status` darf bei nicht verfügbarer HTTP-Antwort `null` bleiben.
- `.ci/bin/modules/core-utils.ps1`: atomarer CI-Write-Fallback überschreibt vorhandene Zieldateien robust; `devserver-status` läuft wieder.
- `docs/test-matrix.*` und `tests/Test-JobAgentTestMatrix.ps1`: JA-014 ist als separate Live-Pilot-Lane dokumentiert, nicht im Supertest.
- `Roadmap.md`, `Roadmap_archive.md`, `Roadmap_index.md`, `todo.*`: JA-014 abgeschlossen; JA-015 ist der einzige offene aktive Punkt.

Live-Pilot:

- Command: `pwsh -NoProfile -Command "& .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -CompanyIds @('company:siemens_ag','company:stadtwerke_muenchen_gmbh') -MaxCompanies 2 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 5 -MaxDetailFetchesPerSource 2"`
- Ergebnis: `SUCCESS`, 2 Firmen, 2 Adapterversuche, 3 offizielle Detailseiten geprüft, 0 technische Fehler.
- `verified_matching_jobs`: 0. Die geprüften Detailseiten wurden als nicht passende IT-Führungsrollen klassifiziert und daher nicht als passende Treffer ausgegeben.
- Evidence: `logs/jobagent/live-pilot-20260817.json`, `logs/jobagent/daily-run-20260817T134912490Z.json`, `logs/jobagent/daily-run-20260817T134912490Z.md`.

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

## Nächste Aufgabe

TD-0013 / JA-015 Kontinuierliche Firmenabdeckung und Adapter-Erweiterung priorisieren.

Konkreter Einstieg:

1. Coverage-Metriken aus `data/jobagent/store.json` ableiten: Firmen, erfolgreiche/fehlerhafte Scans, fehlende Karriere-URLs, passende Stellen, zuletzt geprüft.
2. Adapter-/Portal-Backlog aus Live-Pilot-Befunden erzeugen, insbesondere präzisere Jobdetail-Erkennung für dynamische ATS- und Karriereseiten.
3. Rotationslogik ergänzen, damit Firmenauswahl nach Alter, Fehlerstatus und Abdeckung priorisiert wird.

No-Gos:

- Keine Vollständigkeitsbehauptung über den Arbeitsmarkt.
- Keine Jobbörsen oder Aggregatoren als Primärnachweis.
- Keine passende Stelle ohne offizielle Detailseite und MATCH/POSSIBLE-Klassifikation.
