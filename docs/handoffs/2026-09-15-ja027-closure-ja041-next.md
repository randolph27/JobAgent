# Handoff: JA-027 abgeschlossen, JA-041 als nächster Slice

Stand: 2026-09-15T14:00:00+02:00

## Abgeschlossener Roadmap-Punkt

`JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand` ist vollständig nach `Roadmap_archive.md` rotiert. Die aktive Roadmap enthält nur noch JA-041, UI-001 und JA-042.

Der letzte technische Blocker war ausschließlich die lokale Chrome-Headless-GPU-Lane bei 1920 px. `tests/Test-JobAgentHtmlViewportAudit.ps1` nutzt deshalb nun die lokale Playwright-CLI. Sie erzeugt reproduzierbar Screenshots für den synthetischen Daily-Run-Report und den produktiven Coverage-Report bei 390, 800, 1366 und 1920 px.

Wichtige Artefakte:

- `logs/jobagent/ja-022-viewport-audit.json` mit `status: ok`.
- `output/playwright/ja-022-fixture-viewport-{390,800,1366,1920}.png`.
- `output/playwright/ja-022-production-coverage-viewport-{390,800,1366,1920}.png`.
- `Roadmap_archive.md`, Abschnitt `Archiviert am 2026-09-15 – JA-027`.

Nachweise dieses Abschlusses:

- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` → Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` → Exit 0.
- `cmd /c .\ci.cmd route-check` → Exit 0.
- `cmd /c .\ci.cmd stp` → Exit 0.

`cmd /c .\ci.cmd supertest` wurde gestartet, aber der unabhängige Teiltest `tests/Test-JobAgentDailyRun.ps1` schloss nach mehreren Minuten nicht ab und die ausschließlich zugehörige Prozesskette wurde kontrolliert beendet. Es gibt daher keinen grünen Supertest-Nachweis. Das ist kein offener JA-027-Blocker; nach Nutzervertrag gilt ein nicht angefragter Supertest als erledigt.

## Aktiver Roadmap-Punkt

`TD-0053` / `JA-041 Berufsneutrale Stellenerfassung von Suchprofilen trennen` ist aktiv. Der nächste zusammenhängende Slice ist `JA-041.1`.

Ziel: Die Erfassung muss standardmäßig berufsneutral erfolgen. Leere Suchbegriffe bedeuten alle Berufe und dürfen nicht in die historische IT-Fallbackliste (`Head of IT`, `Director IT`, `IT Leitung`, `IT-Leitung`, `Leiter IT`, `CIO`) zurückfallen. Explizite CLI- oder Profilbegriffe bleiben ein kompatibler, begrenzter Suchscope. Berufsprofil und Klassifikation steuern später die Anzeige, nicht die Akquise oder allgemeine Stellenerfassung.

Primärer Scope:

- `tools/Invoke-JobAgentDailyRun.ps1`
- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.DailyRun.psm1`
- `manual/PROGRAM.md`
- gezielte Erweiterungen in `tests/Test-JobAgentDailyRun.ps1`, `tests/Test-JobAgentLiveScan.ps1` und `tests/Test-JobAgentSourceAdapters.ps1`

Nicht im Slice: Frameworkwechsel, Gebietsaufweitung, Bewerbungsautomatisierung, neue Stellenadapter, UI-001-Filter oder eine neue Firmenakquise-Welle.

Akzeptanz für JA-041.1:

1. Standardlauf mit leeren Suchbegriffen sammelt allgemeine offizielle Stellenlisten ohne IT-Vorselektion.
2. Quellen mit zwingendem Suchbegriff bleiben als eingeschränkt/`PARTIAL` sichtbar, statt irrtümlich Vollständigkeit oder Nulltreffer zu melden.
3. Pagination, Timeout, Ergebnislimits, München-20-km-Bereich und Freising bleiben erhalten; unbekannte Orte bleiben `UNKNOWN`.
4. Ein neues `logs/jobagent/JA-041-1-acceptance.json` hält Gitstand, Fixture-IDs, Befehle und erwartete/erhaltene Zähler fest.

Vor einer Änderung die aktuelle SearchTerms-Übergabe und alle impliziten IT-Filter von Daily-Run über LiveScan bis zur Normalisierung konkret nachverfolgen. Bestehende Parser- und Pagination-Arbeit bleibt erhalten. Erst nach allen drei JA-041-Unterpunkten ist ein Supertest erforderlich; ohne explizite Nutzeranforderung gilt er als erledigt.

## Zustand und Betriebsgrenzen

- Aktiver Todo: `TD-0053`; danach `TD-0054`/UI-001 und `TD-0055`/JA-042.
- Devserver wird ausschließlich über `cmd /c .\ci.cmd devserver-start` auf Port 8500 verwaltet.
- Sonar ist für PowerShell/statisches HTML nicht konfiguriert (`not-supported`); keinen grünen Sonar-Status behaupten.
- Keine reale Firmenmindestmenge und keine manuelle Firmenwelle als Done-Gate verwenden.
- Alle Firmen-, Website-, Karriere-, ATS- und Discovery-URLs bleiben mit Herkunft und Historie erhalten; keine Refresh- oder Abruffehler-Löschung.
