# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, tägliche Läufe zunächst manuell oder per lokalem Scheduler, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: aktuell Bootstrap-/CI-Gerüst, fachliche JobAgent-Implementierung noch aufzubauen; konkrete Programmiersprache, Persistenztechnologie und Testframework sind noch nicht final festgelegt.
- Priorisierung: zuerst persistente Verträge und Datenmodelle, danach idempotente Laufsteuerung, danach Quellen-/Crawler-Adapter, Matching, Statuslogik, Ausgabe, Automatisierung und Qualitätssicherung.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis.

## M2 - Quelleninventar und offizielle Verifikation

- [ ] JA-004 Firmeninventar-Seed und Erweiterungsstrategie für München/Freising erstellen #comment: Eine breite, dauerhaft gepflegte Unternehmensbasis entscheidet über Trefferqualität und darf nicht täglich neu generiert werden.
  - [ ] Beschreibung: Erstelle ein initiales, persistentes Inventar relevanter Arbeitgeber mit offizieller Website, Karriere-URL, Standortbezug, Branche, Aliasnamen und Scanpriorität; Erweiterungen werden dedupliziert und als neue Firmen nachvollziehbar protokolliert.
  - [ ] Scope: Firmeninventar-Daten, Discovery-Regeln, Tests für Firmen-Deduplikation; keine Behauptung, dass alle Firmen bereits vollständig oder aktuell geprüft sind.
  - [ ] Ist-Stand (2026-08-17 12:20): Es existiert kein fachliches Firmeninventar; der Auftrag fordert langfristig möglichst vollständige Abdeckung.
  - [ ] Abhängigkeiten: JA-002 und JA-003; optional JA-001 für verbindliche Branchen- und Quellenregeln.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-5 PT für initiale Struktur und erste Seed-Daten; laufende Erweiterung dauerhaft.
  - [ ] Prioritätsscore: 88/100, weil ohne Firmenliste keine systematische Quellabdeckung entsteht.
  - [ ] Risiken: Firmen können über Tochtergesellschaften, Holdings und unterschiedliche Rechtsformen mehrfach erscheinen; unklare Karriere-URLs dürfen nicht als verifiziert gelten.
  - [ ] Schritte:
    1. Definiere Seed-Kriterien für große Arbeitgeber, regionale Unternehmen, Konzerne, Mittelstand, öffentliche/staatnahe Arbeitgeber und Branchen mit eigener IT-Abteilung im Zielgebiet.
    2. Implementiere Firmen-Deduplikation über kanonischen Namen, Domain, Rechtsformnormalisierung, Aliasliste und vorsichtige Konzern-/Tochter-Regeln.
    3. Speichere pro Firma Scanpriorität, Discovery-Quelle, offizielle Karriere-URL, ATS-Hinweis, Status und nächsten geplanten Scanzeitpunkt.
  - [ ] Evidence: Persistentes Firmeninventar mit validiertem Schema; Log der erstmalig hinzugefügten Firmen; Deduplikationsbericht für Alias-/Domain-Kollisionen.
  - [ ] Funktionstest: Tests für identische Domain, Namensvariante mit Rechtsform, getrennte Tochtergesellschaft, fehlende Karriere-URL und erneute Seed-Ausführung ohne Duplikate.
  - [ ] Audit: Stichprobe prüfen, dass Firmen nicht aus Jobbörsen als offiziell verifiziert markiert werden, solange keine offizielle Unternehmensquelle vorhanden ist.
  - [ ] Supertest: Nach grünen Inventar- und Deduplikationstests in Daily-Run-Supertest aufnehmen.

- [ ] JA-005 Quellenadapter-Vertrag für Karriereseiten und ATS-Systeme definieren #comment: Offizielle Quellen haben unterschiedliche technische Formen; ein einheitlicher Adaptervertrag verhindert Sonderlogik im Daily-Workflow.
  - [ ] Beschreibung: Definiere eine Adapter-Schnittstelle, die offizielle Unternehmensseiten und offiziell verlinkte ATS-Systeme durchsucht, Rohstellen extrahiert, Fehler klassifiziert und Quellnachweise liefert.
  - [ ] Scope: Adapter-Interfaces, Fehlerklassen, Rate-Limits, Retry-Regeln, Tests mit lokalen Fixtures; keine Umgehung von Logins, Paywalls, Captchas oder robots/ToS-Grenzen.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Crawler- oder Adapterlogik vorhanden.
  - [ ] Abhängigkeiten: JA-001 Quellenregeln, JA-002 Datenfelder, JA-003 Persistenz.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-4 PT für Vertrag und erste generische Adapter; weitere ATS-Adapter separat.
  - [ ] Prioritätsscore: 86/100, weil Verifikation nur über offizielle Quellen belastbar ist.
  - [ ] Risiken: Seitenstrukturänderungen, dynamisches Rendering, Captchas und fehlerhafte ATS-Suchen können False Negatives erzeugen.
  - [ ] Schritte:
    1. Lege Adapter-Input und -Output fest: Company, Karriere-URL, Suchbegriffe, Scan-Kontext, gefundene Rohjobs, offizielle URL, Extraktionsvertrauen, Fehler und Retry-Empfehlung.
    2. Implementiere mindestens einen generischen HTML-/Suchseiten-Adapter und einen Fixture-basierten Testadapter, der keine externe Website benötigt.
    3. Definiere Fehlercodes für nicht erreichbar, Timeout, blockiert, keine Jobs gefunden, unklare Quelle, Parsingfehler und technische Einschränkung.
  - [ ] Evidence: Adaptervertrag dokumentiert; Fixtures mit offiziellen Beispielstrukturen; ScanAttempt-Logs zeigen Erfolg und Fehler deterministisch.
  - [ ] Funktionstest: Fixture-Tests für statische Karriereseite, ATS-Listing, Detailseite, Timeout-Simulation, unklare Quelle und leere Trefferliste.
  - [ ] Audit: Prüfen, dass Adapter keine Jobbörse als Primärquelle akzeptieren und externe Probleme nicht als Nichtvorhandensein von Stellen bewerten.
  - [ ] Supertest: Nach Adaptertests in Supertest aufnehmen, externe Live-Crawls nur als gesonderte optionale Lane.

- [ ] JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren #comment: Jeder Treffer muss auf eine offizielle Unternehmens- oder offiziell angebundene Recruiting-Seite zurückführbar sein.
  - [ ] Beschreibung: Implementiere Regeln zur Prüfung, ob eine URL offiziell ist, zur Kanonisierung von Joblinks, zur Speicherung alternativer offizieller URLs und zur Ablehnung nicht verifizierter Treffer.
  - [ ] Scope: URL-/Domain-Validierung, Company-Domain-Bezug, ATS-Allowlist pro Firma, JobSource-Modell, Tests; keine pauschale globale Allowlist ohne Firmenbindung.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Logik unterscheidet offizielle Quellen von Aggregatoren.
  - [ ] Abhängigkeiten: JA-002, JA-004, JA-005.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT; parallelisierbar mit JA-007 nach Festlegung des JobSource-Modells.
  - [ ] Prioritätsscore: 84/100, weil falsche Quellen direkte Qualitätsverletzungen verursachen.
  - [ ] Risiken: Unternehmen nutzen Drittanbieter-ATS-Domains; zu strenge Regeln verwerfen echte offizielle Jobs, zu weiche Regeln akzeptieren Aggregatoren.
  - [ ] Schritte:
    1. Implementiere `isOfficialSource(company, url)` mit Unternehmensdomain, explizit gespeicherter Karriere-URL und firmenbezogener ATS-Domain.
    2. Implementiere URL-Kanonisierung ohne Trackingparameter, Session-IDs oder Suchfilter, aber mit Erhalt jobrelevanter Pfad-/ID-Bestandteile.
    3. Speichere pro Stelle primäre offizielle URL und optionale alternative offizielle URLs; markiere nicht verifizierbare Quellen als `INVALID` oder `unverified`, nie als Treffer.
  - [ ] Evidence: Testbericht mit akzeptierten offiziellen URLs, abgelehnten Aggregator-URLs und kanonisierten Links.
  - [ ] Funktionstest: Tests für Firmen-Domain, ATS-Domain, Redirect, Trackingparameter, StepStone/Indeed/LinkedIn/XING/Kununu/Glassdoor-Ablehnung und mehrfache offizielle URLs.
  - [ ] Audit: Stichprobe mit realistischen URL-Beispielen prüfen, ohne daraus echte Jobs zu behaupten.
  - [ ] Supertest: Quellenverifikation als Pflichtgate in den Daily-Run-Supertest aufnehmen.

## M3 - Matching, Deduplication und Statuslogik

- [ ] JA-007 Stellenklassifikation für IT-Führungspositionen entwickeln #comment: Nur echte IT-Führungsrollen im Zielgebiet sollen als passende Treffer erscheinen.
  - [ ] Beschreibung: Implementiere eine regelbasierte, nachvollziehbare Bewertung für Titel, Aufgaben, Führungsverantwortung, IT-Gesamtverantwortung, Standort, Vollzeitbezug und Arbeitsmodell.
  - [ ] Scope: Matching-Regeln, Ausschlussregeln, Score-/Kategorie-Logik, Tests; keine automatische Bewerbung und keine Speicherung unnötiger persönlicher Daten.
  - [ ] Ist-Stand (2026-08-17 12:20): Zielprofil liegt nur im Briefing vor; es gibt keine maschinenlesbare Klassifikation.
  - [ ] Abhängigkeiten: JA-001, JA-002, JA-005.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-4 PT; teilweise parallelisierbar mit JA-008.
  - [ ] Prioritätsscore: 82/100, weil Trefferqualität vom präzisen Ausschluss unpassender Rollen abhängt.
  - [ ] Risiken: Titel wie `IT Lead` oder `Team Lead` sind mehrdeutig; rein titelbasierte Regeln erzeugen False Positives.
  - [ ] Schritte:
    1. Definiere positive Signale für IT-Leitung, Head/Director/CIO, Gesamtverantwortung, Budget-/Personalverantwortung und strategische IT-Verantwortung.
    2. Definiere negative Signale für reine Entwicklerstellen, Projektleitung ohne IT-Gesamtverantwortung, Spezialistenrollen und Teamleitung ohne wesentliche Führungsverantwortung.
    3. Implementiere eine erklärbare Bewertung mit Ergebnis `MATCH`, `POSSIBLE`, `REJECTED` und Begründungsfeldern, die im Daily-Output nutzbar sind.
  - [ ] Evidence: Fixture-Katalog mit passenden, grenzwertigen und abzulehnenden Stellen; Klassifikationsreport pro Testfall.
  - [ ] Funktionstest: Tests für deutsche/englische Titel, leere Beschreibung, widersprüchlichen Titel, unklaren Standort, Remote-Deutschland-Bezug und Teamlead-Ausschluss.
  - [ ] Audit: Manuell prüfen, dass eine Stelle ohne eindeutige IT-Führungsaufgabe nicht als verifizierter Treffer ausgegeben wird.
  - [ ] Supertest: Nach grünen Klassifikationstests in Supertest aufnehmen.

- [ ] JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren #comment: Bekannte Stellen dürfen bei späteren Läufen nicht erneut als `NEW` erscheinen, auch wenn Titel oder URL-Parameter variieren.
  - [ ] Beschreibung: Implementiere stabile Jobidentitäten mit Priorität offizielle Job-ID, ATS-ID, kanonische URL und sekundäre Merkmale; erkenne Titeländerungen, echte Updates und mögliche Neuausschreibungen.
  - [ ] Scope: Deduplication-Service, ID-Normalisierung, Vergleichslogik, Tests; keine Zusammenführung getrennter Stellen ohne belastbare Identität.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Jobdatenbank und keine Deduplikation vorhanden.
  - [ ] Abhängigkeiten: JA-002, JA-003, JA-006.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-3 PT; kritisch vor erstem produktiven Daily-Run.
  - [ ] Prioritätsscore: 80/100, weil Dublettenvermeidung als hohe Priorität definiert ist.
  - [ ] Risiken: Wiederverwendung von ATS-IDs, geänderte URLs und gelöschte/neuveröffentlichte Stellen können falsch zusammengeführt oder getrennt werden.
  - [ ] Schritte:
    1. Implementiere Identitätspriorität: offizielle Job-ID vor ATS-ID, ATS-ID vor kanonischer URL, URL vor zusammengesetzten Merkmalen aus Firma, Standort und Titel.
    2. Implementiere Vergleich von JobSnapshot zu bestehendem Job mit Erkennung von unverändert, wesentlich geändert, entfernt, geschlossen und potenziell neu veröffentlicht.
    3. Speichere Entscheidungsgründe im Änderungsverlauf, damit jede `NEW`-, `UPDATED`- oder `CLOSED`-Ausgabe nachvollziehbar ist.
  - [ ] Evidence: Deduplikationslog mit Entscheidungsgrund; Testfixtures für bekannte Stelle, Titeländerung, URL-Parameteränderung, echte Neuausschreibung und entfernte Stelle.
  - [ ] Funktionstest: Zwei-Lauf-Test, bei dem dieselbe Stelle im zweiten Lauf nicht erneut `NEW` wird; Tests für Job-ID-Wechsel, URL-Kanonisierung und Titeländerung.
  - [ ] Audit: Prüfen, dass eine Titeländerung allein keine neue Stelle erzeugt und dass unsichere Fälle als unsicher markiert werden.
  - [ ] Supertest: Deduplikations-Zwei-Lauf-Szenario als Pflichtteil des Supertests aufnehmen.

- [ ] JA-009 Statusmaschine für Daily-Run-Ergebnisse und Änderungsverlauf bauen #comment: Neue, aktive, geänderte und entfernte Stellen müssen deterministisch aus Scanresultaten und Historie entstehen.
  - [ ] Beschreibung: Implementiere eine Statusmaschine, die pro Lauf Rohjobs mit der Historie vergleicht, first_seen/last_seen aktualisiert, Statuswechsel erzeugt und Ausgabe-Kandidaten ableitet.
  - [ ] Scope: Daily-State-Engine, ChangeEvent-Erzeugung, Testfixtures mit mehreren Läufen; keine Live-Webrecherche in Funktionstests.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Statusübergänge außer Bootstrap-Todo-Status vorhanden.
  - [ ] Abhängigkeiten: JA-003, JA-008, JA-007.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-4 PT; nach Deduplikation, vor Ausgabeformat.
  - [ ] Prioritätsscore: 78/100, weil tägliche Differenzberichte Kernnutzen des Agenten sind.
  - [ ] Risiken: Temporär nicht erreichbare Portale dürfen aktive Stellen nicht sofort fälschlich als geschlossen markieren.
  - [ ] Schritte:
    1. Implementiere Laufstart mit Laden von Company-, Job- und Scanstatus sowie Erzeugung eines neuen `scan_run_id`.
    2. Implementiere Statusberechnung für gefundene, nicht gefundene, geänderte und ungültige Stellen unter Berücksichtigung erfolgreicher oder fehlgeschlagener Firmen-Scans.
    3. Implementiere ChangeEvent-Ausgabe mit alten/neuen Feldwerten, Zeitpunkt, Quelle und Begründung für jede relevante Änderung.
  - [ ] Evidence: Mehrlauf-Testbericht mit Statusverlauf `NEW -> ACTIVE -> UPDATED -> CLOSED/REMOVED`; ScanAttempt-Log für fehlerhafte Portale ohne voreilige Schließung.
  - [ ] Funktionstest: Tests für ersten Lauf, zweiten unveränderten Lauf, Update-Lauf, fehlgeschlagenen Firmen-Scan, erfolgreiche Entfernung und invaliden Treffer.
  - [ ] Audit: Prüfen, dass `last_seen` nur bei offizieller Wiedererkennung aktualisiert wird und dass Fehler nicht als fehlende Stelle interpretiert werden.
  - [ ] Supertest: Mehrlauf-Statusszenario als Pflichtteil des Supertests aufnehmen.

## M4 - Daily-Run, Ausgabe und Automatisierung

- [ ] JA-010 Deterministischen Daily-Run-Orchestrator implementieren #comment: Der tägliche Rechercheprozess braucht eine klare Reihenfolge, Retry-Logik, begrenzbare Laufzeit und reproduzierbare Nachweise.
  - [ ] Beschreibung: Implementiere einen Orchestrator, der Zustand lädt, Firmen priorisiert, Adapter ausführt, Jobs klassifiziert, Historie aktualisiert, Ergebnis erzeugt und Fehler einzelner Portale isoliert protokolliert.
  - [ ] Scope: CLI-Command z.B. `daily-run`, Priorisierungslogik, Scanbudget, Logging, Tests mit Mock-Adaptern; keine unbegrenzten Browser-/Netzwerkprozesse.
  - [ ] Ist-Stand (2026-08-17 12:20): Kein Daily-Run-Command vorhanden; README/CI bieten nur Bootstrap-Commands.
  - [ ] Abhängigkeiten: JA-003 bis JA-009.
  - [ ] Aufwand/Dauer: Aufwand L-XL, Dauer 3-6 PT; nicht sinnvoll vor Persistenz und Adaptervertrag.
  - [ ] Prioritätsscore: 74/100, weil erst hier aus den Kernkomponenten ein nutzbarer Tageslauf entsteht.
  - [ ] Risiken: Laufzeit kann durch viele Portale wachsen; fehlende Timeouts oder Retry-Grenzen können den gesamten Lauf blockieren.
  - [ ] Schritte:
    1. Implementiere Priorisierung der Firmen nach unbekannt/lang nicht geprüft, hoher Trefferwahrscheinlichkeit, bekannter Karriere-URL, kürzlich passenden Stellen und regulären Wiederholungsläufen.
    2. Implementiere pro Firma isolierte ScanAttempt-Ausführung mit Timeout, Retry-Klasse, Fehlerprotokoll und Fortsetzung des Gesamtlaufs bei Einzelproblemen.
    3. Verbinde Adapter, Klassifikation, Deduplikation, Statusmaschine und Persistenz in einer transaktionalen Laufsequenz mit finalem Ergebnisartefakt.
  - [ ] Evidence: `logs/jobagent/daily-run-<date>.json` und menschenlesbarer Report; Scanstatistik mit untersuchten Firmen, neuen Firmen, geprüften Jobs, neuen/aktiven/geänderten/geschlossenen Stellen und Fehlern.
  - [ ] Funktionstest: Mock-Daily-Run mit drei Firmen: eine erfolgreich mit neuer Stelle, eine unverändert, eine nicht erreichbar; erwartete Persistenz und Ausgabe prüfen.
  - [ ] Audit: Prüfen, dass keine externe Aktion außer lesender Recherche erfolgt und dass ein Firmenfehler den Lauf nicht abbricht.
  - [ ] Supertest: Daily-Run-Mock-Szenario erst nach grünen Komponenten-Funktionstests in Supertest aufnehmen.

- [ ] JA-011 Ausgabeformat und Priorisierung A/B/C für Rechercheberichte umsetzen #comment: Ergebnisse müssen kompakt, differenziert und ohne redundante Wiederholung bekannter unveränderter Stellen nutzbar sein.
  - [ ] Beschreibung: Erzeuge pro Daily-Run einen strukturierten Bericht mit neuen passenden Stellen, aktiven passenden Stellen, Änderungen, geschlossenen/entfernten Stellen, neuen Unternehmen, Recherche-Statistik und A/B/C-Priorisierung.
  - [ ] Scope: Report-Renderer für Markdown und optional JSON, Bewertungserklärung, Snapshot-Verlinkung; keine Bewerbung, keine Kontaktaufnahme, keine externen Schreibaktionen.
  - [ ] Ist-Stand (2026-08-17 12:20): Kein fachlicher Daily-Run-Report vorhanden.
  - [ ] Abhängigkeiten: JA-007, JA-008, JA-009, JA-010.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT; parallelisierbar mit Scheduler erst nach stabiler Daily-Run-Ausgabe.
  - [ ] Prioritätsscore: 68/100, weil ein nutzbarer Bericht erst nach korrekter Datenlogik sinnvoll ist.
  - [ ] Risiken: Zu ausführliche aktive Stellen erzeugen Rauschen; zu knappe geänderte Stellen verlieren Nachvollziehbarkeit.
  - [ ] Schritte:
    1. Implementiere Berichtabschnitte exakt nach Auftrag: neue Stellen, aktive Stellen, Änderungen, geschlossene/entfernte Stellen, neue Unternehmen, Statistik und Priorisierung.
    2. Implementiere A/B/C-Bewertung anhand fachlicher Passung, Führungsverantwortung, Unternehmensrelevanz, Standort, Arbeitsmodell, strategischer Verantwortung, Anforderungen und Bewerbungsrelevanz.
    3. Stelle sicher, dass unveränderte bekannte Stellen nicht erneut vollständig als neue Treffer erscheinen, aber kompakt unter aktiven Stellen auffindbar bleiben.
  - [ ] Evidence: Beispielbericht aus Mock-Daten mit mindestens einem Eintrag je Abschnitt; JSON-Report optional maschinenlesbar.
  - [ ] Funktionstest: Renderer-Tests für leere Ergebnisse, nur neue Stellen, nur Änderungen, geschlossene Stellen, fehlende optionale Felder und A/B/C-Begründung.
  - [ ] Audit: Manuell prüfen, dass jeder verifizierte Treffer eine offizielle URL enthält und unsichere Werte als `UNKNOWN` oder unklar markiert sind.
  - [ ] Supertest: Berichtsgenerierung mit Mock-Daily-Run in Supertest aufnehmen.

- [ ] JA-012 Lokalen Scheduler- und Betriebsmodus für tägliche Läufe dokumentieren und absichern #comment: Der Agent soll täglich laufen, ohne den Zustand vorheriger Läufe zu verlieren oder parallele Läufe zu starten.
  - [ ] Beschreibung: Definiere und implementiere einen sicheren lokalen Betriebsmodus für tägliche Ausführung mit Locking, Logrotation, Exitcodes, Retry-Hinweisen und klarer Bedienung über `.\ci.cmd`.
  - [ ] Scope: CI-Command-Integration, Scheduler-Dokumentation, Lock-/Statusdateien, Tests; keine Einrichtung eines externen Cloud-Dienstes ohne separaten Auftrag.
  - [ ] Ist-Stand (2026-08-17 12:20): Bootstrap kennt CI-Commands, aber keinen fachlichen `daily-run`-Scheduler.
  - [ ] Abhängigkeiten: JA-010, JA-011; Locking aus JA-003 wiederverwenden.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT; kann nach Daily-Run-CLI parallel zur Dokumentation erfolgen.
  - [ ] Prioritätsscore: 60/100, weil Automatisierung nach korrektem Einzellauf kommt.
  - [ ] Risiken: Parallele Scheduler-Starts können Daten beschädigen; Logdateien können wachsen; Netzwerkfehler dürfen nicht still verschluckt werden.
  - [ ] Schritte:
    1. Registriere einen CI-Command wie `.\ci.cmd daily-run`, der den fachlichen Orchestrator startet, Exitcodes setzt und Logs unter `logs/jobagent/` schreibt.
    2. Dokumentiere Windows Task Scheduler Einrichtung mit Arbeitsverzeichnis, Kommando, Zeitplan, Umgebungsannahmen und sicheren Re-Run-Regeln.
    3. Implementiere Status-/Lockdateien, Logrotation und `daily-run-status`, damit laufende oder zuletzt fehlgeschlagene Läufe ohne Kontextverlust geprüft werden können.
  - [ ] Evidence: Betriebsdokumentation, Beispiel-Scheduler-Konfiguration ohne Secrets, Logrotationstest und Statusdatei eines Mock-Laufs.
  - [ ] Funktionstest: Tests für Start bei freiem Lock, Start bei bestehendem Lock, Statusabfrage, Logrotation und Exitcode bei Adapterfehlern.
  - [ ] Audit: Prüfen, dass keine Secrets in Logs oder Handoff landen und dass der Scheduler keine interaktiven Prompts erzeugt.
  - [ ] Supertest: Scheduler-/CLI-Mocklauf in Supertest aufnehmen, produktive Webrecherche als separate Live-Lane kennzeichnen.

## M5 - Qualität, Live-Abdeckung und Erweiterung

- [ ] JA-013 Teststrategie und Supertest für Kernfunktionen konsolidieren #comment: Einzelne Funktionstests müssen vor dem Supertest grün sein; der Supertest bündelt erst abgeschlossene Roadmap-Funktionen.
  - [ ] Beschreibung: Erstelle fokussierte Tests für Schema, Persistenz, Quellenverifikation, Klassifikation, Deduplikation, Statusmaschine, Daily-Run und Report; bündle abgeschlossene Funktionen in einem Supertest-Command.
  - [ ] Scope: Testordner, Fixtures, CI-Command, Testdaten; keine Live-Webabhängigkeit in deterministischen Funktionstests.
  - [ ] Ist-Stand (2026-08-17 12:20): Es gibt Bootstrap-Tests, aber keinen fachlichen JobAgent-Testvertrag.
  - [ ] Abhängigkeiten: Mindestens JA-002 bis JA-011 für vollständigen Supertest; einzelne Tests entstehen jeweils mit der Funktion.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer laufend 2-5 PT über die Implementierung; parallel zu allen Funktionspunkten.
  - [ ] Prioritätsscore: 72/100, weil Qualitätssicherung laufend mitentwickelt werden muss, aber vollständiger Supertest erst nach Kernfunktionen sinnvoll ist.
  - [ ] Risiken: Live-Webtests können flakey sein; zu breite Tests erschweren schnelle Fehlerlokalisierung.
  - [ ] Schritte:
    1. Definiere Fixture-Format und Testdaten für Firmen, Jobs, URLs, Statusübergänge, fehlerhafte Portale und Berichtsausgaben.
    2. Implementiere pro Kernfunktion fokussierte Tests mit typischen Werten, Grenzwerten, ungültigen Eingaben, Fehlermeldungen, Idempotenz und Nebenwirkungen.
    3. Registriere einen Supertest, der nur abgeschlossene und bereits einzeln grüne Funktionsbereiche ausführt und Live-Crawls getrennt markiert.
  - [ ] Evidence: Testmatrix mit Zuordnung Roadmap-ID -> Testdatei -> Command -> Status; Supertest-Log mit ausgeführten Teilbereichen.
  - [ ] Funktionstest: `.\ci.cmd self-check`; projektspezifische Testcommands je implementierter Funktion; Supertest erst nach Abschluss des jeweiligen Roadmap-Punkts.
  - [ ] Audit: Prüfen, dass Tests keine produktiven Daten überschreiben und dass Fixtures keine erfundenen realen Stellen als echte Treffer darstellen.
  - [ ] Supertest: `.\ci.cmd supertest` nach grünem Abschluss einzelner Funktionstests.

- [ ] JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll durchführen #comment: Erst nach stabiler Mock-Logik darf eine kleine Live-Lane offizielle Quellen prüfen und reale Treffer belastbar nachweisen.
  - [ ] Beschreibung: Führe einen begrenzten Live-Pilot mit ausgewählten offiziellen Karrierequellen durch, speichere Scanversuche, verifizierte Treffer, Nicht-Treffer und technische Fehler ohne ungesicherte Behauptungen.
  - [ ] Scope: Kleine Firmenstichprobe aus dem Inventar, Live-Scan-Logs, Review der Ergebnisse; keine großflächige Recherche ohne Rate-/Laufzeitgrenzen.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Live-Recherche durchgeführt; keine Firmen oder Stellen sind fachlich verifiziert.
  - [ ] Abhängigkeiten: JA-004 bis JA-013, insbesondere Quellenverifikation und Statusmaschine.
  - [ ] Aufwand/Dauer: Aufwand M-L, Dauer 1-3 PT je nach Portalen; parallelisierbar mit Ausbau weiterer Adapter nach Pilotbefund.
  - [ ] Prioritätsscore: 58/100, weil Live-Abdeckung wertvoll ist, aber erst nach deterministischer Kernlogik belastbar wird.
  - [ ] Risiken: Websites ändern Struktur, blockieren Abrufe oder liefern dynamische Inhalte; einzelne Fehler dürfen nicht als fehlende Stellen gelten.
  - [ ] Schritte:
    1. Wähle eine kleine, dokumentierte Firmenstichprobe mit offizieller Karriere-URL und klarer Firmen-ID aus dem Inventar.
    2. Führe Live-Scans mit festen Timeouts, User-Agent-Regeln, Retry-Grenzen und vollständigen ScanAttempt-Logs aus.
    3. Prüfe jede gefundene potenzielle Stelle gegen offizielle Detailseite, Zielprofil, Standort und Status, bevor sie im Bericht als verifiziert erscheint.
  - [ ] Evidence: `logs/jobagent/live-pilot-<date>.json`, Bericht mit geprüften Firmen, Trefferstatus, Fehlerklassen und offizieller URL je verifiziertem Treffer.
  - [ ] Funktionstest: Vor Live-Pilot alle Mock-Funktionstests ausführen; nach Pilot Validierung der erzeugten Datenbank gegen Schema und keine Duplikate.
  - [ ] Audit: Manuelle Stichprobe jeder als verifiziert ausgegebenen Stelle; unklare Treffer müssen als nicht verifiziert markiert oder ausgeschlossen sein.
  - [ ] Supertest: Supertest bleibt mock-basiert; Live-Pilot als separate Lane dokumentieren und nicht als deterministisches Pflichtgate verwenden.

- [ ] JA-015 Kontinuierliche Firmenabdeckung und Adapter-Erweiterung priorisieren #comment: Nach dem Pilot muss die Abdeckung systematisch wachsen, statt täglich dieselben Unternehmen abzufragen.
  - [ ] Beschreibung: Implementiere einen Verbesserungszyklus, der unbekannte Firmen, fehlerhafte Portale, neue ATS-Systeme und lange nicht geprüfte Unternehmen priorisiert und die Abdeckung messbar erweitert.
  - [ ] Scope: Coverage-Metriken, Backlog für Firmen/Adapter, Scanpriorisierung, Reportabschnitt für Abdeckung; keine automatische Zusammenführung unklarer Unternehmensgruppen.
  - [ ] Ist-Stand (2026-08-17 12:20): Keine Abdeckungsmetriken und keine ATS-Erweiterungshistorie vorhanden.
  - [ ] Abhängigkeiten: JA-004, JA-005, JA-010, JA-014.
  - [ ] Aufwand/Dauer: Aufwand M-L initial 1-3 PT, danach kontinuierlich; parallelisierbar mit weiteren ATS-Adaptern.
  - [ ] Prioritätsscore: 52/100, weil nachhaltige Trefferqualität erst nach Kernbetrieb skaliert.
  - [ ] Risiken: Fokus auf einfache Portale kann wichtige Firmen mit schwierigen ATS-Systemen verdrängen; Coverage-Metriken dürfen keine Vollständigkeit vortäuschen.
  - [ ] Schritte:
    1. Implementiere Coverage-Metriken: Anzahl Firmen im Inventar, erfolgreich gescannt, fehlerhaft, ohne Karriere-URL, ohne passende Stellen, mit passenden Stellen und seit X Tagen ungeprüft.
    2. Erzeuge einen priorisierten Erweiterungsbacklog für neue Firmen, problematische Karriereportale und fehlende ATS-Adapter mit Begründung und nächstem technischen Schritt.
    3. Ergänze den Daily-Run um Rotation, damit nicht jeden Tag ausschließlich dieselben Suchanfragen und Firmen untersucht werden.
  - [ ] Evidence: Coverage-Report, Adapter-Backlog, Scanprioritätsliste und Änderungsverlauf neuer Firmen/ATS-Systeme.
  - [ ] Funktionstest: Tests für Priorisierung bei unbekannten Firmen, lange nicht geprüften Firmen, fehlerhaften Portalen, kürzlich passenden Stellen und Rotationslogik.
  - [ ] Audit: Prüfen, dass Coverage-Prozentwerte als Annäherung gekennzeichnet sind und keine vollständige Marktdeckung behaupten.
  - [ ] Supertest: Coverage-Priorisierung mit Mock-Inventar in Supertest aufnehmen.
