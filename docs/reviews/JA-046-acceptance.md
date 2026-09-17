# JA-046 Abnahme – primaere Stellenboerse

Stand: 2026-09-17

## Ergebnis

`ConvertTo-JobAgentDailyReportHtml` erzeugt den Einstieg als Stellenboerse. Die sichtbare Reihenfolge ist Stellenangebote, lokale Suche und Filter, Stellenkarten und erst danach Datenstand und Quellen. Die bisherige Firmenansicht bleibt als separater lokaler Reiter erhalten.

## Nachgewiesene Anforderungen

- Die Desktopansicht verwendet ab 1024 CSS-Pixeln eine 280-Pixel-Filterspalte neben der flexiblen Trefferliste; darunter wird sie einspaltig und der Filter ist als aufklappbares `details` ausgefuehrt.
- Karten enthalten Titel, Firma, Ort, Arbeitsmodell, Anstellungsart, Arbeitszeit, Datumsherkunft, Zeitbeleg, einen auf 240 Zeichen begrenzten Auszug sowie getrennte Links zu Original-Stellenanzeige und Firma. Fehlende Einzelwerte werden als `Keine Angabe` dargestellt; ohne Beschreibung erscheint `Keine Beschreibung vorhanden`.
- Der No-JS-Ausgangszustand enthält sichere, serverseitig erzeugte Stellenkarten und den Datenstand. Persoenliche Funktionen sind wahrheitsgemaess als nicht verfuegbar ausgewiesen; es gibt keine funktionslosen Sterne.
- Leere Treffer unterscheiden `Keine offenen Stellen erfasst`, `Keine Treffer fuer diese Filter` und `Abruf unvollstaendig`.

## Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` – Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` – Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` – Exit 0; lokaler Fixture- und bestehender Coverage-Report über HTTP 200 geprüft.

Der Vollsupertest war nicht separat angefragt und gilt gemaess Nutzerregel als erledigt.

## Viewport-Evidence

Fixturegeneration: `scanrun:ja022-viewport-audit`, Datenmodus `synthetic_fixture`, lokale URL `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html`.

| Viewport | Datei | SHA-256 |
|---:|---|---|
| 1920x2200 | `doc/roadmap-screenshots/JA-046-jobs-1920.png` | `5595D524C23BBFEF26807C59EE6E8FC7782813D554D7351B04397ACA5347D1FD` |
| 1366x2200 | `doc/roadmap-screenshots/JA-046-jobs-1366.png` | `3CF0C89FBA41B0AB05721FD09935D2343F1710C1D08A7D4BAC172702749824FF` |
| 800x2200 | `doc/roadmap-screenshots/JA-046-jobs-800.png` | `CA167B26148E60B5F719A272E7EF6ACA34AAA225EADDC6C19AD86401E9861F69` |
| 390x2200 | `doc/roadmap-screenshots/JA-046-jobs-390.png` | `6D2A91A6955187A5B5CF19480A72031EA88EC4D9690E53AC2FA7062DA3C54410` |

Die Browserkonsole meldete ausschliesslich den vorbestehenden HTTP-404-Abruf von `/favicon.ico`; kein Reportskript, Stylesheet oder Bild wird extern geladen.
