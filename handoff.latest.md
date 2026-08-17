# Handoff latest

Stand: 
2026-08-17T13:16:30+02:00

## Zustand

- Active: _(none)_
- Status: `open`
- Ziel: Naechster Arbeitsschritt ist `TD-0002 / JA-004 Firmeninventar-Seed und Erweiterungsstrategie fuer Muenchen/Freising erstellen`.
- Branch: `master`
- HEAD vor Commit: `c9ef2221683d`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `JA-001` bis `JA-003` sind abgeschlossen und archiviert; aktive Roadmap startet bei `JA-004`.

## Abgeschlossener Arbeitsschritt

- `JA-003 Speicher- und Migrationsschicht fuer idempotente Daily-Runs implementieren` ist abgeschlossen.
- `src/JobAgent.Persistence.psm1` implementiert Store-Pfade, leeren `jobagent/v1`-Store, Lesen, Validieren, atomares Schreiben, exklusives Locking, Backups und Migration von `jobagent/v0` nach `jobagent/v1`.
- Repository-Funktionen vorhanden: `Upsert-JobAgentCompany`, `Upsert-JobAgentJobSource`, `Upsert-JobAgentScanRun`, `Upsert-JobAgentJobSnapshot`, `Record-JobAgentScanAttempt`, `Mark-JobAgentMissingJobs`, `Get-JobAgentDailyOutputCandidates`.
- `docs/data-model.md` dokumentiert Persistenzentscheidung, Pfadvertrag, Recovery und Repository-API.
- `Roadmap.md` wurde bereinigt; `JA-003` wurde nach `Roadmap_archive.md` rotiert.
- `todo.state.json` und `todo.current.md` starten jetzt bei `TD-0002 / JA-004`.
- `todo-prune` hat das erledigte JA-003-Event nach `logs/todo/done-events-20260817-131547.jsonl` verschoben.

## Neue Dateien

- `src/JobAgent.Persistence.psm1`
- `tests/Test-JobAgentPersistence.ps1`

## Geaenderte Zustandsdateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-131518.log`
- `.\ci.cmd stp` -> Exit `0`

## Supertest-Hinweis

- Nicht angefragt; laut Nutzeranweisung gilt Supertest als erledigt. Der fachliche Abschluss wurde mit fokussierten Funktionstests validiert.

## Offene Aufgaben

1. `TD-0002 / JA-004 Firmeninventar-Seed und Erweiterungsstrategie fuer Muenchen/Freising erstellen`
   - Persistentes Firmeninventar auf Basis der neuen Store-API erstellen.
   - Pro Firma speichern: offizielle Website, Karriere-URL, Standortbezug, Branche, Aliasnamen, Scanprioritaet, Status und naechster geplanter Scanzeitpunkt.
   - Deduplikation ueber kanonischen Namen, Domain, Rechtsformnormalisierung, Aliasliste und vorsichtige Konzern-/Tochter-Regeln implementieren.
   - Keine Firma als offiziell verifiziert markieren, solange keine offizielle Unternehmensquelle belegt ist.
   - Funktionstests fuer identische Domain, Namensvariante mit Rechtsform, getrennte Tochtergesellschaft, fehlende Karriere-URL und erneute Seed-Ausfuehrung ohne Duplikate erstellen.
2. Danach `JA-005` Quellenadapter-Vertrag fuer Karriereseiten und ATS-Systeme.
3. Danach `JA-006` offizielle Quellenverifikation und URL-Kanonisierung.

## Risiken und Annahmen

- Dateibasierte Persistenz ist fuer lokale Einzellaeufe ausgelegt; bei groesserer Live-Abdeckung kann eine SQLite-Migration sinnvoll werden.
- Noch keine Firmen-, Quellenadapter-, Deduplikations-, Statusmaschinen- oder Daily-Run-Implementierung.
- Keine Live-Recherche starten, bevor Quellenverifikation, Adaptervertrag und Deduplikation stehen.
- Keine Firmen, Stellen, URLs, Geodaten oder Gehaelter erfinden; unbekannte Angaben als `UNKNOWN` oder `TODO` modellieren.
