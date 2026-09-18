# Handoff latest

Stand: 2026-09-18T08:24:54.903+02:00

## Zustand

- Branch: `master`; Arbeitsbaum wird mit diesem Handoff committed und gepusht.
- Aktiver fachlicher Anker: `TD-0076` / `JA-048`; Roadmap und Todo bleiben offen.
- Kein Supertest ausgefuehrt: gemaess Nutzeranweisung gilt der nicht angeforderte Supertest als erledigt.
- Der Route-Check bleibt wegen elf vorbestehender Steuerzeichen/Markdown-Fence-Funde unter `.ci/tools/sonar/**/jre/legal/**` rot. Diese Dateien wurden nicht geaendert und sind nicht Teil von JA-048.

## Umgesetzter Stand JA-048

- `src/JobAgent.Report.psm1` rendert auf Karten zwei getrennte Schalter: Favorit und Bewerbungsmarkierung. Beide verwenden den vorhandenen browserlokalen v1-Store, haben eigene Texte, `aria-pressed`, sichtbare Speicherergebnisse und mindestens 44 CSS-Pixel.
- Ein Titel oeffnet die lokale Detailansicht ueber `#job=<job_id>` und behaelt den bestehenden Filterzustand. Die Detailansicht zeigt Firma, Ort, Arbeitsbedingungen, Zeit-/Aktualitaetsdaten, Beschreibung, Anforderungen und getrennte Original-/Firmenlinks.
- Der Rueckweg in die Trefferliste setzt den Fokus auf den zuvor geoeffneten Jobtitel. Eine Markierung wird nach erfolgreichem lokalen Speichern erneut gerendert; Karten, Detailansicht und bestehende Favoriten-/Bewerbungsfilter lesen damit dieselbe Wahrheit.
- Der derzeitige Hash-Parser verwirft unbekannte `job`-IDs und normalisiert zur Liste. Der in JA-048 geforderte explizite Leerzustand fuer unbekannte Job-IDs fehlt noch.

## Noch offen vor Abschluss von JA-048

1. Unbekannte `job`-ID als sicheren Leerzustand rendern statt zum Listenhash zu normalisieren.
2. Markierte, nicht mehr im aktiven Report enthaltene Jobs aus dem lokalen Store als historische Favoriten-/Bewerbungseintraege mit Status „Nicht mehr im aktuellen offenen Stellenbestand“ darstellen; keine falsche Verfuegbarkeit oder Loeschung persoenlicher Historie.
3. Spezifische Browserassertions fuer Detail-Hash, zwei unabhaengige Schalter, Karten-/Detail-Synchronisierung, Rueckfokus, unbekannte ID und historische Markierungen ergaenzen. Danach JA-048 gegen die Roadmap-Akzeptanz pruefen und erst dann rotieren.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` -> Exit 0; isolierte Fixture, 264 Stellen/251 Firmen, Viewports 390/800/1366/1920.
- `git diff --check` -> keine Whitespace-Fehler.

## Naechster Schritt

`TD-0076` fortsetzen, zuerst den unbekannten-ID-Leerzustand und die historischen lokalen Markierungen implementieren. Danach die spezifischen JA-048-Browserfaelle erweitern. JA-052/JA-053/JA-055 bleiben abhaengige Folgepunkte; keine Rotation der Roadmap vor vollstaendiger Akzeptanz.
