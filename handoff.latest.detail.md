# Uebergabe-Details

Stand: 2026-09-18T20:05:00+02:00

## Arbeitsstand

`JA-049 Stellenboerse als stabilen HTML-Einstieg atomar publizieren` ist abgeschlossen und nach `Roadmap_archive.md` rotiert. `TD-0077` ist als erledigt im Todo-Index abgelegt. Aktiver Punkt ist `TD-0083` / `JA-054`. Die naechste fachliche Reihenfolge lautet `JA-054 -> JA-056 -> JA-050`.

Der vorhandene Devserver auf Port 8500 ist ein externer, nicht verwalteter Listener. Keine zweite Instanz starten; Status ausschliesslich mit `./ci.cmd devserver-status` pruefen. SonarQube ist auf Port 9000 vorhanden, nur bei spaeterem Bedarf mit `./ci.cmd sonar` nutzen.

## Abschluss JA-049

Die stabile Stellenboerse wird aus genau einer gespeicherten Storegeneration in `html/jobagent/index.html` veroeffentlicht. `Write-JobAgentDailyRunPublication` in `src/JobAgent.DailyRun.psm1` validiert die temporaere HTML-Ausgabe, erzeugt ein Manifest mit Store-/Quell-/Ziel-Hashes und tauscht die Datei erst danach atomar aus. Ein injizierter Fehler vor dem Tausch erhaelt die vorherige Einstiegsversion.

Der Daily-Run, Operationsstatus und das CLI-Ergebnis liefern `jobboard_path` sowie `publication_manifest_path`. Die Stellenboerse verlinkt die Firmen- und Coverage-Diagnose; die Coverage-Seite verlinkt zur Stellenboerse. Der aktuelle Einstieg ist erreichbar unter:

- `html/jobagent/index.html`
- `http://127.0.0.1:8500/html/jobagent/`
- `logs/jobagent/JA-049/publication-manifest.json`

Akzeptanznachweis: `docs/reviews/JA-049-acceptance.md`.

Erfolgreiche Funktionstests:

- `pwsh -NoProfile -File .\tests\Test-JobAgentPublication.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1 -IncludeToolIntegration`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1`

Der volle `./ci.cmd supertest` war fuer JA-049 nicht angefordert. Nach der Nutzerregel gilt er deshalb als erledigt. Ein bereits gestarteter Lauf wurde bewusst beendet; daraus folgt kein fehlgeschlagener Test.

## Startpunkt JA-054

Ziel ist eine lokale Kalenderansicht fuer tatsaechlich gespeicherte Abrufe, bekannte geplante Pruefungen und eigene Termine. Die Ansicht darf weder einen Abruf ausloesen noch eine Planung als ausgefuehrten Scrape darstellen. Sie baut auf vorhandenen Zeitdaten aus JA-051, eigenen Aufgaben aus JA-052 und der stabilen JA-049-Publikation auf.

Verbindlicher Umfang:

- Monat, Woche und Agenda mit Hashnavigation `view=calendar`, `calendarMode=month|week`, `calendarDate` sowie optionaler Firmen-ID.
- Monatsansicht: Montag zuerst, immer 42 Tagesfelder. Woche: sieben Tagesfelder. Agenda: gleiche zeitliche Reihenfolge.
- Abruf-/Retry-Status von persoenlichen Aufgaben und geplanten Pruefungen getrennt visualisieren und textlich benennen.
- Pro Firmen-ID nur ein aktueller `next_scan_at`-Termin, gestrichelt und als geplant gekennzeichnet. Keine erfundene Planhistorie und keine Rueckdatierung.
- Retryversuche bleiben einzelne Abrufe; Tageskopf zaehlt Firmen distinct und Abrufe getrennt. Orakel: Firma A mit zwei Fehlern und einem Erfolg mit zwei neuen Jobs ergibt 1 Firma, 3 Abrufe, 2 Fehler, 2 neue Stellen.
- Abschluss ueber Mitternacht einmal am lokalen Enddatum; laufender Abruf am Startdatum. Ein Abschluss ersetzt den Laufstatus, statt ein zweites Ereignis anzulegen.
- Leere Tage zeigen ehrlich `Keine gespeicherten Abrufe`. Historische Luecken nicht als vollstaendige Zeitreihe ausgeben.
- Tagesgenaue Aufgaben ohne Zeitzonenverschiebung; zeitgebundene Termine mit Offset. Aufgaben offen/erledigt filterbar; private Notizen nur im persoenlichen Detail.
- Tagesdetails begrenzen: maximal 50 Ereignisse je Tag, mit Seitennavigation. Klickziele zu Firmen-/Quellen-/Jobdetails bzw. Bewerbungsdetails.

Geplante Dateien und Grenzen:

- Scope: `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `src/JobAgent.Operations.psm1` nur fuer benoetigte Projektion, UI-/CSS-/State-Assets.
- Neu: `tests/Test-JobAgentCalendar.ps1`, `tests/fixtures/jobagent/calendar.json`, `docs/reviews/JA-054-acceptance.md`, `logs/jobagent/JA-054/calendar-cases.json` und vier Viewport-Screenshots.
- No-Gos: neuer Scheduler, Navigation mit automatischem Abruf, externer Kalenderconnector, Mail/Push, Daten aus Browseruhr als Scrapeerfolg, Loeschen historischer Laeufe.

Empfohlene Reihenfolge:

1. Fixture mit festen Run-/Attempt-/Task-IDs, Referenzdatum, Zeitzone, Retry-, Leer-, Plan- und Mitternachtsfaellen definieren; technische Zeitaggregation strikt von persoenlichen Aufgaben trennen.
2. Gemeinsame Zeitprojektion mit Monats-/Wochen-/Agenda-Rendering, Hashnavigation, Statuslegende und statischem Fallback implementieren.
3. Tagesdetails, Filter, Detailverweise, Tastatursteuerung und 50-Ereignis-Paginierung ergaenzen.
4. Funktionstests fuer 42/7 Felder, Montagstart, Februar 2028, Dez/Jan, zweimal 02:30 mit unterschiedlichen Offsets am 2026-10-25, Mitternacht, Retryorakel, 0/50/51 Ereignisse, fehlende Planung, Aufgabenstatus, unbekannten Hash sowie Netzwerkanfragen ausfuehren.
5. Report-, Browser- und Viewport-Audits fuer 1920x1080, 1366x900, 800x1024 und 390x844 ausfuehren. Supertest erst bei fachlich abgeschlossenem JA-054; ohne ausdrueckliche Anforderung als erledigt behandeln.

## Offene technische Nebenlage

`TD-0085` bleibt offen. `./ci.cmd stp` meldet `route_ok=false` wegen Steuerzeichen in `java.desktop/freetype.md` und einer offenen Fence in `java.desktop/giflib.md`, jeweils in gebuendelten Sonar-JRE-Lizenzbestanden unter `.ci/tools/sonar`. Das ist kein Produktcodefehler und wurde nicht mit JA-049 vermischt.

## Abschlussprotokoll dieses Standes

`./ci.cmd stp` wurde ausgefuehrt. Todo, Roadmap und Handoff zeigen jetzt `TD-0083` als aktiven Punkt. Vor dem naechsten Eingriff zuerst die Kalenderfixture und ihre fachlichen Orakel festlegen; keine globale Bereinigung oder erneute Publikationsarchitektur beginnen.
