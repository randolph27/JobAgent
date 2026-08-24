# Handoff latest

Stand: 2026-08-24T08:58:00+02:00

## Neuer Chat Einstieg

Es sind keine aktiven Roadmap-Punkte offen. `TD-0033 / JA-033` ist abgeschlossen, nach `Roadmap_archive.md` rotiert und per Funktionstests, Supertest sowie Self-Check verifiziert.

## Aktueller Zustand

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `61e11983c73d`
- Upstream: `origin/master`
- Active: none
- Offen: keine aktiven Roadmap-Punkte
- Todo: `todo.current.md` zeigt keine aktiven Items
- Roadmap: `Roadmap.md` zeigt keine aktiven Punkte
- Archiv: `Roadmap_archive.md` enthaelt JA-001 bis JA-033
- Worktree zum Handoff-Zeitpunkt: `dirty` wegen Abschlussaenderungen, Staging/Commit/Push folgt im selben Nutzerauftrag

## Abgeschlossener Punkt

`TD-0033 / JA-033 Daily-Run-HTML und Detailberichte mit klickbaren offiziellen Stellen- und Anbieterlinks vereinheitlichen`

Umgesetzt:

- `src/JobAgent.Report.psm1` reichert Job-Reporteintraege um `provider_link`, `provider_label` und `provider_url` aus `Get-JobAgentCoverageCompanyLinks` an.
- Provider-Link-Auswahl bevorzugt eine zur Stelle passende offizielle `JobSource`; sonst wird der primaere offizielle Karriere-/Website-/ATS-Link genutzt.
- Markdown-Reports rendern getrennte kurze Links: `[Stelle]`, `[Karriere]`, `[ATS]`, `[Quelle]`.
- HTML-Reports validieren Links auf http/https, encodieren `href` und rendern externe Links mit `target="_blank"` sowie `rel="noopener noreferrer"`.
- Fehler-/Quellen-Sektionen verlinken nur offizielle `JobSource`-Eintraege.
- Unoffizielle Quellen, z.B. Jobboersen-/Discovery-Hints, bleiben nicht klickbar und zeigen einen Review-Grund.

Geaenderte Fachdateien:

- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentReport.ps1`
- `tests/Test-JobAgentDailyRun.ps1`

Geaenderte Steuerdateien:

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `todo.current.md`
- `todo.state.json`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`
- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd repin-immutables` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`

## Betriebsstatus

- SonarQube `http://localhost:9000/api/system/status`: `UP`
- Devserver `http://localhost:8500`: HTTP `200`

## Naechste Aufgabe

Keine aktive Aufgabe. Neuer Chat soll zuerst `Roadmap.md`, `todo.current.md`, `todo.state.json` und dieses Handoff pruefen. Falls neue Arbeit gewuenscht ist, neue Roadmap-Punkte gemaess Roadmap-Vertrag priorisiert anlegen.

## Harte Regeln fuer Folgechat

- Keine Bewerbung, kein Formular-Autofill, keine extern wirksame Aktion ohne ausdrueckliche Bestaetigung.
- Keine Jobboerse als offizieller Stellen- oder Anbieterlink.
- Keine ungesicherten Aggregator-URLs als offizielle Quelle ausgeben.
- Keine neue Live-Abhaengigkeit in Funktionstests.
- Supertest erst nach gruenen Funktionstests; wenn nicht angefragt, gilt er gemaess Nutzeranweisung als erledigt.
