# Handoff latest

Stand: 2026-08-17T16:12:00+02:00

## Status

- Projekt: JobAgent
- Branch: master
- Upstream: origin/master
- HEAD: 7eb0b13be51e
- Worktree: dirty
- Active: _(none)_
- Status: open
- STP: `.\ci.cmd stp` ausgefuehrt am 2026-08-17T15:28:42+02:00
- Abgeschlossen und rotiert: JA-012 / TD-0010
- Naechster Einstieg: TD-0011 / JA-013 Teststrategie und Supertest fuer Kernfunktionen konsolidieren

## Abgeschlossen

JA-012 Lokalen Scheduler- und Betriebsmodus fuer taegliche Laeufe dokumentieren und absichern ist fertig, archiviert und getestet.

Umgesetzt:

- `src/JobAgent.Operations.psm1`: Betriebswrapper fuer Daily-Runs mit separatem Lock, Statusdatei, Run-Log, Exitcode, Fehlerstatus und Logrotation.
- `tools/Get-JobAgentDailyRunStatus.ps1`: nicht-interaktive JSON-Statusabfrage fuer Scheduler- und manuelle Checks.
- `tools/Invoke-JobAgentDailyRun.ps1`: nutzt den Betriebswrapper; Live-Lane bleibt ohne `-FixturePath` fail-closed.
- `.ci/bin/modules/ci-commands-main.ps1`: registriert `daily-run`, `daily-run-status`; `supertest` nutzt im JobAgent-Repo die fachliche PowerShell-Test-Suite.
- `tests/Test-JobAgentOperations.ps1`: Funktionstests fuer freien Start, Statusschreibung, Fehler-Exitcode, Logrotation und parallelen Startschutz.
- `docs/data-model.md`: Scheduler-Bedienung, Exitcodes, Re-Run-Regeln und Secret-Grenzen dokumentiert.

Roadmap/Todo:

- `Roadmap.md`: JA-012 entfernt; aktive Roadmap beginnt bei JA-013.
- `Roadmap_archive.md`: JA-012 als erledigt aufgenommen.
- `todo.current.md` / `todo.state.json`: TD-0011 offen, kein aktiver In-Progress-Eintrag.
- `todo.events.jsonl`: TD-0010 done und TD-0011 seed erfasst; STP hat erledigte Events rotiert.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit 0
- `pwsh -NoProfile -File tools\Get-JobAgentDailyRunStatus.ps1` -> Exit 0
- `.\ci.cmd runtime-update` -> Exit 0
- `.\ci.cmd daily-run-status` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd stp` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> UP
- `Invoke-WebRequest http://localhost:8300/` -> 200

Hinweis: `.\ci.cmd stp` schreibt weiterhin eine alte Verify-Digest-Zeile mit `.\ci.cmd supertest` Exit 1 in seine CAPSULE. Der direkt danach ausgefuehrte aktuelle `.\ci.cmd supertest` ist gruen.

## Naechste Aufgabe

TD-0011 / JA-013 Teststrategie und Supertest fuer Kernfunktionen konsolidieren.

Konkreter Einstieg:

1. Bestehende Testmatrix aus `tests/Test-JobAgent*.ps1` und `tests/Test-JobAgentSupertest.ps1` gegen JA-002 bis JA-012 erfassen.
2. Dokumentierten Testvertrag in `docs/data-model.md` oder separater Testmatrix so strukturieren, dass Roadmap-ID, Testdatei, Command und Status nachvollziehbar sind.
3. Pruefen, ob `.\ci.cmd supertest` alle abgeschlossenen fachlichen Bereiche abdeckt und Live-Crawls weiterhin getrennt bleiben.
4. Danach Roadmap/Todo/Handoff konsistent aktualisieren und nur bei abgeschlossenem Punkt archivieren.

## Hinweise

- Funktionstests bleiben mock-/fixture-basiert; Live-Webrecherche ist erst JA-014.
- Keine produktiven Bewerbungen, keine Kontaktaufnahme, keine externen Schreibaktionen.
- Devserver laeuft nach Projektkonfiguration auf http://localhost:8300/.
- SonarQube ist auf http://localhost:9000 UP; lokales `sonar.cmd` fehlt im JobAgent-Repo weiterhin.
