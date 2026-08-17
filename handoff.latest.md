# Handoff latest

Stand: 2026-08-17T15:39:00+02:00

## Status

- Projekt: JobAgent
- Branch: master
- HEAD vor Commit: `8cdf88e51e45`
- Worktree vor Commit: dirty, alle fachlichen Änderungen werden in den Übergabe-Commit aufgenommen
- Active: _(none)_
- Status: open
- Abgeschlossen und rotiert: JA-013 / TD-0011
- Nächster Einstieg: TD-0012 / JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll

## Abgeschlossen

JA-013 Teststrategie und Supertest für Kernfunktionen konsolidieren ist vollständig erledigt, validiert und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.

Umgesetzt:

- `docs/test-matrix.json`: maschinenlesbare Testmatrix mit `schema_version: jobagent-test-matrix/v1`; ordnet JA-002 bis JA-013 jeweils Roadmap-ID, Titel, Testdatei, Command, Status, Supertest-Aufnahme, Test-Lane und Coverage-Punkte zu.
- `docs/test-matrix.md`: menschlich lesbare Testmatrix mit Testvertrag, Tabelle und expliziter Abgrenzung der späteren Live-Lane.
- `tests/Test-JobAgentTestMatrix.ps1`: neuer Vertragstest für Matrixschema, Abdeckung JA-002 bis JA-013, Existenz aller referenzierten Testdateien, deterministische Commands, Live-Web-Ausschluss in Funktionstests und Synchronität mit `tests/Test-JobAgentSupertest.ps1`.
- `tests/Test-JobAgentSupertest.ps1`: erweitert um `Test-JobAgentTestMatrix.ps1`; der Supertest umfasst jetzt alle abgeschlossenen deterministischen JobAgent-Kernfunktionen JA-002 bis JA-013.
- `Roadmap.md`: JA-013 entfernt; aktiv bleiben JA-014 und JA-015.
- `Roadmap_archive.md`: JA-013 mit Evidence, Tests, Audit und Supertest als abgeschlossen ergänzt.
- `Roadmap_index.md`: aktive Roadmap ab JA-014, Archiv aktuell JA-001 bis JA-013.
- `todo.current.md` / `todo.state.json` / `todo.master.index.json`: TD-0011 erledigt; TD-0012 und TD-0013 offen.
- `todo.checkpoint.json` und `todo.events.jsonl`: STP-/Todo-Zustand aktualisiert.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd runtime-update` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `.\ci.cmd stp` -> Exit 0
- `Invoke-RestMethod http://localhost:9000/api/system/status` -> `UP`
- `.\ci.cmd devserver-status` -> Exit 0, `port=8300`, `listening=True`, URL `http://localhost:8300/`

Hinweis: Der deterministische Supertest bleibt mock-/fixture-basiert. Live-Webrecherche ist bewusst nicht Bestandteil des Supertests und startet erst mit JA-014 als separate Lane.

## Nächste Aufgabe

TD-0012 / JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll durchführen.

Konkreter Einstieg:

1. Kleine Firmenstichprobe aus `data/jobagent/store.json` wählen, nur mit offizieller Karriere-URL und klarer `company_id`.
2. Live-Lane so anbinden, dass jeder Abruf feste Timeouts, User-Agent-Regeln, Retry-Grenzen und vollständige `ScanAttempt`-Logs schreibt.
3. Jede potenzielle Stelle gegen offizielle Detailseite, Zielprofil, Standort und Status prüfen; unklare Treffer nicht als verifiziert ausgeben.
4. Nach dem Pilot Schema-/Deduplikations-Funktionstests ausführen; Live-Pilot weiter getrennt vom Supertest dokumentieren.

No-Gos für den nächsten Chat:

- Keine Jobbörsen oder Aggregatoren als Primärnachweis.
- Keine erfundenen Firmen, Stellen, URLs, IDs, Standorte, Gehälter oder Verifikationsaussagen.
- Keine großflächige Live-Recherche ohne Rate-/Laufzeitgrenzen.
- Keine Bewerbung, Kontaktaufnahme oder externe Schreibaktion.
