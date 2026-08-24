# Handoff latest

Stand: 2026-08-24T10:26:23.606+02:00

## Zustand

- Active: ``
- Status: `handoff`
- Ziel: JA-038 abgeschlossen; naechster Anker JA-039
- Branch: `master`
- HEAD: `ef3ae72f31e4`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`, wird in diesem Abschluss gestaged, committed und gepusht
- Route: ``

## Abgeschlossener Arbeitsschritt

JA-038 ist abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. Daily-Run-JSON, Markdown und HTML zeigen jetzt pro passender Stelle ein `Kurzprofil` aus offiziellen Adapter-/ATS-/Detailseiteninhalten. Fehlende offizielle Beschreibungen werden deterministisch als `Keine Beschreibung aus offizieller Quelle verfuegbar` dargestellt.

## Implementierung

- `src/JobAgent.SourceAdapters.psm1`: `New-JobAgentRawJob` normalisiert `summary` als Plaintext, entfernt Markup/Script-/Style-Inhalte, begrenzt auf 1200 Zeichen und fuehrt `description`/`description_source`.
- `src/JobAgent.StatusMachine.psm1`: Jobs und Snapshots speichern `description`; relevante Beschreibungsaenderungen erzeugen `JOB_UPDATED` mit `changed_fields=description`; historische Jobs ohne Feld bleiben kompatibel.
- `src/JobAgent.Report.psm1`: Markdown-/HTML-Jobtabellen enthalten `Kurzprofil`; fehlende Beschreibung bekommt einen fachlichen Leerwert; HTML escaped Beschreibungen und nutzt breitere responsive Tabellen.
- `schemas/jobagent.schema.json` und `tests/fixtures/jobagent/valid.json`: Schema/Fixture kennen Beschreibungsfelder fuer Job, RawJob und Snapshot.
- `Roadmap.md`, `Roadmap_archive.md`, `Roadmap_index.md`: JA-038 rotiert; nur JA-039 ist aktiv.

## Aktive Roadmap fuer neuen Chat

1. JA-039 Quellenbestand, Quellenanzahl und Scanabdeckung im Bericht transparent ausweisen.
   - Prioritaetsscore: 94
   - Meilenstein: M6-C Quellenbestand messbar und sichtbar
   - Scope: `src/JobAgent.Coverage.psm1`, `src/JobAgent.Report.psm1`, optional `tools/Measure-JobAgentSourceCoverage.ps1`, Tests `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentReport.ps1`, optional `tests/Test-JobAgentOperations.ps1`
   - Ziel: Gesamtquellen, offizielle Quellen, Karrierequellen, ATS-Quellen, Discovery-/Review-Quellen, verifizierte/offene/blockierte/retry-faellige Quellen und Scanabdeckung deterministisch aus `data/jobagent/store.json`, Source Registry und Laufartefakten berechnen.
   - No-Go: keine Live-Netzwerkabfrage fuer reine Zaehllogik; keine Jobboersen als offizielle Primaerquelle; Firmenanzahl und Quellenanzahl nicht vermischen; keine geschaetzten Zahlen.
   - Funktionstests zuerst: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`; falls Tool entsteht: `pwsh -NoProfile -File tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`
   - Supertest erst nach gruenen Funktionstests und Abschluss des Roadmap-Punkts.

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`
- `output/playwright/ja-022-viewport-800.png`
- `schemas/jobagent.schema.json`
- `src/JobAgent.Report.psm1`
- `src/JobAgent.SourceAdapters.psm1`
- `src/JobAgent.StatusMachine.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentReport.ps1`
- `tests/Test-JobAgentSchema.ps1`
- `tests/Test-JobAgentSourceAdapters.ps1`
- `tests/Test-JobAgentStatusMachine.ps1`
- `tests/fixtures/jobagent/valid.json`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Bekannte Hinweise

- Kein harter Blocker.
- Der Screenshot aus dem Chat war lokal nicht als Datei verfuegbar; JA-038 wurde ueber Report-, HTML- und Viewport-Tests abgedeckt.
- `logs/verify/ja-038-job-description-report.md` liegt lokal vor; `logs/verify/` ist nicht im Git-Status sichtbar.

## Naechster Anker

JA-039 umsetzen. Vor Schreibarbeit zuerst die aktuelle Source-/Coverage-Struktur lesen, dann die reine Quellenmetrikfunktion testen, anschliessend Report/CLI anbinden.
