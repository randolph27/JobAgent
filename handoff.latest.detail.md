# Uebergabe-Details

Stand: 2026-09-18T21:07:05.2527927+02:00

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

## Aktueller Schnitt JA-056

Der Suchauftrag-/Sichtungsvertrag ist als `docs/contracts/JA-056-saved-searches.md` festgelegt. `saved_searches` ist im v2-Schema optional und leer vorbelegt. `jobboard-state.js` validiert maximal 50 stabile Aufträge, normalisierte Namen, kanonische Filter und atomare Baseline-/Löschoperationen. `compareSavedSearch` verarbeitet ausschliesslich bereits kanonisch gefilterte IDs und trennt neue, geänderte und durch persönliche Auswahl sichtbare Treffer.

Die Report-Clientdaten enthalten `scan_run_id`. `window.JobAgentSearch` verwendet die bestehende Filterfunktion sowohl für das Rendern als auch für die Suchauftrags-Baseline. Das eingebettete `jobboard-saved-searches.js` bietet getrennte lokale Aktionen für Speichern, Aufrufen, Bearbeiten, Duplizieren, Löschen und Sichtungsbestätigung; die Teilmenge „Neu seit letzter Sichtung“ markiert neue und fachlich geänderte Karten ohne zusätzlichen Filteralgorithmus. `tests/Test-JobAgentSavedSearches.ps1` prüft Generationsbaseline, Neu-/Änderungsvergleich, explizite Sichtung, UI-Assetsyntax und die Reportverdrahtung.

Belegt durch `pwsh -NoProfile -File .\tests\Test-JobAgentSavedSearches.ps1`, `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` (je Exit 0). Kein Supertest, Livecrawl oder Sonarlauf in diesem unvollständigen Roadmap-Punkt. Der neue gezielte Browserpfad ist vorhanden, aber noch nicht erfolgreich als Evidence abgeschlossen.

Der Basis-Commit `45673ce` ist auf `origin/master` gepusht. Die Übergabedateien selbst werden in einem folgenden Metadaten-Commit mitgeführt; der neue Agent startet anhand der hier dokumentierten Roadmap- und Todo-Lage, nicht bei JA-050.

1. Den fokussierten Browserpfad `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -SavedSearchOnly` mit isolierter Session ausführen und dessen 1366/390-Evidence sichern.
2. Mehrgenerationen-, Import-/Export-, Quota- und unbekannte-Generationen-Fälle in den fokussierten Pfad aufnehmen; alte Baselines müssen bei jedem Fehler unverändert bleiben.
3. `docs/reviews/JA-056-acceptance.md` und die vorgesehenen Evidence-Dateien ohne private Suchparameter erstellen. Erst dann TD-0084 abschließen und JA-056 rotieren.

## Betriebsgrenzen

Der Devserver auf Port 8500 ist extern und nicht verwaltet; keine zweite Instanz starten. Status ausschließlich mit `./ci.cmd devserver-status` prüfen. SonarQube läuft auf Port 9000, aber `route_ok=false` bleibt wegen Steuerzeichen/offener Fence in gebündelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar`; nicht im Produktpunkt JA-056 reparieren.
