# QA-006 Abnahme

Stand: 2026-09-16. Commitbasis: `38450ce4042e241857f2b9b91bb91b20a93580de` vor den lokalen QA-006-Hash-Erweiterungen.

Der Runner erzeugt atomare Berichte mit vollständiger Ergebnisliste, Child-Output, Exitcode, Zeitstempeln, PowerShell-Version, Arbeitsverzeichnis sowie Inventar-, Matrix- und Quellhash. Der Contracttest deckt Erfolg, Nichtnull-Exit, Exception, ungültige Plandaten, Timeout, Abbruch und `not-run` ab.

| Nachweis | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\tests\Test-JobAgentSupertestContract.ps1` | Exit 0 |
| `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` | Exit 0 |
| `./ci.cmd supertest` | zwei Läufe, Exit 0; 28/28 bestanden |

Die finalen Berichte sind `logs/jobagent/QA-006/20260916T131614134Z/summary.json` und `logs/jobagent/QA-006/20260916T133027413Z/summary.json`. Ihr normalisierter Vergleich ist in [QA-006-run-comparison.json](QA-006-run-comparison.json) festgehalten: Status, Fallzahl, Reihenfolge und alle drei Eingabehashes sind identisch. Zeitstempel, Child-Ausgabe und temporäre Arbeitswurzel sind volatile Felder.

Lines/Branches: `not-supported`; für dieses PowerShell/HTML-Projekt ist keine belastbare Coverage-Messlane konfiguriert. Browser- und Visual-Evidence laufen innerhalb der 28 Tests für Daily/Coverage bei 390/800/1366/1920 px. Sonar: `not-supported` gemäß CI-Konfiguration. Device/Android: `not-applicable` für den Webbericht-Vertrag.
