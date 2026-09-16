# Handoff latest

Stand: 2026-09-16T12:41:56.900+02:00

## Zustand

- Active: `TD-0062`
- Status: `in-progress`
- Ziel: QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen #comment: Das blosse Vorhandensein einer Screenshotdatei beweist weder fehlerfreies Layout noch barrierearme Bedienbarkeit.
- Branch: `master`
- HEAD: `56075e130199`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen und Fachstand

- `src/JobAgent.Report.psm1`: Der eingebettete Report-Client markiert bei einem Formularreset `focusReset` und setzt den Fokus nach dem nachgelagerten Hash-Render per `requestAnimationFrame` auf `jobagent-reset`. Die vorhandene Pagination-Fokuslogik bleibt unveraendert.
- `tests/Test-JobAgentUiBrowserAudit.ps1`: Der Browseraudit setzt einen aktiven Freitextfilter, loest Reset mit `Enter` aus und behauptet danach wieder 264 Stellen, Fokus auf `jobagent-reset` und sichtbare Outline. Die Evidence-Fall-ID lautet `keyboard_filter_reset_and_tab_journey`.
- `todo.state.json`: Der naechste Arbeitsschritt referenziert die Reset- und Pagination-Fokuskorrektur.
- `todo.checkpoint.json`, `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`, `handoff.latest.json`: durch `ci.cmd stp` synchronisiert.

## Roadmap- und Todo-Entscheidung

- `TD-0062` / `QA-005` bleibt `in-progress`. QA-005.1 ist erledigt; QA-005.2 und QA-005.3 sind nicht vollstaendig nachgewiesen.
- Es wurde kein Roadmap-Punkt rotiert: QA-005 erfordert weiterhin den vollstaendigen fokussierten Browseraudit, die visuelle Sichtung, negative Rendererfixtures, versionierte Referenzbilder und die drei festgelegten Funktionstests.
- `TD-0063` / `QA-006` bleibt offen und beginnt erst nach fachlichem Abschluss von QA-005.
- `TD-0056` bleibt als bekannter CI-Driftbefund offen; keine Pin- oder Runtime-Reparatur wurde vorgenommen.
- Kein `supertest` wurde ausgefuehrt. Gemass aktuellem Nutzerauftrag ist kein Supertest fuer diesen Arbeitsschnitt nachzuholen.

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- Parserpruefung fuer `src/JobAgent.Report.psm1` und `tests/Test-JobAgentUiBrowserAudit.ps1` -> Exit `0`
- `git diff --check` -> Exit `0`
- `./ci.cmd stp` -> Exit `0`; Todo- und Handoff-Artefakte synchronisiert.

## Nicht abgeschlossene Verifikation

- Der vollstaendige `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` muss im neuen Chat erneut ausserhalb der Sandbox gestartet werden. Vorherige isolierte Laeufe erzeugten keinen verwertbaren Abschlussstatus; sie wurden als eigene Testprozesse beendet. Es gibt keinen behaupteten gruenen Browseraudit fuer die Reset-Erweiterung.
- Keine Laufzeitprozesse aus diesen abgebrochenen Testlaeufen weiterverwenden. Devserver-Status vor dem neuen Test nur ueber `./ci.cmd devserver-status` pruefen; bei Bedarf ausschliesslich `./ci.cmd devserver-start` verwenden.

## Naechster Anker

1. `./ci.cmd devserver-status` ausfuehren; falls nicht bereit, `./ci.cmd devserver-start` im Hintergrund verwenden.
2. `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` ausserhalb der Sandbox vollstaendig bis Exitcode und Evidence-Abschluss laufen lassen. Bei Fehler nur den konkreten Browserfall isolieren; kein Supertest.
3. Bei Erfolg QA-005.2 in Roadmap/Todo abschliessen und QA-005.3 umsetzen: Screenshots aller Pflichtzustaende erzeugen und sichten, negative Clipping-/Overlap-/Kleincontrol-/Fokusfixture verifizieren, Referenzen plus Hashes unter `doc/roadmap-screenshots/` versionieren sowie Evidence/Review aktualisieren.
