# Handoff latest

Stand: 2026-08-17T14:41:35+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor finalem STP-Commit: `3d7c38c`
- Upstream: `origin/master`
- Ahead/Behind vor finalem Push: `1/0`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-009` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`

## Abgeschlossen

`JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen` ist abgeschlossen, aus `Roadmap.md` nach `Roadmap_archive.md` rotiert und in Commit `3d7c38c` enthalten.

Umgesetzt:

- `src/JobAgent.StatusMachine.psm1`
  - `Invoke-JobAgentStatusMachine` verarbeitet AdapterResults pro ScanRun.
  - Persistiert ScanAttempts, Jobs, JobSnapshots und ChangeEvents.
  - Statusuebergaenge: erster Treffer `NEW`, unveraenderter Folgelauf `ACTIVE`, geaenderter Treffer `UPDATED`, erfolgreicher autoritativer Leerscan `REMOVED`.
  - Fehlerhafte Adapterlaeufe loesen keine Entfernung oder Schliessung bestehender Jobs aus.
  - Invalide Rohjobs ohne Titel oder absolute Detail-URL werden nicht als Job gespeichert und als `JOB_INVALIDATED` protokolliert.
- `tests/Test-JobAgentStatusMachine.ps1`
  - Funktionstest fuer ersten Lauf, zweiten unveraenderten Lauf, Update-Lauf, fehlgeschlagenen Firmen-Scan, erfolgreiche Entfernung und invaliden Treffer.
- `tests/Test-JobAgentSupertest.ps1`
  - Statusmaschinen-Test in den fachlichen JobAgent-Supertest aufgenommen.
- `docs/data-model.md`
  - Abschnitt `Statusmaschine` mit Regeln, Grenzen und Testcommand ergaenzt.
- Roadmap/Todo
  - `JA-009` archiviert.
  - `TD-0007` im Index auf `done`.
  - `TD-0008` bleibt als einziger offener aktueller Todo-Eintrag.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd repin-immutables` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Hinweis: `.\ci.cmd stp` referenziert weiterhin den historischen `.\ci.cmd supertest`-Fehler aus `logs\verify\tst-450-human-visual-supertest.md`. Nach Nutzeranweisung gilt ein nicht angefragter historischer Supertest nicht als Blocker; der fachliche JobAgent-Supertest `tests\Test-JobAgentSupertest.ps1` ist gruen.

## Naechste Aufgabe

`TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`

Ziel:

- Zustand laden.
- Firmen priorisieren.
- Adapter ausfuehren.
- Rohjobs klassifizieren.
- Deduplikation und Statusmaschine anwenden.
- Persistenz transaktional aktualisieren.
- Ergebnisartefakt unter `logs/jobagent/` erzeugen.
- Fehler einzelner Firmen isoliert protokollieren, ohne den Gesamtlauf unnoetig abzubrechen.

Konkreter Einstieg:

1. Neues Modul fuer Orchestrierung anlegen, z.B. `src/JobAgent.DailyRun.psm1`.
2. Mock-Daily-Run-Test erstellen, z.B. `tests/Test-JobAgentDailyRun.ps1`.
3. Fixture-Szenario mit drei Firmen abdecken:
   - eine Firma erfolgreich mit neuer Stelle,
   - eine Firma unveraendert,
   - eine Firma nicht erreichbar.
4. Bestehende Module wiederverwenden:
   - `JobAgent.Persistence.psm1`
   - `JobAgent.SourceAdapters.psm1`
   - `JobAgent.Classification.psm1`
   - `JobAgent.Deduplication.psm1`
   - `JobAgent.StatusMachine.psm1`
5. Erst nach gruenem Funktionstest den Daily-Run-Test in `tests\Test-JobAgentSupertest.ps1` aufnehmen.

## Bekannte Risiken

- SonarQube: `http://localhost:9000/api/system/status` lief in 5s in ein Timeout; lokales `.\sonar.cmd` und `sonar.cmd` im PATH wurden nicht gefunden.
- `.\ci.cmd supertest` ist historisch Gradle-/Altlogik und nicht identisch mit dem fachlichen JobAgent-Supertest.
- Fuer JA-010 keine Live-Webrecherche in Funktionstests verwenden; nur Mock-/Fixture-Adapter.
