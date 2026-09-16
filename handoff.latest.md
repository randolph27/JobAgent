# Handoff latest

Stand: 2026-09-16T14:29:23.610+02:00

## Zustand

- Active: `TD-0063`
- Status: `in-progress`
- Ziel: QA-006 Vorhandenen Supertest kontrolliert erweitern und seine Vollstaendigkeit nachweisen #comment: Der einzige Startbefehl soll alle abgeschlossenen Funktionalitaeten und die echte UI mit belastbarem Ergebnisprotokoll pruefen.
- Branch: `master`
- HEAD: `c54e95962e67`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `docs/reviews/QA-001-function-inventory.json`
- `docs/test-matrix.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-fixture-viewport-1366.png`
- `output/playwright/ja-022-fixture-viewport-1920.png`
- `output/playwright/ja-022-fixture-viewport-390.png`
- `output/playwright/ja-022-fixture-viewport-800.png`
- `output/playwright/ja-022-production-coverage-viewport-1366.png`
- `output/playwright/ja-022-production-coverage-viewport-1920.png`
- `output/playwright/ja-022-production-coverage-viewport-390.png`
- `output/playwright/ja-022-production-coverage-viewport-800.png`
- `tests/Test-JobAgentSupertest.ps1`
- `tests/Test-JobAgentTestMatrix.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Verify-JobAgentCompanyCandidates.ps1`

## QA-006.1 abgeschlossen

- `tests/JobAgent.Supertest.psm1` ist die alleinige Quelle der Supertest-Auswahl: nur Matrixeintraege mit `status=done` und `include_in_supertest=true`; leerer Plan, fehlende Datei, doppelte Datei, ungueltige/doppelte Reihenfolge und Selbstaufnahme brechen ab.
- `tests/Test-JobAgentSupertest.ps1` nutzt den dynamischen Plan und protokolliert Roadmap-ID, Testpfad, Command, Exitcode, Ausgabeende und Sollanzahl.
- `docs/test-matrix.json` enthaelt 27 eindeutig geordnete freigegebene Tests. Neu eingebunden: CiContracts, Kandidatenverifikation, FetchEnvironment, FetchErrorInspection, HtmlAudit und HtmlViewportAudit.
- `tests/Test-JobAgentTestMatrix.ps1` erzwingt die Zuordnung jeder inventarisierten Nicht-Aggregator-Testdatei.
- `tools/Verify-JobAgentCompanyCandidates.ps1` normalisiert Runspace-Inputs zu `PSCustomObject`; der Parallel-Worker-Fall funktioniert wieder.

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`, inklusive Parallel-Worker-Fall.
- `Test-JobAgentFetchEnvironment.ps1`, `Test-JobAgentFetchErrorInspection.ps1`, `Test-JobAgentHtmlAudit.ps1` und `Test-JobAgentHtmlViewportAudit.ps1` -> jeweils Exit `0`.
- `git diff --check` -> Exit `0`.
- Kein neuer Supertest-Lauf; gemaess Nutzeranweisung gilt er als erledigt, solange er nicht angefragt wurde.

## Naechster Anker

QA-006.2: `tests/Test-JobAgentSupertestContract.ps1` mit isolierten Child-Skripten fuer Erfolg, Nichtnull-Exit, Exception, ungueltige Ergebnisdaten, Timeout und Abbruch erstellen. Keine echte Supertest-Rekursion. Der Runner muss nach erstem Fehler atomar einen Gesamtbericht mit `passed`/`failed`/`blocked`/`not-run`, Command, CWD, Start/Ende, Exit und stdout/stderr schreiben. Danach nur Contract-, Matrix- und CI-Contracttest ausfuehren. QA-006.3, Vollsuite und Wiederholbarkeitsnachweis bleiben offen. `TD-0056` bleibt unveraendert offen; keine Roadmap-Rotation, da QA-006 noch nicht abgeschlossen ist.
