# Handoff latest

Stand: 2026-08-17T12:42:00+02:00

## Zustand

- Active: `JA-002`
- Status: `open`
- Ziel: Als naechstes das persistente Datenmodell fuer Firmen, Stellen, Scanlaeufe und Aenderungen definieren.
- Branch: `master`
- HEAD: `siehe git log nach Commit`
- Upstream: `origin/master` nach Remote-Konfiguration
- Ahead/Behind: `1/0 vor erstem Push`
- Worktree: `clean nach Commit erwartet`
- Route: `JA-001 abgeschlossen und archiviert; aktive Roadmap startet praktisch bei JA-002`

## Abgeschlossener Arbeitsschritt

- `manual/PROGRAM.md` wurde vom Platzhalter zum verbindlichen JobAgent-Programmvertrag ausgebaut.
- Der Vertrag definiert Zweck, Zielprofil, Zielgebiet Muenchen/Freising, Quellenprioritaet, ausgeschlossene Quellen, Persistenzpflicht, Statusmodell, Daily Workflow, Deduplikation, Ausgabeformat, Qualitaetssicherung, Betrieb und offene Annahmen.
- Harte No-Gos sind festgehalten: keine Bewerbungen, keine Kontaktaufnahme, keine personenbezogenen Bewerbungsdaten, keine nicht belegten Stellen/Firmen/URLs/Geodaten/Gehaelter/Verifikationsaussagen, keine Primaerbelege aus Aggregatoren.
- `JA-001` wurde aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.
- `Roadmap_index.md` wurde angelegt und verweist auf aktive Roadmap und Archiv.
- `.gitignore` wurde angelegt, damit lokale Logs, Backups, State und CI-Laufzeitverzeichnisse nicht in den Commit geraten.

## Verifikation

- `.\ci.cmd self-check` am 2026-08-17 12:36:08: exit=0, issues=0, Log `logs/terminal/self-check-20260817-123608.log`.
- `.\ci.cmd self-check` am 2026-08-17 12:39:42: exit=0, issues=0, Log `logs/terminal/self-check-20260817-123942.log`.
- Textuelle Contract-Pruefung per `Select-String` auf `IT-Fuehrungspositionen`, `offizielle`, `NEW`, `CLOSED`, `Muenchen`, `Freising`, `keine nicht belegten`: exit=0.
- `.\ci.cmd repin-immutables`: exit=0 nach Aenderung von `manual/PROGRAM.md` und `Roadmap.md`.
- `.\ci.cmd stp`: exit=0, Todo-Rotation lief ohne erledigte Todo-IDs; Roadmap-Rotation wurde manuell als `JA-001`-Archivierung umgesetzt.
- Supertest wurde nicht separat ausgefuehrt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.

## Naechster Anker

1. `JA-002 Persistentes Datenmodell fuer Firmen, Stellen, Scanlaeufe und Aenderungen definieren` bearbeiten.
2. Vor Implementierung technische Speicherentscheidung treffen und dokumentieren: JSON/JSONL oder SQLite. Keine Produktiv-Recherche starten.
3. Schema-Datei anlegen, voraussichtlich `schemas/jobagent.schema.json`, plus Dokumentation `docs/data-model.md`.
4. Pflichtobjekte definieren: Company, Job, JobSource, ScanRun, ScanAttempt, JobSnapshot, ChangeEvent.
5. Funktionstests fuer Schema-Validierung ergaenzen: fehlende `official_url`, fehlende stabile ID, gueltige Beispiele fuer Unternehmen, Job, geaenderten Job und entfernte Stelle.

## Risiken und offene Annahmen

- Das Verzeichnis war initial kein Git-Checkout. `.\ci.cmd stp` hat ein lokales Git-Repository auf `master` sichtbar gemacht, aber ohne Commit und ohne Remote.
- Push ist nur moeglich, wenn `origin` korrekt auf `https://github.com/randolph27/JobAgent.git` gesetzt wird und Credentials verfuegbar sind.
- Remote `ls-remote --heads https://github.com/randolph27/JobAgent.git` lieferte keine Branch-Ausgabe. Das kann ein leeres Repository oder fehlende Sichtbarkeit bedeuten.
- Nicht force-pushen. Wenn Push nach `master` abgelehnt wird, neuen Branch verwenden oder Remote-Zustand im neuen Chat klaeren.
