# Roadmap Archive

## Archiviert am 2026-08-17

- [x] JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren #comment: Jeder Treffer muss auf eine offizielle Unternehmens- oder offiziell angebundene Recruiting-Seite zurückführbar sein.
  - [x] Beschreibung: `src/JobAgent.SourceVerification.psm1` implementiert URL-Kanonisierung, offizielle Quellenbewertung gegen Firmendomain, Karriere-URL und firmengebundene ATS-Domains sowie fail-closed Erzeugung offizieller `JobSource`-Objekte.
  - [x] Scope: Erstellt wurden `src/JobAgent.SourceVerification.psm1` und `tests/Test-JobAgentSourceVerification.ps1`; erweitert wurden `schemas/jobagent.schema.json`, `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`, Fixtures und `docs/data-model.md`. Keine pauschale globale ATS-Allowlist ohne Firmenbindung, keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 13:58): Offizielle Quellen werden gegen Company-Domain, Career-URL oder `Company.ats.official_domain` validiert; StepStone, Indeed, LinkedIn, XING, Kununu und Glassdoor werden als Primaerquelle abgelehnt; alternative offizielle URLs sind im Job-Schema modelliert.
  - [x] Abhängigkeiten: JA-002, JA-004 und JA-005 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 84/100, weil falsche Quellen nun fail-closed als `INVALID` oder `UNVERIFIED` markiert werden, bevor sie als Treffer gespeichert werden koennen.
  - [x] Risiken: Redirect-Verifikation bleibt ohne Live-Lane auf die kanonische Ziel-URL beschraenkt; echte ATS-Domains muessen pro Firma belegt in `Company.ats` gepflegt werden.
  - [x] Schritte:
    1. `Get-JobAgentOfficialSourceEvaluation` fuer Company-Domain, Karriere-URL und firmenbezogene ATS-Domain umgesetzt.
    2. `ConvertTo-JobAgentCanonicalUrl` entfernt Tracking-, Session- und Fragmentbestandteile, erhaelt aber jobrelevante Parameter wie `jobId`.
    3. `Resolve-JobAgentOfficialJobUrl` speichert primaere offizielle URL und gefilterte alternative offizielle URLs; Aggregatoren und unbekannte Drittquellen werden nicht als Treffer akzeptiert.
  - [x] Evidence: `src/JobAgent.SourceVerification.psm1`, `tests/Test-JobAgentSourceVerification.ps1`, `schemas/jobagent.schema.json`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` exit=0.
  - [x] Audit: Tests decken Firmendomain, Subdomain, Karriere-URL, firmengebundene ATS-Domain, Trackingparameter, Sessionparameter, StepStone/Indeed/LinkedIn/XING/Kununu/Glassdoor-Ablehnung und alternative offizielle URLs ab.
  - [x] Supertest: `.\ci.cmd supertest` ausgefuehrt, exit=1 wegen bestehender Projekt-CI-Blocker `Directory ... does not contain a Gradle build` und fehlendem lokalen `sonar.cmd`; die fachlichen JA-006-Funktionstests sind gruen.

- [x] JA-005 Quellenadapter-Vertrag für Karriereseiten und ATS-Systeme definieren #comment: Offizielle Quellen haben unterschiedliche technische Formen; ein einheitlicher Adaptervertrag verhindert Sonderlogik im Daily-Workflow.
  - [x] Beschreibung: `src/JobAgent.SourceAdapters.psm1` definiert einen Adaptervertrag fuer offizielle Karrierequellen mit validiertem Input, Rohjob-Output, persistierbarem `ScanAttempt`, Fehlerklassen, Retry-Empfehlungen und lokalen Nachweisartefakten.
  - [x] Scope: Erstellt wurden `src/JobAgent.SourceAdapters.psm1` und `tests/Test-JobAgentSourceAdapters.ps1`; erweitert wurden `schemas/jobagent.schema.json`, `tests/Test-JobAgentSchema.ps1` und `docs/data-model.md`. Keine Live-Webrecherche, keine Login-/Captcha-/ToS-Umgehung, keine Jobboerse als Primaerquelle.
  - [x] Ist-Stand (2026-08-17 13:41): Adaptervertrag, Fixture-Adapter und generischer HTML-Fixture-Adapter sind implementiert; Rohjobs werden noch nicht als verifizierte Jobs persistiert, weil JA-006 URL-Verifikation und Kanonisierung noch offen ist.
  - [x] Abhängigkeiten: JA-001 bis JA-004 sind abgeschlossen; der Adaptervertrag nutzt `Company`, `JobSource`, `ScanAttempt` und `jobagent/v1`.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 86/100, weil offizielle Quellen nun einheitlich und testbar an spätere Verifikation, Klassifikation und Daily-Runs angebunden werden koennen.
  - [x] Risiken: Der generische HTML-Adapter ist bewusst nur fuer statische Link-Fixtures geeignet; dynamische ATS-Systeme, Redirect-Verifikation und URL-Kanonisierung bleiben Folgepunkte. Leere oder fehlerhafte Adapterlaeufe schliessen keine bestehenden Jobs.
  - [x] Schritte:
    1. Adapter-Input fuer Company, offizielle JobSource, Scan-Kontext, Timeout, Ergebnisbudget und Suchbegriffe umgesetzt.
    2. Adapter-Output mit Rohjobs, offizieller Quell-URL, Extraktionsvertrauen, `ScanAttempt`, Fehlerklasse und Retry-Empfehlung implementiert.
    3. Fixture-Adapter und generischen HTML-Link-Extraktor erstellt; Fehlerfaelle fuer leeres HTML, keine Treffer und nicht-offizielle Quelle getestet.
  - [x] Evidence: `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentSourceAdapters.ps1`, `schemas/jobagent.schema.json`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0.
  - [x] Audit: Tests blockieren nicht-offizielle Quellen, validieren absolute Detail-URLs, erzeugen persistierbare ScanAttempts und bewerten leere Trefferlisten als `NO_JOBS_FOUND` statt als Entfernen von Stellen.
  - [x] Supertest: Nicht ausgeführt; der bestehende Projekt-Supertest ist noch nicht fachlich auf JobAgent-Funktionstests zugeschnitten und JA-013 bündelt abgeschlossene Kernfunktionen später.

- [x] JA-004 Firmeninventar-Seed und Erweiterungsstrategie für München/Freising erstellen #comment: Eine breite, dauerhaft gepflegte Unternehmensbasis entscheidet über Trefferqualität und darf nicht täglich neu generiert werden.
  - [x] Beschreibung: `src/JobAgent.CompanyInventory.psm1` liefert ein initiales Firmeninventar für Muenchen/Freising mit offiziellen Websites, Karriere-URLs, Standortbezug, Branche, Aliasnamen, Scanprioritaet, naechstem Scanzeitpunkt, Discovery-Quelle und Verifikationsstatus; `tools/Seed-JobAgentCompanies.ps1` schreibt den Seed transaktional in `data/jobagent/store.json`.
  - [x] Scope: Erstellt wurden `src/JobAgent.CompanyInventory.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tools/Seed-JobAgentCompanies.ps1` und `data/jobagent/store.json`; erweitert wurden `schemas/jobagent.schema.json`, `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`, `tests/fixtures/jobagent/valid.json` und `docs/data-model.md`.
  - [x] Ist-Stand (2026-08-17 13:25): Seed- und Deduplikationslogik ist implementiert; der produktive Store enthaelt 12 Firmen und 12 offizielle Karrierequellen; keine Live-Jobrecherche wurde gestartet.
  - [x] Abhängigkeiten: JA-001 bis JA-003 sind abgeschlossen; der Seed nutzt den `jobagent/v1`-Store und die vorhandene transaktionale Persistenz.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 88/100, weil nach Persistenz nun die erste systematische Quellenbasis fuer Adapter, Verifikation und Daily-Run vorhanden ist.
  - [x] Risiken: Karriere-URLs koennen sich aendern; die Seed-Liste ist ein initialer Bestand und behauptet keine vollstaendige Marktabdeckung. Firmen ohne Karriere-URL werden unterstuetzt, erzeugen aber keine offizielle `JobSource`.
  - [x] Schritte:
    1. Firmen-Seedmodell mit offiziellen Website-/Karriere-URLs, Branchen, Zielgebiet, Aliasnamen, Scanprioritaet und Discovery-Quelle umgesetzt.
    2. Deduplikation ueber `company_id`, kanonische Domain, rechtsformnormalisierten Namen und Aliasnamen implementiert; Konzern-/Tochtergesellschaften werden nicht allein wegen gemeinsamer Wortbestandteile zusammengefuehrt.
    3. Seed-Skript erstellt und ausgefuehrt; der lokale Store wurde idempotent mit 12 Firmen und 12 Quellen gefuellt.
  - [x] Evidence: `src/JobAgent.CompanyInventory.psm1`, `tools/Seed-JobAgentCompanies.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `data/jobagent/store.json`, `logs/jobagent/company-seed-20260817-112503.json`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests decken identische Domain, Rechtsformvariante, getrennte Tochtergesellschaften, fehlende Karriere-URL und idempotente erneute Seed-Ausfuehrung ab; `.\ci.cmd self-check` exit=0.
  - [x] Supertest: Nicht ausgeführt; gemaess Nutzeranweisung wurden nur funktionsbezogene Tests genutzt, bis ein Roadmap-Punkt vollstaendig abgeschlossen ist.

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
