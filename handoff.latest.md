# Handoff latest

Stand: 2026-09-18T22:53:48.730+02:00

## Zustand

- Active: `TD-0078`
- Status: `in-progress`
- Ziel: M3 - Publikation und Gesamtabnahme: JA-050 Stellenworkflow mit Wachstum, Markierungen und Grenzfaellen abnehmen #comment: Abschluss erfordert belegtes Zusammenspiel von regulaerem Lauf, Suche, Details, persoenlichen Markierungen und erneuter Publikation.
- Branch: `master`
- HEAD: `d4e170c8d362`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `.ci/bin/modules/project-logic.ps1`
- `Roadmap.md`
- `docs/reviews/QA-001-function-inventory.json`
- `docs/test-matrix.json`
- `docs/test-matrix.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

Keine aktive Roadmap-Aufgabe.

## Fortsetzung fuer den naechsten Chat

- Aktiv bleibt `TD-0078` / `JA-050`; kein Roadmap-Punkt ist zur Rotation bereit.
- Teilbild 1 ist abgeschlossen: `tests/Test-JobAgentAcceptance.ps1` prueft den isolierten A/B/D->A/B/C/D-Lauf. Ergebnis: 4 Firmen, 4 historische Stellen, 3 offene Stellen. A1 bleibt aktualisiert, A2 wird nach erfolgreichem Fehlen geschlossen, B1 bleibt bei Quellenfehler erhalten und C1 wird nur browserlokal ausgeblendet.
- Die browserlokalen Orakel pruefen A1 als Favorit, A2 als beworben mit Notiz und offener Nachfassaufgabe, B1 mit beiden Markierungen sowie gespeicherte Suche: C1 vor Ausblendung neu, A1 geaendert, nach Ausblendung keine sichtbare Neuigkeit, nach Sichtung keine offene Neuigkeit.
- Nachweis: `docs/reviews/JA-050-acceptance.md`; Testmatrix und kanonisches Inventar enthalten den Test als erledigten Einzeltest ohne Supertest-Aufnahme.
- Als naechstes Teilbild 2 umsetzen: isolierte Browserfaelle fuer stabile URL, Filter, Pagination, Detail/Quellenlink, beide Sterne, Reload, Navigation, Export/Import, Nulltreffer, Speicherfehler und unbekannte Detail-ID. Kalender, Chronik, Ausblendung und gespeicherte Suche muessen an einer gemeinsamen Generation mit DOM-/Fokusassertions laufen.
- Danach Teilbild 3: lokaler Benchmarkhost fuer 0/1/50/51/121/1000/10000 Stellen, 5 Warmups und 20 Messungen. Akzeptanz: maximal 50 Karten, p95 Filter <=500 ms, erster bedienbarer 10000er-Render <=3 s; Hardware- und Browserversion dokumentieren.
- Supertest ist nicht angefragt und gilt gemaess Nutzerauftrag als erledigt; nicht ausfuehren, sofern kein neuer ausdruecklicher Auftrag erfolgt.
