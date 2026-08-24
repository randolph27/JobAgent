# Handoff latest

Stand: 2026-08-24T10:12:31.895+02:00

## Zustand

- Active: ``
- Status: ``handoff``
- Ziel: Neuen Chat/Agenten mit abgeschlossenem JA-037 und naechstem Anker JA-038 starten
- Branch: ``master``
- HEAD: ``e3949149977a``
- Upstream: ``origin/master``
- Ahead/Behind: ``0/0``
- Worktree: ``dirty``, wird anschliessend gestaged, committed und gepusht
- Route: ``

## Abgeschlossener Arbeitsschritt

JA-037 ist abgeschlossen und aus ``Roadmap.md`` nach ``Roadmap_archive.md`` rotiert. Die sichtbaren HTML-/Markdown-Berichte verwenden fachliche deutsche Labels statt technischer Werte fuer Metriken, Status, Zielgebiete, Work-Modelle, Beschaeftigungsarten, Fehlerklassen, Retry-Hinweise, Backlog-Arten und Scan-Aktionen. Maschinenlesbare JSON-Artefakte bleiben unveraendert technisch.

## Wichtige Implementierung

- ``src/JobAgent.Report.psm1``: ``ConvertTo-JobAgentReportDisplayLabel`` plus Markdown-/HTML-Helfer; Daily-Run-Status, Statistik-Karten, Tabellen und Coverage-Backlog werden fachlich gelabelt.
- ``tools/Measure-JobAgentCompanyCoverage.ps1``: ``ConvertTo-ToolDisplayLabel`` plus Markdown-/HTML-Helfer; Coverage-HTML/-Markdown, Importwellen, Firmeninventar, Backlog, Scanprioritaeten und Review-Queues zeigen lesbare Werte.
- ``tests/Test-JobAgentReport.ps1``: Assertions verhindern sichtbare technische Metriklabels wie ``checked_jobs``, ``active_matching_jobs``, ``uncertain_sources``, ``published_at``.
- ``tests/Test-JobAgentCoverage.ps1``: Assertions pruefen fachliche Backlog-/Discovery-Labels und verhindern sichtbare Rohwerte wie ``discovery_hint``, ``MUNICH_20KM``, ``NEVER_SCANNED``, ``RETRY_REQUIRED``, ``source_id``, ``priority_score``, ``scan_rotation`` im Coverage-HTML.

## Aktive Roadmap fuer naechsten Chat

1. JA-038 Stellenbeschreibung und Kurzprofil in Daily-Run- und HTML-Berichte aufnehmen, Prioritaetsscore 96, Meilenstein M6-B. Scope: ``src/JobAgent.SourceAdapters.psm1``, ``src/JobAgent.LiveScan.psm1``, ``src/JobAgent.StatusMachine.psm1``, ``src/JobAgent.Report.psm1``, Tests ``tests/Test-JobAgentSourceAdapters.ps1``, ``tests/Test-JobAgentDailyRun.ps1``, ``tests/Test-JobAgentReport.ps1``, ``tests/Test-JobAgentSchema.ps1``. Keine KI-generierten Jobtexte, keine Aggregator-Snippets als Primaerbeschreibung, fehlende offizielle Beschreibung explizit anzeigen.
2. JA-039 Quellenbestand, Quellenanzahl und Scanabdeckung im Bericht transparent ausweisen, Prioritaetsscore 94, Meilenstein M6-C. Scope: ``src/JobAgent.Coverage.psm1``, ``src/JobAgent.Report.psm1``, optional ``tools/Measure-JobAgentSourceCoverage.ps1``, Tests ``tests/Test-JobAgentCoverage.ps1``, ``tests/Test-JobAgentReport.ps1``. Keine Live-Netzwerkabfrage fuer reine Zaehllogik; Firmenanzahl und Quellenanzahl nicht vermischen.

## Versionierte Aenderungen

- ``Roadmap.md``
- ``Roadmap_archive.md``
- ``Roadmap_index.md``
- ``data/jobagent/company-candidate-verification.queue.json``
- ``handoff.latest.json``
- ``handoff.latest.md``
- ``html/jobagent/company-coverage.html``
- ``html/jobagent/ja-022-viewport-audit.html``
- ``output/playwright/ja-022-viewport-1366.png``
- ``output/playwright/ja-022-viewport-1920.png``
- ``output/playwright/ja-022-viewport-800.png``
- ``src/JobAgent.Report.psm1``
- ``tests/Test-JobAgentCoverage.ps1``
- ``tests/Test-JobAgentReport.ps1``
- ``todo.events.jsonl``
- ``todo.history.digest.json``
- ``todo.master.index.json``
- ``tools/Measure-JobAgentCompanyCoverage.ps1``

## Verifikation

- ``pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`` -> Exit ``0``
- ``pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`` -> Exit ``0``
- ``pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1`` -> Exit ``0``
- ``pwsh -NoProfile -File tests\Test-JobAgentHtmlViewportAudit.ps1`` -> Exit ``0``
- ``.\ci.cmd supertest`` -> Exit ``0``
- ``.\ci.cmd stp`` -> Exit ``0``

## Bekannte Hinweise

- Kein harter Blocker.
- Der Screenshot aus dem Chat war lokal nicht als Datei verfuegbar; JA-037 wurde ueber vorhandene HTML-Artefakte und Tests gegen sichtbare technische Labels abgedeckt.
- SonarQube war erreichbar auf ``http://localhost:9000/api/system/status`` mit Status ``UP``.

## Naechster Anker

JA-038 umsetzen. Erst funktionsbezogene Tests ausfuehren, Supertest erst nach abgeschlossenem Roadmap-Punkt oder expliziter Anforderung.
