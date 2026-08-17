# Roadmap Archive

## Archiviert am 2026-08-17

- [x] JA-009 Statusmaschine für Daily-Run-Ergebnisse und Änderungsverlauf bauen #comment: Neue, aktive, geänderte und entfernte Stellen müssen deterministisch aus Scanresultaten und Historie entstehen.
  - [x] Beschreibung: `src/JobAgent.StatusMachine.psm1` verarbeitet Adapter-Ergebnisse eines Laufes, vergleicht Rohjobs mit der Historie, aktualisiert `first_seen`/`last_seen`/`changed_at`, erzeugt JobSnapshots und schreibt ChangeEvents fuer neue, aktive, geaenderte, entfernte und invalide Treffer.
  - [x] Scope: Erstellt wurden `src/JobAgent.StatusMachine.psm1` und `tests/Test-JobAgentStatusMachine.ps1`; erweitert wurden `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Live-Webrecherche, keine Daily-Run-Orchestrierung, keine Reportausgabe.
  - [x] Ist-Stand (2026-08-17 15:05): Statusmaschine deckt `NEW -> ACTIVE -> UPDATED -> REMOVED` ab, protokolliert invalide Rohjobs als `JOB_INVALIDATED` und entfernt Jobs nur bei erfolgreichem autoritativem Firmenlauf.
  - [x] Abhängigkeiten: JA-003, JA-007 und JA-008 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 78/100, weil Daily-Run und Bericht nun eine deterministische Zustands- und Ereignislogik nutzen koennen.
  - [x] Risiken: `CLOSED` bleibt fuer spaetere explizite Quellenhinweise reserviert; nicht mehr gefundene Stellen werden aktuell als `REMOVED` markiert. Autoritative Leerscans duerfen nur von `SUCCESS`/`NONE`-Adapterergebnissen kommen.
  - [x] Schritte:
    1. Mehrlauf-Verarbeitung mit Deduplikationsentscheidung, stabilen Job-IDs, Snapshot-Erzeugung und ScanAttempt-Protokoll umgesetzt.
    2. Statusuebergaenge fuer neue, unveraenderte, geaenderte, fehlerhafte, leere erfolgreiche und invalide Treffer implementiert.
    3. ChangeEvent-Ausgabe mit alten/neuen Statuswerten, konkreten `changed_fields`, Zeitpunkt, ScanRun und Begruendung erstellt.
  - [x] Evidence: `src/JobAgent.StatusMachine.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` exit=0; `git -c core.pager=cat -c color.ui=false --no-pager diff --check` exit=0.
  - [x] Audit: Tests pruefen, dass `first_seen` stabil bleibt, `last_seen` nur bei Wiedererkennung aktualisiert wird, fehlgeschlagene Scans keine Entfernung ausloesen und invalide Rohjobs nicht als Job gespeichert werden.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; Statusmaschine ist im fachlichen Supertest gebuendelt.

- [x] JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren #comment: Bekannte Stellen dürfen bei späteren Läufen nicht erneut als `NEW` erscheinen, auch wenn Titel oder URL-Parameter variieren.
  - [x] Beschreibung: `src/JobAgent.Deduplication.psm1` implementiert stabile Jobidentitaeten mit Prioritaet offizielle Job-ID, ATS-ID, kanonische URL und zusammengesetzter Fingerprint; bekannte Stellen werden als `KNOWN` oder `UPDATED` statt erneut als `NEW` erkannt.
  - [x] Scope: Erstellt wurden `src/JobAgent.Deduplication.psm1` und `tests/Test-JobAgentDeduplication.ps1`; erweitert wurden `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Zusammenfuehrung getrennter Stellen ohne belastbare Identitaet, keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 14:21): Deduplikation erkennt dieselbe Stelle im zweiten Lauf, priorisiert offizielle Job-ID vor ATS-ID und kanonischer URL, nutzt alternative offizielle URLs und trennt echte Neuausschreibungen mit neuer ID und neuer URL.
  - [x] Abhängigkeiten: JA-002, JA-003, JA-006 und JA-007 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 80/100, weil Dublettenvermeidung nun vor Statusmaschine, Daily-Run und Report deterministisch verfuegbar ist.
  - [x] Risiken: Der zusammengesetzte Fingerprint bleibt bewusst konservativ; wenn eine Stelle gleichzeitig neue starke Identitaeten und gleiche weiche Merkmale besitzt, wird sie nicht automatisch zusammengefuehrt. JA-009 muss daraus spaeter ChangeEvents und Statusuebergaenge ableiten.
  - [x] Schritte:
    1. Identitaetskandidaten mit geordneten Keys fuer `OFFICIAL_JOB_ID`, `ATS_JOB_ID`, `CANONICAL_URL` und `COMPOSITE_FINGERPRINT` implementiert.
    2. Wiedererkennung gegen bestehende Jobs inklusive `alternative_official_urls`, URL-Kanonisierung, geaenderter Titel und geaenderter Job-ID umgesetzt.
    3. Entscheidungsobjekt mit `decision`, `job_id`, `identity_basis`, `confidence`, `changed_fields` und `reason` fuer die spaetere Statusmaschine bereitgestellt.
  - [x] Evidence: `src/JobAgent.Deduplication.psm1`, `tests/Test-JobAgentDeduplication.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` exit=0; `git -c core.pager=cat -c color.ui=false --no-pager diff --check` exit=0.
  - [x] Audit: Tests decken zweiten Lauf derselben Stelle, offizielle Job-ID-Prioritaet, Job-ID-Wechsel bei gleicher kanonischer URL, URL-Parameter-Kanonisierung, Titelwechsel, alternative offizielle URL und echte Neuausschreibung mit neuer ID plus neuer URL ab.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; JobAgent-Funktionstests fuer Schema, Persistenz, Firmeninventar, Quellenadapter, Quellenverifikation, Klassifikation und Deduplikation sind gebuendelt.

- [x] JA-007 Stellenklassifikation für IT-Führungspositionen entwickeln #comment: Nur echte IT-Führungsrollen im Zielgebiet sollen als passende Treffer erscheinen.
  - [x] Beschreibung: `src/JobAgent.Classification.psm1` implementiert eine regelbasierte, nachvollziehbare Bewertung fuer Titel, Beschreibung, Fuehrungsverantwortung, IT-Gesamtverantwortung, Standort, Vollzeitbezug und Arbeitsmodell.
  - [x] Scope: Erstellt wurden `src/JobAgent.Classification.psm1`, `tests/Test-JobAgentClassification.ps1` und `tests/Test-JobAgentSupertest.ps1`; erweitert wurde `docs/data-model.md`. Keine automatische Bewerbung, keine Speicherung unnoetiger persoenlicher Daten und keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 14:30): Klassifikation liefert `MATCH`, `POSSIBLE` oder `REJECTED` mit Score, Prioritaet, Gruenden, Ausschlussgruenden und Zeitstempel; starke IT-Leitungsrollen, Remote-Deutschland-Bezug und Ausschluesse fuer Entwickler-, Projektleitungs- und Teamlead-Grenzfaelle sind getestet.
  - [x] Abhängigkeiten: JA-001, JA-002 und JA-005 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 82/100, weil Trefferqualitaet nun durch belegte positive Fuehrungssignale und fail-closed Ausschluesse unpassender Rollen abgesichert ist.
  - [x] Risiken: Regelbasierte Klassifikation bleibt bewusst konservativ; mehrdeutige Titel wie `IT Manager` werden als `POSSIBLE` statt als verifizierter Match markiert, bis Deduplikation/Status/Report mehr Kontext liefern.
  - [x] Schritte:
    1. Positive Signale fuer CIO, Head/Director/Leiter IT, IT-Gesamtverantwortung, Budget-/Personalverantwortung und strategische IT-Verantwortung implementiert.
    2. Negative Signale fuer Entwickler-, Spezialisten-, Consultant-, Administrator-, Projektleitungs- und Teamlead-Rollen ohne belegte Gesamt- oder Strategie-Verantwortung implementiert.
    3. Erklaerbare Bewertung mit Ergebnis, Score, Prioritaet, Gruenden und Ausschlussgruenden fuer spaetere Daily-Reports umgesetzt.
  - [x] Evidence: `src/JobAgent.Classification.psm1`, `tests/Test-JobAgentClassification.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentClassification.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests decken deutsche/englische Titel, leeren Titel, Entwickler-Ausschluss, Projektleitungs-Ausschluss, Teamlead-Ausschluss, unklaren Standort, Zielgebiet, ausserhalb Zielgebiet, Remote-Deutschland-Bezug und grenzwertigen `IT Manager` ab.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; JobAgent-Funktionstests fuer Schema, Persistenz, Firmeninventar, Quellenadapter, Quellenverifikation und Klassifikation sind gebuendelt.

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
