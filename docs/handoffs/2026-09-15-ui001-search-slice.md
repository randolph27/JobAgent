# UI-001 Wechselstatus: lokale Firmen- und Stellensuche

Stand: 2026-09-15

## Umgesetzt

- src/JobAgent.Report.psm1 erzeugt zusätzlich zum bisherigen Tagesreport eine berufsneutrale Basis aus allen validen aktiven Stellen (sections.active_jobs) und allen gespeicherten Firmen (sections.companies).
- Die HTML-Ausgabe enthält eine lokale Suchoberfläche mit getrennten Stellen-/Firmentabs, vollständigen Ergebniszählern, clientseitiger Pagination (50 Einträge), Hash-basierter Rücknavigation und Reset.
- Stellenfilter: Unicode-normalisierter Freitext über Titel, Arbeitgeber und belegte Berufskategorie; Mehrfachauswahl innerhalb eines Felds als ODER, verschiedene Felder als UND; Gebiet, Arbeitsmodell, Anstellungsart, Arbeitszeit und Aktualität.
- Gebietsfacetten unterscheiden München Stadt, München 20 km, Freising Stadt, Landkreis Freising, unpräzises Freising, Remote/Hybrid mit belegtem Zielgebietsbezug und UNKNOWN. Nicht belegte Stadt-/Landkreiswerte werden nicht hergeleitet.
- Links werden im Browser nur für http/https erzeugt; die eingebetteten JSON-Daten werden gegen einen Script-Ausbruch escaped.

## Verifiziert

- pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1 beendet erfolgreich.
- Playwright gegen den lokalen Devserver auf http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html: Freitext Director reduzierte die Stellenansicht von 2 auf 1 Treffer; Tabwechsel, Reset, URL-Zustand und lokale Filterinteraktion funktionierten. Während der Filterinteraktion entstanden keine API- oder Daily-Run-Requests.
- Der vorhandene Viewport-Audit erzeugte Screens für 390, 800, 1366 und 1920 px. Die einzige Browser-Konsolemeldung war der fehlende favicon.ico-Abruf (HTTP 404), kein JavaScript-Fehler.
- pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1 wurde durch die Zeitgrenze des Tool-Runners abgebrochen; kein fachlicher Assertion-Fehler wurde ausgegeben. Der Test startet bei der Coverage-Ermittlung langlebige PowerShell-Child-Prozesse. Diese vor dem nächsten Lauf kontrolliert prüfen und nur mit ausreichender Laufzeit ausführen.

## Nicht abgeschlossen

UI-001 bleibt in-progress; nicht rotieren.

Offen für den nächsten Agenten:

1. Einen dedizierten, schnellen Browser-Funktionstest für UI-001 ergänzen. Fixture: mehr als 250 Firmen/Stellen mit erwarteten IDs für Position 251, München+Buchhaltung, Freising+Pflege, Teilzeit+Hybrid, UNKNOWN, Umlautsuche und Nulltreffer.
2. In diesem Test Pagination, Mehrfachfilter, Reset und Browser-Rücknavigation mit exakten Zählern/IDs abnehmen; zusätzlich bestätigen, dass der Store vor/nach Filterwechsel bytegleich bleibt.
3. Arbeitszeit ist im aktuellen Store-Schema nicht als eigenes Stellenfeld vorhanden. UI zeigt deshalb ausschließlich UNKNOWN. Vor einer Erweiterung Schema, StatusMachine, Adapter und Fixtures gemeinsam ergänzen; keinen Wert ableiten.
4. Nach vollständiger Browserabnahme UI-001-Evidence unter logs/jobagent/UI-001-*.json erzeugen, Roadmap-Punkt abschließen und gemäß Roadmap archivieren. Erst danach JA-042 beginnen.
5. TD-0056 (CI-Drift) ist unabhängig offen und erst nach UI-001 priorisiert behandeln.

## Geänderte Produktdateien

- src/JobAgent.Report.psm1
- tests/Test-JobAgentReport.ps1
- tests/Test-JobAgentHtmlAudit.ps1

## Arbeitsbaum und Prozesshinweis

Vor Commit wurden ausschließlich testgenerierte Screens, HTML-Artefakte und Playwright-Sitzungsordner verworfen. Der Commit enthält nur die drei Produkt-/Testdateien und diesen Wechselstatus.
