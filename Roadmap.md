# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, tägliche Läufe zunächst manuell oder per lokalem Scheduler, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: aktuell Bootstrap-/CI-Gerüst, fachliche JobAgent-Implementierung noch aufzubauen; konkrete Programmiersprache, Persistenztechnologie und Testframework sind noch nicht final festgelegt.
- Priorisierung: zuerst persistente Verträge und Datenmodelle, danach idempotente Laufsteuerung, danach Quellen-/Crawler-Adapter, Matching, Statuslogik, Ausgabe, Automatisierung und Qualitätssicherung.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis.

## M4 - Daily-Run, Ausgabe und Automatisierung

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
