# Handoff latest

Stand: 2026-09-21T13:30:22.044+02:00

## Zustand

- Active: `TD-0078`
- Status: `in-progress`
- Ziel: M3 - Publikation und Gesamtabnahme: JA-050 Stellenworkflow mit Wachstum, Markierungen und Grenzfaellen abnehmen #comment: Abschluss erfordert belegtes Zusammenspiel von regulaerem Lauf, Suche, Details, persoenlichen Markierungen und erneuter Publikation.
- Branch: `master`
- HEAD: `8281c5593bde`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `docs/reviews/JA-050-acceptance.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `tests/Test-JobAgentSupertest.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

`TD-0078` / `JA-050`: Teilbild 3, lokaler Last- und Renderbenchmark fuer 0/1/50/51/121/1000/10000 Stellen mit 5 Warmups und 20 Messungen pro Filterfall.

## Fortsetzung fuer den naechsten Chat

- Roadmapstatus: Ausschliesslich `JA-050` ist aktiv; keine Rotation moeglich. Teilbild 1 ist durch `Test-JobAgentAcceptance.ps1` belegt: 4 Firmen, 4 historische Stellen, 3 offene Stellen, Update/Schliessung/Quellenfehler sowie generationengebundene Markierungen, Ausblendung und Sichtung.
- Teilbild 2 hat gezielte grüne Nachweise: `Test-JobAgentCalendarBrowserAudit.ps1`, `Test-JobAgentUiBrowserAudit.ps1 -ApplicationOverviewOnly`, `-SavedSearchOnly`, `-VisibilityOnly`, `Test-JobAgentUserState.ps1`, `Test-JobAgentSavedSearches.ps1` und `Test-JobAgentAcceptance.ps1`. Artefaktpfade und Exitcodes: `docs/reviews/JA-050-acceptance.md`.
- Der ungekürzte `Test-JobAgentUiBrowserAudit.ps1` ist nicht als bestanden belegt: Die lokale Playwright-CLI-Sitzung blieb nach `JA-048-stars-390.png` bei der folgenden Filterinteraktion stehen und wurde kontrolliert beendet. Vor der Gesamtabnahme isoliert reproduzieren; keine Teilausgabe als Volltest werten.
- Als Nächstes Benchmarkhost und Test für 0/1/50/51/121/1000/10000 Stellen implementieren. Akzeptanz: höchstens 50 sichtbare Karten, p95 Filter <=500 ms, erster bedienbarer Render bei 10000 <=3 s; 5 Warmups + 20 Messungen, Browser-/Hardwareversion, Referenzzeit, Exitcode und `logs/jobagent/JA-050/performance.json` erfassen.
- Danach die zusammengeführte Browserreise von Teilbild 2 schließen: stabile URL, Suche/Firma/Gebiet/Arbeitsbedingungen, persönliche Filter, Pagination, Detail/Quellenlink, beide Sterne, Reload/neuer Report, Zurück/Vor, Export/Import, Nulltreffer, Speicherfehler, unbekannte Detail-ID sowie Kalender/Chronik an einer gemeinsamen Generation mit ID-, DOM- und Fokusassertions.
- `tests/Test-JobAgentSupertest.ps1` wird mit diesem Arbeitsstand gelöscht. Gemäß Nutzerauftrag ist kein Supertest auszuführen. Deshalb schlägt `Test-JobAgentTestMatrix.ps1` derzeit mit `Test-JobAgentSupertest.ps1 fehlt.` fehl; die Testmatrix-/Supertest-Abhängigkeit nur bei einer fachlichen Konsolidierung ändern.
- Devserver ist beendet. Für spätere Browserläufe nur `./ci.cmd devserver-start` auf Port 8500 verwenden.
