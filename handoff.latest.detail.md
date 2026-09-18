# Uebergabe-Details

Stand: 2026-09-18T20:35:00+02:00

## Aktiver Arbeitsauftrag

`TD-0084` / `JA-056 Gespeicherte Suchauftraege und neue Treffer seit letzter Sichtung bereitstellen` ist aktiv. Die verbindliche Reihenfolge lautet `JA-056 -> JA-050`; `TD-0085` bleibt ein separater CI-Driftpunkt.

## Abgeschlossener Schnitt JA-054

`JA-054` / `TD-0083` ist vollständig nach `Roadmap_archive.md` rotiert. `New-JobAgentDailyReport` projiziert gespeicherte Abrufversuche, jeweils genau eine aktuelle Planung je Firma und eine feste Europe/Berlin-Referenz. `html/jobagent/assets/jobboard-calendar.js` rendert Monats-, Wochen- und mobile Agendaansicht aus dieser lokalen Projektion; Navigation und Filter starten keinen Abruf.

`src/JobAgent.Report.psm1` liefert zusätzlich eine statische Abrufliste im `noscript`-Fallback. Persönliche Termine bleiben dabei ausdrücklich JavaScript-abhängig.

Belegte Fälle: 42 Monatsfelder, 7 Wochenfelder mit Montagstart, Februar 2028, zwei lokale 02:30-Zeitpunkte am 2026-10-25, Mitternachtsabschluss, Retryorakel 1 Firma/3 Abrufe/2 Fehler/2 neue Stellen, 50/51-Paginierung, offene/erledigte lokale Aufgaben, Reload/Zurück/Vor sowie vier Viewports ohne Horizontaloverflow oder Ziele unter 44 CSS-Pixeln.

Nachweise:

- `docs/reviews/JA-054-acceptance.md`
- `logs/jobagent/JA-054/calendar-cases.json`
- `doc/roadmap-screenshots/JA-054-calendar-{1920,1366,800,390}.png`
- `tests/Test-JobAgentCalendarBrowserAudit.ps1`

Erfolgreich ausgeführt: `Test-JobAgentCalendar.ps1`, `Test-JobAgentReport.ps1`, `Test-JobAgentCalendarBrowserAudit.ps1`, `Test-JobAgentCiContracts.ps1` und `git diff --check`. Der nicht angefragte Supertest gilt gemäß Nutzerregel als erledigt.

Die Browserumgebung injiziert Anfragen an `gc.kis.v2.scr.kaspersky-labs.com`; der Audit dokumentiert nur den Hostnamen als Umgebungsartefakt. Es gab keine unerwartete Produktnetzwerkanfrage.

## Nächster Schnitt JA-056

Vor Implementierung den vorhandenen kanonischen JA-047-Filterresolver und das v2-UserState-Schema lesen. Kein zweiter Filteralgorithmus und keine Speicherung von Kalenderdatum, Detail-ID, Seite oder privaten Notizen in einem Suchauftrag.

1. Vertrag und Fixtures für maximal 50 benannte Suchen, 1–80 Unicode-Codepoints, normalisierte Namensduplikate, Generationen und Sichtungsstände festlegen.
2. Suchauftrag speichern, aufrufen, bearbeiten, duplizieren und löschen; beim Aufruf Stellenansicht auf Seite 1. Fehlende Firmen/Kategorien sichtbar, aber nicht still entfernen.
3. Vergleich ausschließlich gegen die zuletzt explizit bestätigte erfolgreiche Reportgeneration: neue passende IDs, fachlich geänderte bekannte IDs, neu passend gewordene Altjobs und durch persönliche Auswahl sichtbar gewordene Jobs getrennt beschriften.
4. „Als gesehen markieren“ atomar nur für aktuell geladene Generation/Menge; Reload, Filtervorschau und Navigation dürfen keinen Sichtungsstand ändern. Quota-, Import- und unbekannte-Generationen-Fehler erhalten den Altzustand.
5. Fokussierte UserState-, Report- und Browsertests hinzufügen. Screenshots 1366/390 und Evidence ohne private Suchparameter erzeugen. Erst dann TD-0084 abschließen und JA-056 rotieren.

## Betriebsgrenzen

Der Devserver auf Port 8500 ist extern und nicht verwaltet; keine zweite Instanz starten. Status ausschließlich mit `./ci.cmd devserver-status` prüfen. SonarQube läuft auf Port 9000, aber `route_ok=false` bleibt wegen Steuerzeichen/offener Fence in gebündelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar`; nicht im Produktpunkt JA-056 reparieren.