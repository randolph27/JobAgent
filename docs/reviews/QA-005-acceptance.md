# QA-005 Akzeptanznachweis

Stand: 2026-09-16

## Ergebnis

QA-005 ist fachlich abgenommen. Der isolierte Browserlauf pruefte die Daily- und Coverage-Abschnitte mit festem Locale `de-DE`, Zeitzone `UTC`, deaktivierten Animationen und geladenen Schriften. Die vier gerenderten Grundansichten wurden visuell gesichtet: keine unbegruendeten Ueberlappungen, kein Seiten-Overflow und keine unlesbaren oder unerreichbaren Bedienelemente.

Die sichtbaren nativen Mehrfachauswahlfelder duerfen ihre Inhalte vertikal scrollen; ihre vollstaendigen Optionen sind per nativer Tastaturbedienung erreichbar. Dies ist kein globaler Clipping-Ausschluss.

## Funktionstests

| Command | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` | Exit 0 |
| `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` | Exit 0 |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` | Exit 0 |

Der Browseraudit verwendete die isolierte Fixture `qa004-cb1366d514224e5e8f34bdc2ffc54cb3`. Die Fixture- und Report-Hashes blieben vor und nach der Interaktion identisch. Er pruefte Kontrast, sichtbaren Fokus, Labels, Tabs, Live-Status, Filter-/Reset-/Tab-/Pagination-Tastaturreise sowie alle vier erwarteten negativen Rendererfaelle (zu kleines Control, Overlap, Clipping, unsichtbarer Fokus).

Der anschliessende Lauf `./ci.cmd supertest` endete nach 755,67 s mit Exit 0. Der erste Abschlusslauf hatte den kanonischen Inventarvergleich bemängelt; `docs/reviews/QA-001-function-inventory.json` wurde danach mit dem vorgesehenen `-WriteInventory` aus den aktuellen Quelltexten erneuert und `Test-JobAgentTestMatrix.ps1` mit Exit 0 bestätigt. Im Wiederholungslauf waren alle Teiltests gruen.

## Sichtung und Referenzen

| Viewport | Referenz | SHA-256 | Befund |
| --- | --- | --- | --- |
| 390x2200 | `doc/roadmap-screenshots/QA-005-daily-null-results-390.png` | `6e1c15bb7df13bafae054408e98585da56ae231784a4f57d6d6a076d8c06d2f5` | Mobilansicht: einspaltige Controls, kein Seiten-Overflow. |
| 800x2200 | `doc/roadmap-screenshots/QA-005-daily-null-results-800.png` | `25f1bd0f5432fbe8f62ca107420e4cc0b0ed8e183406fa466694b426d05975f4` | Tabletansicht: Filterraster ohne Control-Overlap. |
| 1366x2200 | `doc/roadmap-screenshots/QA-005-daily-null-results-1366.png` | `e0ce8f18d6f432e7fcfc9d43763ed69d64c1a529b9f49629c3bdbe5fa36fb108` | Desktopansicht: Karten und Filter erreichbar, kein horizontaler Seiten-Overflow. |
| 1920x2200 | `doc/roadmap-screenshots/QA-005-daily-null-results-1920.png` | `e6f7f2518e18c1ffded260580d141c535547cfd34a9bf48f4c98703acf1015ef` | Breite Desktopansicht: stabile Hierarchie und lesbare Berichtsabschnitte. |

Die Referenzen zeigen den reproduzierbaren Nulltrefferzustand nach dem Browseraudit. Die zugehoerige maschinenlesbare Evidence liegt unter `logs/jobagent/QA-004/qa004-cb1366d514224e5e8f34bdc2ffc54cb3/browser-cases.json`.
