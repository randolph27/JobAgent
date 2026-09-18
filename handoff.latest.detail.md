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

## Fortschritt JA-054 (2026-09-18)

Die Kalenderprojektion ist jetzt Teil von `New-JobAgentDailyReport`: Sie liefert alle gespeicherten Versuche, die aktuellen `next_scan_at`-Planungen pro Firma, distinct `JOB_CREATED`-IDs je Lauf und eine feste `Europe/Berlin`-Reportreferenz. `html/jobagent/assets/jobboard-calendar.js` liest diese Projektion sowie lokale Aufgaben und stellt Monat, Woche und die mobile Agenda unter `#view=calendar` dar. Abrufe, Planungen und persoenliche Termine bleiben getrennt; Hashnavigation und Filter starten keine Abfrage.

Neu vorhanden: `tests/Test-JobAgentCalendar.ps1`, `tests/fixtures/jobagent/calendar.json`, `docs/reviews/JA-054-acceptance.md` und `logs/jobagent/JA-054/calendar-cases.json`.

Bestanden: `node --check .\\html\\jobagent\\assets\\jobboard-calendar.js`, `pwsh -NoProfile -File .\\tests\\Test-JobAgentCalendar.ps1`, `pwsh -NoProfile -File .\\tests\\Test-JobAgentReport.ps1`, `pwsh -NoProfile -File .\\tests\\Test-JobAgentUserState.ps1` und `git diff --check`.

Offen bleiben der isolierte Kalender-Browser-/Viewport-Audit, Sommerzeit- und 50/51-Ereignisfaelle sowie Screenshots. `TD-0083` bleibt deshalb `in-progress`; Roadmap und Todo werden noch nicht abgeschlossen oder rotiert.

## Uebergabe an den naechsten Chat

1. Bei `TD-0083` bleiben und keine Roadmap-Rotation vornehmen. `JA-054` ist fachlich noch nicht vollstaendig; die Nutzerregel macht einen nicht angeforderten Supertest nur dann erledigt, wenn die sonstigen Akzeptanzkriterien belegt sind.
2. Die vorhandene Projektion pruefen und erweitern: 42 Monatsfelder/Montagstart, sieben Wochenfelder, Februar 2028, Dez/Jan, die zwei lokalen 02:30-Zeitpunkte am 2026-10-25 mit unterschiedlichen Offsets, laufend-zu-fertig ohne Duplikat, 0/50/51 Tagesereignisse, fehlende/verschobene Planung sowie offene/erledigte lokale Aufgaben.
3. Einen isolierten Playwright-/Browserfall fuer `#view=calendar` auf einer Fixture ausfuehren. Nachweisen: Reload/Zurueck/Vor, Pfeiltasten/Home/End/Enter, keine externen oder Bediennetzwerkanfragen, Linkziele, 50er-Seitenwechsel und Fokus. Die bisherigen Aufrufe von `Test-JobAgentUiBrowserAudit.ps1 -FixtureOnly` lieferten innerhalb des Tool-Zeitfensters keinen Abschluss; daraus folgt kein Testergebnis.
4. Danach `Test-JobAgentHtmlViewportAudit.ps1` oder einen spezifischen Kalender-Viewporttest fuer 1920x1080, 1366x900, 800x1024 und 390x844 ausfuehren; Screenshots nur bei bestandenem Audit unter den in Roadmap.md vorgesehenen Pfaden ablegen.
5. Bestehen alle spezifischen Tests, `JA-054` in Roadmap/Todo abschliessen und nach `Roadmap_archive.md` rotieren. Ein Supertest ist nicht erneut erforderlich, solange er nicht ausdruecklich angefordert wird. Erst dann `TD-0084` / `JA-056` aktivieren.

Der `stp`-Routefehler ist weiterhin ausschliesslich ein gebuendelter Sonar-JRE-Lizenzbestand in `.ci/tools/sonar` (Steuerzeichen bzw. offene Markdown-Fence). Nicht im Rahmen von JA-054 aendern.
