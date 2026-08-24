# Handoff latest

Stand: 2026-08-24T08:41:21+02:00

## Neuer Chat Einstieg

Direkt mit `TD-0033 / JA-033` weitermachen: Daily-Run-Markdown und Daily-Run-HTML sollen pro relevanter Ergebniszeile getrennte, sichere Links fuer die offizielle Stellen-URL und die offizielle Anbieter-/Karriere-/ATS-Quelle ausgeben.

## Aktueller Zustand

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD: `e37cdf63e6ed`
- Upstream: `origin/master`
- Active: `TD-0033`
- Offen: `TD-0033 / JA-033`
- Abgeschlossen und rotiert: `TD-0032 / JA-032`
- Roadmap: `Roadmap.md` enthaelt nur noch `JA-033`; `JA-032` liegt in `Roadmap_archive.md`
- Todo: `todo.current.md` zeigt `TD-0033` als Active
- Worktree: `dirty`

## Was erledigt ist

JA-032 ist fachlich abgeschlossen:

- `tools/Measure-JobAgentCompanyCoverage.ps1` rendert zentrale Coverage-Linkobjekte in Markdown und HTML.
- Coverage-HTML enthaelt Linkspalten fuer Importwellen-Kandidaten, Backlog, Scanprioritaeten und Firmeninventar.
- Coverage-Markdown enthaelt dieselben Linkspalten fuer Importwellen-Kandidaten, Backlog, Scanprioritaeten und Firmeninventar.
- HTML-Links nutzen `target="_blank"` und `rel="noopener noreferrer"`.
- Klickbare Links werden nur fuer `is_clickable=true` ausgegeben.
- Unverifizierte Discovery-Hints werden sichtbar als `Review-Hinweis` ausgegeben und nicht als offizieller Anbieterlink verlinkt.
- Linkzellen nutzen kurze Labels und behalten den bestehenden Overflow-/Sticky-Header-Schutz.
- `tests/Test-JobAgentCoverage.ps1` prueft Linkspalten, sichere HTML-Links, Review-Hinweise und den Ausschluss produktiver Discovery-Hint-Links.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Naechste Aufgabe TD-0033 / JA-033

Umzusetzen:

1. In `src/JobAgent.Report.psm1` Report-Eintraege fuer Jobs und Quellen-Issues um Anbieterlink-Information aus dem zentralen Linkvertrag erweitern.
2. In `src/JobAgent.DailyRun.psm1` sicherstellen, dass Daily-Run-Reports die Anbieterlink-Daten aus Store/Company/JobSource-Kontext bekommen.
3. Markdown-Renderer erweitern: Stellenlink und Anbieterlink getrennt ausgeben; offizielle Stellenlinks nutzen `official_url`, Anbieterlinks nutzen Karriere/Website/ATS aus dem Linkvertrag.
4. HTML-Renderer erweitern: sichere `href`-Attribute mit `target="_blank"` und `rel="noopener noreferrer"`, kurze Labels, HTML-Encoding, keine externen Ressourcen.
5. Fehler-/Quellen-Sektionen nur dann klickbar machen, wenn die Quelle als offizielle `JobSource` im Store steht; sonst nicht klickbarer Review-Grund.
6. Tests in `tests\Test-JobAgentReport.ps1` und `tests\Test-JobAgentDailyRun.ps1` fuer aktive/neue/geaenderte/entfernte Jobs, fehlende Anbieterlinks, Fehlerquellen, URL-Encoding und HTML-Encoding ergaenzen.

## Wichtige Regeln

- Keine Bewerbungsaktion, kein Formular-Autofill, keine extern wirksame Aktion.
- Keine Jobboerse als offizieller Stellen- oder Anbieterlink.
- Keine Linkausgabe fuer ungesicherte Aggregator-URLs als offizielle Quelle.
- Keine neue Live-Abhaengigkeit in Tests.
- Wenn ein Roadmap-Punkt abgeschlossen wird, in `Roadmap_archive.md` rotieren und Todo/Handoff aktualisieren.
- Laut Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt; fuer JA-032 wurde `.\ci.cmd supertest` trotzdem erfolgreich ausgefuehrt.
