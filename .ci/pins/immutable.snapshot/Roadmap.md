# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, tägliche Läufe zunächst manuell oder per lokalem Scheduler, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: aktuell Bootstrap-/CI-Gerüst, fachliche JobAgent-Implementierung noch aufzubauen; konkrete Programmiersprache, Persistenztechnologie und Testframework sind noch nicht final festgelegt.
- Priorisierung: zuerst persistente Verträge und Datenmodelle, danach idempotente Laufsteuerung, danach Quellen-/Crawler-Adapter, Matching, Statuslogik, Ausgabe, Automatisierung und Qualitätssicherung.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis.

## M5 - Qualität, Live-Abdeckung und Erweiterung

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
