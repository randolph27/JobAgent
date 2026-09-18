# Uebergabe-Details

Stand: 2026-09-18T20:46:28.9862896+02:00

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

Der Suchauftrag-/Sichtungsvertrag ist nun als `docs/contracts/JA-056-saved-searches.md` festgelegt. `saved_searches` ist im v2-Schema optional und leer vorbelegt. `jobboard-state.js` validiert maximal 50 stabile Aufträge, normalisierte Namen, kanonische Filter und atomare Baseline-/Löschoperationen. `compareSavedSearch` verarbeitet ausschliesslich bereits kanonisch gefilterte IDs und trennt neue, geänderte und durch persönliche Auswahl sichtbare Treffer.

Belegt durch `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` (je Exit 0). Kein Supertest, Browseraudit, Livecrawl oder Sonarlauf in diesem unvollständigen Roadmap-Punkt.

1. Suchauftrag-UI mit Speichern, Aufrufen, Bearbeiten, Duplizieren und Löschen integrieren; Aufruf setzt Stellenansicht und Seite 1. Fehlende Firmen/Kategorien bleiben als nicht verfügbare aktive Auswahl sichtbar.
2. Die stabile `scan_run_id` aus der Reportpublikation als Generationskennung in die Clientdaten aufnehmen und die bestehende Filterfunktion für Baseline und Vergleich wiederverwenden.
3. „Als gesehen markieren“ erst nach erfolgreicher Speicherung der exakt geladenen Generation aktivieren; Quota-, Import- und unbekannte-Generationen-Fehler lassen den Altzustand unverändert.
4. Fokussierten SavedSearch-/Browser-Test, Screenshots 1366/390 und Evidence ohne private Suchparameter ergänzen. Erst dann TD-0084 abschließen und JA-056 rotieren.

## Betriebsgrenzen

Der Devserver auf Port 8500 ist extern und nicht verwaltet; keine zweite Instanz starten. Status ausschließlich mit `./ci.cmd devserver-status` prüfen. SonarQube läuft auf Port 9000, aber `route_ok=false` bleibt wegen Steuerzeichen/offener Fence in gebündelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar`; nicht im Produktpunkt JA-056 reparieren.
