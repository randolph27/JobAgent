# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-016 ist weitgehend fachlich angelegt, aber die angehängte Programmanweisung ist noch nicht vollständig umgesetzt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizielle Quellenverifikation, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog und Supertest.
- Kritische Lücken: Live-Recherche ist noch Pilotqualität; Firmeninventar wird nicht systematisch autonom erweitert; lokale App-/Artefaktablage und Audit-Nachweise sind noch nicht vollständig vertraglich abgesichert.
- Priorisierung: zuerst Live-Adapter-Härtung, weil JA-019 die Quellenbeweiskette für ATS-/Redirect-Anbindungen jetzt persistent und auditierbar absichert; danach Firmenabdeckung; zuletzt lokale Betriebs-/Audit-Härtung.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## M8 - Live-Recherche und Firmenabdeckung

- [ ] JA-020 Live-Adapter von Pilotqualität auf robuste offizielle Karriereseiten- und ATS-Erkennung erweitern #comment: Die aktuelle Live-Lane kann einfache HTML-Links prüfen, deckt aber typische Karriereportale und ATS-Systeme noch nicht verlässlich ab.
  - [ ] Beschreibung: Live-Scans erkennen statische Karriereseiten, Such-/Listen-Seiten und mindestens eine explizit belegte ATS-Struktur deterministisch, begrenzt und fail-closed; jedes Ergebnis enthält offizielle Detail-URL, HTTP-/Fetch-Nachweis, Extraktionsvertrauen, Klassifikation und Fehlerklasse.
  - [ ] Scope: Betroffen sind `src/JobAgent.LiveScan.psm1`, `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentLiveScan.ps1`, `tests/Test-JobAgentSourceAdapters.ps1`, optional `tools/Invoke-JobAgentLivePilot.ps1`; No-Go: kein Login-/Captcha-Bypass, kein Scraping gegen Aggregatoren als Primärquelle, keine ungebremste Volltextsuche, keine Live-Abhängigkeit in deterministischen Funktionstests.
  - [ ] Ist-Stand (2026-08-17 16:20): `Invoke-JobAgentLiveHtmlAdapter` nutzt HTTP-Fetch, Linkkandidaten und Detailfetches; Extraktion basiert erkennbar auf generischen Link-/Textsignalen und ist für dynamische ATS-/JSON-/Suchseiten noch nicht robust genug.
  - [ ] Abhängigkeiten: JA-018 und JA-019 sollten zuerst abgeschlossen sein, damit mehr Live-Quellen nicht falsche Status oder unklare Verifikationen erzeugen; JA-016/017 verbessern Nachweise.
  - [ ] Aufwand/Dauer: Aufwand L-XL; Dauer 2-3 Arbeitstage bei 1 Agent für erste robuste Erweiterung; parallelisierbar mit JA-021, wenn Firmenliste und Adapter-Backlog getrennt bearbeitet werden.
  - [ ] Prioritätsscore: 82/100, weil Live-Abdeckung direkten Produktwert erzeugt, aber erst nach Report- und Statushärtung sicher skalierbar ist.
  - [ ] Ordnungsbegründung: Live-Adapter folgen nach Vertrags- und Statussicherheit, damit neue reale Daten nicht mit unvollständiger Ausgabe oder unsicherer Historie vermischt werden.
  - [ ] Risiken und Unsicherheiten: Karriereportale ändern HTML/JSON-Strukturen; manche Seiten blockieren einfache HTTP-Clients oder benötigen JavaScript. Solche Fälle müssen als `BLOCKED`, `TECHNICAL_LIMITATION` oder `MANUAL_REVIEW` enden, nicht als verifizierter Treffer.
  - [ ] Schritte:
    1. Adapter-Backlog aus `coverage.backlog` und Store-Quellen auswerten und konkrete erste ATS-/Karriereseitenmuster priorisieren, ohne reale Treffer zu erfinden.
    2. Extraktion für strukturierte JSON-LD/JobPosting, Linklisten und mindestens ein belegtes ATS-Pattern implementieren, jeweils mit MaxResults, Timeout, Retry und offizieller URL-Prüfung.
    3. Deterministische Fixtures für HTML, JSON-LD, ATS-ähnliche Listen, blockierte Seite, leere Seite und Detailfetch-Fehler erstellen; optional separaten Live-Pilot nur als nicht-deterministische Lane belassen.
  - [ ] Evidence: Neue oder erweiterte Tests mit lokalen Fixtures; Live-Pilot-Log unter `logs/jobagent/live-pilot-<stamp>.json` nur bei explizitem Pilotlauf; Report zeigt Fehlerklassen und unsichere Quellen.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1`.
  - [ ] Audit: Für Live-Pilot maximal begrenzte Firmenzahl, User-Agent, Timeout, Retry und keine Aggregator-Primärquelle prüfen; reale Treffer nur zählen, wenn offizielle Detailseite erreichbar und klassifiziert ist.
  - [ ] Supertest: Nach grünen Funktionstests `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1`; Live-Pilot nicht in den deterministischen Supertest aufnehmen.
  - [ ] Meilenstein und Parallelisierung: M8; parallel mit JA-021 möglich, solange JA-018/019 abgeschlossen sind.

- [ ] JA-021 Firmeninventar autonom, dedupliziert und quellenorientiert erweitern #comment: Die angehängte Anweisung verlangt langfristig möglichst vollständige Firmenabdeckung statt einer statischen Seedliste.
  - [ ] Beschreibung: Der JobAgent kann neue relevante Unternehmen im Zielgebiet aus erlaubten Entdeckungsquellen oder gepflegten Seeds aufnehmen, Dubletten vermeiden, offizielle Website/Karriere-URL verifizieren und den Recherchefortschritt mit Scanstatus, Priorität und nächstem Schritt persistieren.
  - [ ] Scope: Betroffen sind `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tools/Seed-JobAgentCompanies.ps1`, neue optionale Discovery-Tools, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1`; No-Go: keine neue Firma ohne belastbare Quelle, keine Zusammenführung rechtlich unterschiedlicher Arbeitgeber ohne eindeutigen Beleg.
  - [ ] Ist-Stand (2026-08-17 16:20): Es gibt einen initialen Store mit 12 Firmen und Coverage-Priorisierung; eine systematische autonome Erweiterung über Branchen, regionale Arbeitgeber, Banken, Versicherungen, Automotive, Gesundheitswesen, öffentliche Arbeitgeber und Technologieunternehmen ist noch nicht umgesetzt.
  - [ ] Abhängigkeiten: JA-004 und JA-015 sind abgeschlossen; JA-019 ist für neue ATS-Belege relevant, aber nicht für reine Firmenseeds blockierend.
  - [ ] Aufwand/Dauer: Aufwand L; Dauer 1-2 Arbeitstage bei 1 Agent für lokale Seed-/Discovery-Lane ohne Webvollcrawl; parallelisierbar mit JA-020.
  - [ ] Prioritätsscore: 78/100, weil Abdeckung Trefferwahrscheinlichkeit stark erhöht, aber ohne robuste Adapter nur begrenzt sofort auswertbar ist.
  - [ ] Ordnungsbegründung: Nach Report-, Status- und Quellenhärtung kann die Firmenbasis wachsen, ohne die Historie mit unsicheren Quellen zu verschmutzen.
  - [ ] Risiken und Unsicherheiten: Vollständigkeit kann nicht belegt werden; Unternehmensstandorte und Karriere-URLs ändern sich; Discovery aus Sekundärquellen darf nicht als Verifikation missverstanden werden.
  - [ ] Schritte:
    1. Firmen-Discovery-Vertrag definieren: erlaubte Entdeckungsquelle, offizielle Website-Verifikation, Karriere-URL-Prüfung, Branche, Zielgebietsbezug, Priorität und `discovery_source`.
    2. Deduplikation erweitern: Domain, Rechtsformvarianten, Aliasnamen, Konzern-/Tochtergesellschaften und Standortbezug testen; neue Firmen nur als neue Unternehmen im Report ausgeben.
    3. Backlog-/Scanpriorität so anpassen, dass nie oder lange nicht untersuchte Firmen vor routinemäßigen Wiederholungen stehen und fehlerhafte Karriereportale Retry-Status behalten.
  - [ ] Evidence: Erweiterter Firmen-Seed oder Discovery-Import mit Quellenbelegen; Store-Diff ohne Dubletten; Coverage-Report mit `never_scanned`, `stale_or_unscanned`, `without_career_url` und neuen Firmen.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; bei Reportauswirkung `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`.
  - [ ] Audit: Stichprobe neuer Firmen: offizielle Website/Karriere-URL erreichbar oder als `UNVERIFIED`/`MANUAL_REVIEW` markiert; keine Jobbörse als Primärbeleg; keine bereits bekannte Firma erscheint erneut als neue Firma.
  - [ ] Supertest: Nach grünen Funktionstests `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1`.
  - [ ] Meilenstein und Parallelisierung: M8; parallel mit JA-020 möglich, sofern nur Inventar- und Coverage-Dateien bearbeitet werden.

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
