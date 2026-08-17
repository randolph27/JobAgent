# Handoff latest

Stand: 2026-08-17T15:05:00+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD: finaler Commit, siehe `git rev-parse --short HEAD`
- Ahead/Behind: nach Commit `1/0` gegen `origin/master`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-010` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0009 / JA-011 Ausgabeformat und Priorisierung A/B/C fuer Rechercheberichte umsetzen`

## Abgeschlossen

`JA-010 Deterministischen Daily-Run-Orchestrator implementieren` ist abgeschlossen, aus `Roadmap.md` nach `Roadmap_archive.md` rotiert und im fachlichen Supertest enthalten.

Umgesetzt:

- `src/JobAgent.DailyRun.psm1`: Store-Lock, Firmenpriorisierung, isolierte Adapterausfuehrung, Klassifikation, Statusmaschine, atomarer Store-Write und JSON-Laufartefakt.
- `tools/Invoke-JobAgentDailyRun.ps1`: lokaler CLI-Einstieg fuer deterministische Fixture-Laeufe; Live-Adapter bleiben bewusst deaktiviert.
- `tests/Test-JobAgentDailyRun.ps1`: Mock-Szenario mit neuer Stelle, unveraenderter Stelle im Folgelauf, nicht erreichbarer Firma und CLI-Fixture-Modus.
- `tests/Test-JobAgentSupertest.ps1`: Daily-Run-Funktionstest in den fachlichen Supertest aufgenommen.
- `docs/data-model.md`: Daily-Run-Orchestrator-Vertrag ergaenzt.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> `UP`
- `Invoke-WebRequest http://localhost:8300/` -> `200`
- `.\ci.cmd repin-immutables` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe

`TD-0009 / JA-011 Ausgabeformat und Priorisierung A/B/C fuer Rechercheberichte umsetzen`

Konkreter Einstieg:

1. Report-Renderer fuer Markdown/JSON aus Daily-Run-Store und ScanRun-Summary erstellen.
2. Abschnitte fuer neue, aktive, geaenderte und entfernte Stellen plus Statistik und neue Unternehmen abbilden.
3. A/B/C-Priorisierung mit Begruendung aus Klassifikation, Standort, Arbeitsmodell und Bewerbungsrelevanz rendern.
4. Renderer-Funktionstest mit leeren Ergebnissen, neuen Stellen, Updates, entfernten Stellen und fehlenden optionalen Feldern erstellen.
5. Erst nach gruenem Funktionstest in den fachlichen Supertest aufnehmen.

## Hinweise

- Devserver laeuft gemaess `.ci\ci.config.json` auf `http://localhost:8300/`; die Nutzerangabe `8090` weicht von der Projektkonfiguration ab.
- SonarQube wurde ueber die vorhandene WSL-Installation gestartet; `.\ci.cmd sonar-start` bleibt im JobAgent-Repo blockiert, weil ein lokales `sonar.cmd` fehlt.


