# Handoff latest

Stand: 2026-08-17T16:09:07+02:00

## Projektzustand

- Projekt: JobAgent
- Branch: `master`
- HEAD vor STP-Commit: `ef57b0b7a613`
- Letzter Feature-Commit: `ef57b0b Complete JA-015 coverage prioritization`
- Upstream: `origin/master`
- Roadmap: keine aktiven Punkte in `Roadmap.md`
- Todo: keine offenen Items in `todo.state.json`
- Worktree laut STP-Capsule: `dirty` wegen Handoff-/Todo-Syncdateien; nach Commit/Push erneut pruefen

## Erledigter Stand

JA-015 ist vollstaendig umgesetzt, getestet und nach `Roadmap_archive.md` rotiert.

Implementiert:

- `src/JobAgent.Coverage.psm1`
  - Coverage-Metriken aus lokalem Store: Firmen gesamt, mit/ohne Karriere-URL, erfolgreich/fehlerhaft/nie gescannt, ohne/mit passenden Stellen und stale/ungescannt.
  - Adapter-/Coverage-Backlog fuer fehlende Karriere-URLs, fehlerhafte Portale, Retry-Lane, stale Rotation und erfolgreiche Firmen ohne Match.
  - Scanpriorisierung mit Gewichtung fuer unbekannte Firmen, fehlgeschlagene Portale, stale Scans und Rotationsmalus fuer kuerzlich erfolgreiche Scans.
  - Expliziter Hinweis: Coverage ist nur operative Naeherung aus lokalem Inventar, keine vollstaendige Marktdeckung.
- `src/JobAgent.Report.psm1`
  - Daily-Run-Markdownberichte enthalten jetzt `## Coverage und Adapter-Backlog`.
  - Enthalten sind Coverage-Tabelle, naechste Scanprioritaeten und Adapter-/Coverage-Backlog.
- `tests/Test-JobAgentCoverage.ps1`
  - Testet unbekannte Firmen, stale Firmen, fehlerhafte Portale, kuerzlich erfolgreiche Scans, passende Stellen, Coverage-Hinweis und Reportintegration.
- Testmatrix/Supertest
  - `docs/test-matrix.json` und `docs/test-matrix.md` enthalten JA-015.
  - `tests/Test-JobAgentSupertest.ps1` fuehrt `Test-JobAgentCoverage.ps1` mit aus.
  - `tests/Test-JobAgentTestMatrix.ps1` erwartet JA-002 bis JA-015.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd runtime-update` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `.\ci.cmd stp` -> Exit 0
- SonarQube `http://localhost:9000/api/system/status` -> `UP`
- `.\ci.cmd devserver-status` -> Exit 0, `port=8300`, `listening=True`

## Aktueller Arbeitsanker

Es gibt keinen offenen Roadmap-Punkt und kein aktives Todo.

Der neue Chat/Agent soll zuerst:

1. `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md` lesen.
2. `git -c core.pager=cat -c color.ui=false --no-pager status --short` ausfuehren.
3. Wenn keine neue Nutzeranforderung vorliegt, neue Roadmap-Punkte fuer die naechste fachliche Ausbaustufe erstellen.

Empfohlene naechste Roadmap-Themen, noch nicht angelegt:

1. Dynamische ATS-/Karriereportal-Erkennung aus Live-Pilot- und Coverage-Backlog ableiten.
2. Offizielle ATS-Adapter fuer priorisierte Portale implementieren, ohne Aggregatoren als Primaerquelle zu nutzen.
3. Firmeninventar kontrolliert erweitern und jede neue Firma nur mit offizieller Quelle aufnehmen.
4. Coverage-Report als separates Artefakt fuer Daily-Run-Status und historische Entwicklung ausgeben.
5. Live-Pilot-Lane mit begrenzter Firmenrotation wiederholen, aber weiter getrennt vom deterministischen Supertest halten.

## Harte No-Gos

- Keine Vollstaendigkeitsbehauptung ueber den Arbeitsmarkt.
- Keine Jobboersen oder Aggregatoren als Primaernachweis.
- Keine passende Stelle ohne offizielle Detailseite und `MATCH`/`POSSIBLE`-Klassifikation.
- Keine Bewerbung, Kontaktaufnahme oder externe Schreibaktion.
- Keine Live-Webzugriffe in Funktionstests oder Supertest.

## Letzte bekannte Artefakte

- `src/JobAgent.Coverage.psm1`
- `tests/Test-JobAgentCoverage.ps1`
- `docs/test-matrix.json`
- `docs/test-matrix.md`
- `Roadmap_archive.md`
- `todo.state.json`
- `handoff.latest.json`
