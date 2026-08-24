# Handoff latest

Stand: 2026-08-24T11:18:58.000+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: 
- Branch: `master`
- HEAD: `3a248ba8cca1`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `templates/chess/README.md`
- `templates/ubuntu-web/README.md`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd observer-baseline` -> Exit `0`
- `.\ci.cmd drift-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- Supertest wurde in diesem Abschlusslauf nicht erneut angefragt; nach Nutzeranweisung gilt er fuer diesen Uebergabeabschluss als erledigt. Letzter belegter Supertest: `2026-08-24T09:29:31.729+02:00`, Exit `0`, `tests_total=19`.

## Naechster Anker

Aktive Punkte: JA-025 Firmeninventar auf mindestens 1000 verifizierte oder prüfbare Zielgebiet-Kandidaten erweitern #comment: Der lokale Store muss statt weniger Dutzend Firmen eine skalierbare, belegte Kandidatenbasis fuer Muenchen, 20-km-Umkreis und Freising enthalten.

## Uebergabe fuer neuen Chat

### Abgeschlossen

- `TD-0042 CI: Resolve drift (observer/route/immutables)` ist erledigt.
- Route-Check-Befund war: ungeschlossene Markdown-Code-Fences in `templates/chess/README.md` und `templates/ubuntu-web/README.md`.
- Fix: In beiden Template-READMEs wurde der Windows-PowerShell-Codeblock vor dem nachfolgenden Unix-Abschnitt geschlossen.
- Immutable-Pins wurden mit `.\ci.cmd repin-immutables` aktualisiert; dadurch sind `.ci/pins/immutable.hashes.json` und `.ci/pins/immutable.snapshot/Roadmap.md` geaendert.
- Observer-Baseline wurde erneuert; `.\ci.cmd drift-check` ist danach gruen.

### Roadmap-Status

- Kein Roadmap-Punkt wurde in diesem Arbeitsschritt vollstaendig abgeschlossen oder rotiert.
- `Roadmap.md` enthaelt weiterhin drei aktive Punkte: `JA-025`, `JA-026`, `JA-027`.
- `JA-025` ist der naechste fachliche Startpunkt und blockiert beziehungsweise staerkt die Wirkung von `JA-026` und `JA-027`.

### Offene Aufgaben

- `TD-0039 / JA-025`: Firmeninventar auf mindestens 1000 verifizierte oder pruefbare Zielgebiet-Kandidaten erweitern. Start mit Quelleninventar, Importwellen, Dedupe und Coverage-Gates. Relevante Tests: `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentImportWaves.ps1`, `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentCompanyDedupeScale.ps1`.
- `TD-0040 / JA-026`: Daily-Run-Scanbreite konfigurierbar machen und Bericht transparent ausweisen lassen, ob `3` ein Testlimit oder Datenbasisumfang ist. Erst sinnvoll voll wirksam nach groesserer Firmenbasis aus `JA-025`.
- `TD-0041 / JA-027`: Karriere-/ATS-Link-Ermittlung skalieren; generische Such-, FAQ- oder Landingpages duerfen nicht als Jobdetail persistiert werden.

### Betriebs- und Arbeitsregeln fuer Folgechat

- Einstieg: `D:\_Scripte\JobAgent`.
- Vor Weiterarbeit lesen: `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md`.
- Tests nur funktionsbezogen ausfuehren; `.\ci.cmd supertest` erst nach abgeschlossenem Roadmap-Punkt oder ausdruecklicher Anforderung.
- Devserver und Sonar nur ueber `.\ci.cmd`-Befehle starten; keine Vordergrundserver.
- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Jobboersen nur als Discovery-Hinweise verwenden, nicht als Primaerbeleg.
