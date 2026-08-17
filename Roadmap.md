# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-016 ist weitgehend fachlich angelegt, aber die angehängte Programmanweisung ist noch nicht vollständig umgesetzt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizielle Quellenverifikation, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog und Supertest.
- Kritische Lücken: Live-Recherche bleibt trotz robusterer Adapter begrenzt; lokale App-/Artefaktablage, Devserver-Portvertrag und Visual-Audit-Nachweise sind noch nicht vollständig vertraglich abgesichert.
- Priorisierung: nach abgeschlossener Firmenabdeckung folgt jetzt die lokale Betriebs-/Audit-Härtung, weil HTML-Artefakte bereits existieren, aber Port-, Ablage- und Sichtbarkeitsvertrag noch offen sind.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## M9 - Lokaler Betrieb, Audit und Abnahme

- [ ] JA-022 Lokale App-/Artefaktablage, Devserver-Port und Visual-Audit für HTML-Berichte absichern #comment: Die App läuft nur lokal; Berichte müssen reproduzierbar abgelegt, geöffnet und visuell geprüft werden können.
  - [ ] Beschreibung: CI-/Tooling-Vertrag startet den lokalen Static-/Devserver über `.\ci.cmd` im Hintergrund, nutzt den vereinbarten Port oder dokumentiert die tatsächliche Konfiguration, stellt HTML-Reports aus `html/` bereit und liefert einen reproduzierbaren Visual-/Layout-Check ohne externe Dienste.
  - [ ] Scope: Betroffen sind `.ci/ci.config.json`, `.ci/bin/modules/*` nur falls Port/Command-Vertrag angepasst werden muss, `tests/Test-JobAgentOperations.ps1`, neue lokale HTML-Audit-Tests oder Dokumentation in `manual/PROGRAM.md`; No-Go: kein blockierender Vordergrundserver, kein Start außerhalb `.\ci.cmd`, kein ungeprüftes Beenden fremder Prozesse.
  - [ ] Ist-Stand (2026-08-17 16:20): Nutzer nennt Devserver `:8500`; `.ci/ci.config.json` enthält aktuell `python -m http.server 8300 --bind 127.0.0.1`. Diese Abweichung muss bewusst bereinigt oder als Annahme dokumentiert werden. SonarQube soll über API/Curl geprüft werden, ist aber für HTML-Report-Funktionstests nicht zwingend.
  - [ ] Abhängigkeiten: JA-016 ist abgeschlossen und erzeugt HTML-Artefakte; JA-017 sollte die sichtbaren Pflichtfelder liefern.
  - [ ] Aufwand/Dauer: Aufwand M; Dauer 0,5-1 Arbeitstag bei 1 Agent; nach JA-017 weitgehend unabhängig von Live-Adapter-Arbeit.
  - [ ] Prioritätsscore: 72/100, weil lokale Bedienbarkeit wichtig ist, aber ohne HTML-Report und vollständige Reportfelder noch kein abnahmefähiges Ziel hat.
  - [ ] Ordnungsbegründung: Betriebshärtung folgt nach funktionsfähigem HTML-Output, damit geprüft wird, was tatsächlich ausgeliefert wird.
  - [ ] Risiken und Unsicherheiten: Portkonflikt auf 8500 oder 8300; vorhandene Server dürfen nicht blind beendet werden. Falls Port 8500 bindend ist, muss die Konfiguration angepasst und über `.\ci.cmd devserver-start/status/stop` getestet werden.
  - [ ] Schritte:
    1. Portvertrag entscheiden und umsetzen: entweder `.ci/ci.config.json` auf 8500 ändern oder README-/Manual-Abweichung dokumentieren; danach `.\ci.cmd devserver-start` im Hintergrund und `.\ci.cmd devserver-status` testen.
    2. Lokalen HTML-Audit implementieren, der eine erzeugte `html/jobagent/*.html` über statischen Server oder Datei-Parser prüft: Pflichtsektionen, keine externen Ressourcen, keine Layout-Überläufe bei langen Texten.
    3. Betriebsstatus/Handoff erweitern, sodass letzter Daily-Run JSON-, Markdown- und HTML-Pfade ausweist und der Nutzer ohne Serverinteraktion die Datei öffnen kann.
  - [ ] Evidence: Devserver-Statuslog mit Port und URL; HTML-Audit-Artefakt oder Testoutput; `handoff.latest.json` mit Reportpfaden; keine laufenden Vordergrundprozesse.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1`; neuer HTML-Audit-Test nach Implementierung; `.\ci.cmd devserver-status`; falls Serverstart Teil des Punktes ist zusätzlich `.\ci.cmd devserver-start` und später Statusprüfung.
  - [ ] Audit: Browser-/Viewport-Check bei 1920/1366/800 px; Akzeptanz: Tabellen umbrechen, Buttons/Links nicht überlagert, Text nicht abgeschnitten, lokaler Server liefert HTML mit HTTP 200, keine externen Requests.
  - [ ] Supertest: Nach grünen Funktionstests `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1`; optional `.\ci.cmd self-check`.
  - [ ] Meilenstein und Parallelisierung: M9; abhängig von JA-016/017, danach parallel zu Firmenabdeckung möglich.
