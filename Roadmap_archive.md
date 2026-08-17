# Roadmap Archive

## Archiviert am 2026-08-17

- [x] JA-003 Speicher- und Migrationsschicht für idempotente Daily-Runs implementieren #comment: Der Agent braucht eine wiederverwendbare lokale Datenbasis, die Läufe deterministisch fortsetzen und Änderungen nachvollziehbar speichern kann.
  - [x] Beschreibung: `src/JobAgent.Persistence.psm1` implementiert eine lokale Persistenzschicht für `jobagent/v1` mit atomaren Schreibvorgängen, exklusivem Locking, Backups, Migrationspfad und Repository-Funktionen für Unternehmen, Quellen, Stellen, Scanläufe, Scanversuche, Snapshots, ChangeEvents und Daily-Output-Kandidaten.
  - [x] Scope: Erstellt wurden `src/JobAgent.Persistence.psm1` und `tests/Test-JobAgentPersistence.ps1`; ergänzt wurde `docs/data-model.md`; produktive Runtime-Daten werden nur unter `data/jobagent/` erwartet, Funktionstests nutzen temporäre Projektwurzeln.
  - [x] Ist-Stand (2026-08-17 13:35): Persistenz ist implementiert und fokussiert getestet; es gibt noch keinen Daily-Run-Orchestrator und keine Live-Recherche.
  - [x] Abhängigkeiten: JA-002 ist abgeschlossen; JSON-Datei unter `data/jobagent/store.json` wurde als erste Persistenztechnologie dokumentiert.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 96/100, weil idempotente Läufe, Historie und spätere Crawler nun eine wiederverwendbare Store-API haben.
  - [x] Risiken: Datei-Persistenz ist für lokale Einzelläufe ausgelegt; spätere größere Live-Abdeckung kann eine SQLite-Migration erfordern. Repository-Funktionen speichern nur übergebene validierte Daten und erzeugen keine Firmen- oder Stellenfakten.
  - [x] Schritte:
    1. Lade-, Speicher- und Validierungsfunktionen für den `jobagent/v1`-Root-Store implementiert.
    2. Atomare Schreibstrategie mit temporärer Datei, best-effort Flush, Backup vor Migration/Write und Recovery-Dokumentation ergänzt.
    3. Repository-Methoden `Upsert-JobAgentCompany`, `Upsert-JobAgentJobSnapshot`, `Record-JobAgentScanAttempt`, `Mark-JobAgentMissingJobs` und `Get-JobAgentDailyOutputCandidates` erstellt.
  - [x] Evidence: `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentPersistence.ps1`, `docs/data-model.md`; Testausgabe enthält Fälle `empty_store`, `write_reload`, `idempotent_upsert`, `backup`, `migration`, `corrupt_store`, `lock_violation`, `path_guard`, `missing_jobs`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests schreiben ausschließlich in temporäre Verzeichnisse; Pfadschutz blockiert Store-Pfade außerhalb des Projektverzeichnisses; produktive JobAgent-Daten und CI-Todos bleiben getrennt.
  - [x] Supertest: Nicht ausgeführt; der Nutzer hat funktionsbezogene Tests priorisiert und der bestehende Projekt-Supertest ist noch nicht auf den fachlichen JobAgent-Stack zugeschnitten.

- [x] JA-002 Persistentes Datenmodell für Firmen, Stellen, Scanläufe und Änderungen definieren #comment: Stabile Identitäten und Historie sind der kritische Pfad, damit tägliche Läufe nicht dieselben Stellen erneut als neu melden.
  - [x] Beschreibung: `schemas/jobagent.schema.json` definiert ein versioniertes Domain-Schema `jobagent/v1` für Company, Job, JobSource, ScanRun, ScanAttempt, JobSnapshot und ChangeEvent mit stabilen IDs, Zeitstempeln, Statuswerten, Herkunftsfeldern und Validierungsregeln.
  - [x] Scope: Erstellt wurden `schemas/jobagent.schema.json`, `docs/data-model.md`, `tests/Test-JobAgentSchema.ps1` und Fixture-Dateien unter `tests/fixtures/jobagent/`; keine Webrecherche, kein produktiver Crawl, keine personenbezogenen Bewerbungsdaten.
  - [x] Ist-Stand (2026-08-17 12:58): Fachliches JSON-Schema, Datenmodelldokumentation und fokussierte Schema-Funktionstests existieren; produktive Persistenz ist bewusst noch nicht implementiert.
  - [x] Abhängigkeiten: JA-001 ist abgeschlossen; offene Persistenzimplementierung bleibt JA-003.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 98/100, weil JA-003 und alle späteren Quellen-, Deduplikations- und Statusfunktionen nun einen stabilen Datenvertrag haben.
  - [x] Risiken: Die endgültige Persistenztechnologie bleibt für JA-003 offen; spätere SQLite-/JSONL-Implementierungen müssen `jobagent/v1` migrieren oder kompatibel abbilden.
  - [x] Schritte:
    1. Pflichtfelder für Unternehmen, offizielle Quellen, Scanläufe, Scanversuche, Jobs, Snapshots und ChangeEvents im Schema definiert.
    2. Statuswerte `NEW`, `ACTIVE`, `UPDATED`, `CLOSED`, `REMOVED`, `INVALID` sowie Scanstatus, Fehlerklassen, Prioritäten und Klassifikationsergebnisse festgelegt.
    3. Dokumentation mit Speicherentscheidung, Identitätspriorität, Beispieldokument und Negativregeln ergänzt.
  - [x] Evidence: `schemas/jobagent.schema.json`, `docs/data-model.md`, `tests/fixtures/jobagent/valid.json`, `tests/fixtures/jobagent/invalid-missing-official-url.json`, `tests/fixtures/jobagent/invalid-missing-job-id.json`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `npx --yes --package ajv-cli@5 --package ajv-formats ajv validate -s schemas\jobagent.schema.json -d tests\fixtures\jobagent\valid.json --spec=draft2020 -c ajv-formats` exit=0; `.\ci.cmd self-check` exit=0.
  - [x] Audit: Keine Felder erzwingen personenbezogene Bewerbungsdaten; fehlende optionale Informationen werden mit `UNKNOWN` modelliert; `JobSource` akzeptiert nur offizielle Quellen.
  - [x] Supertest: Nicht ausgeführt; JA-013 bündelt abgeschlossene Funktionsbereiche später in einen projektspezifischen Supertest.

- [x] JA-001 Programmvertrag und Akzeptanzkriterien für den JobAgent verbindlich festlegen #comment: Der fachliche Auftrag aus dem Nutzerbriefing wurde in eine prüfbare Projektanweisung übersetzt, bevor Code oder Datenbankstruktur entstehen.
  - [x] Beschreibung: `manual/PROGRAM.md` enthält den Zweck des JobAgent, das Zielprofil für IT-Fuehrungspositionen, das Zielgebiet Muenchen 20 km/Freising, erlaubte Quellen, ausgeschlossene Quellen, Laufmodus, Persistenzpflichten, Ausgabeformat und harte No-Gos; jede Anforderung ist als überprüfbare Muss-/Soll-/Darf-nicht-Regel formuliert.
  - [x] Scope: Bearbeitet wurde `manual/PROGRAM.md`; keine CI-Runtime-Dateien wurden fachlich geändert; keine Recherchelogik wurde in Dokumentationsdateien implementiert.
  - [x] Ist-Stand (2026-08-17 12:36): `manual/PROGRAM.md` ist kein Platzhalter mehr, sondern enthält den verbindlichen JobAgent-Programmvertrag.
  - [x] Abhängigkeiten: README-Regeln, Nutzerauftrag, Roadmap und Bootstrap-Dateien wurden berücksichtigt; keine fachlichen Vorarbeiten waren erforderlich.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 100/100, weil ohne verbindlichen Programmvertrag alle nachfolgenden Datenmodelle, Tests und Crawler spekulativ wären.
  - [x] Risiken: Persistenztechnologie, Firmen-Seedliste, Geodistanzlogik, konkrete ATS-Systeme und Scheduler bleiben als `UNKNOWN` in `manual/PROGRAM.md` dokumentiert.
  - [x] Schritte:
    1. Nutzerauftrag in `manual/PROGRAM.md` strukturiert nach Zweck, Zielprofil, Zielgebiet, Quellenpriorität, Persistenz, Statusmodell, Daily Workflow, Deduplikation, Ausgabeformat, Qualitätssicherung, Betrieb und offenen Annahmen.
    2. Akzeptanzkriterien ergänzt, u.a. keine Treffer ohne offizielle URL, keine erfundenen Daten, keine erneute `NEW`-Ausgabe bekannter unveränderter Stellen und kein automatisches Schließen bei Scanfehlern.
    3. Offene technische Entscheidungen als `UNKNOWN` dokumentiert, statt Datenbanktyp, Scheduler oder ATS-Abdeckung zu erfinden.
  - [x] Evidence: `manual/PROGRAM.md` enthält die fachlichen Pflichtabschnitte; `logs/terminal/self-check-20260817-123608.log` belegt grüne Basisprüfung; Kernbegriffsuche bestätigte `IT-Fuehrungspositionen`, `offizielle`, `NEW`, `CLOSED`, `Muenchen`, `Freising`, `keine nicht belegten`.
  - [x] Funktionstest: `.\ci.cmd self-check` lief mit exit=0 und issues=0; textuelle Contract-Prüfung per `Select-String` auf Kernbegriffe lief mit exit=0.
  - [x] Audit: Keine widersprüchlichen Regeln zu Quellen, Statuswerten oder Zielgebiet im Programmvertrag festgestellt; nicht belegbare Informationen sind verboten oder als `UNKNOWN` markiert.
  - [x] Supertest: Vom Nutzer nicht angefragt; gemäß Nutzeranweisung für diesen Abschluss als erledigt gewertet, ohne separaten Lauf.
