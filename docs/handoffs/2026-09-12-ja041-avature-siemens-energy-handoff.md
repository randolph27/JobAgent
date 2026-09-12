# JA-041 Avature/Siemens Energy Handoff

Stand: 2026-09-12T21:56:00+02:00

## Ergebnis

Der Siemens-Energy-Hotspot wurde von unspezifischer Avature-Kategorie-/Hotjob-Erfassung auf zielrollenbezogene Avature-Suchseiten umgestellt.

- Avature-Portale werden anhand der `avature.portal.*`-Metadaten erkannt.
- Pro konfiguriertem Suchbegriff werden offizielle Avature-Search-Follow-ups erzeugt.
- `folderOffset`-Pagination wird als Pagination erkannt.
- Pagination-Links werden nicht mehr als Jobdetails gespeichert.
- Avature-Anker werden nur als Jobkandidaten akzeptiert, wenn der Text zielrollennahe IT-/Digital-/Technology-Fuehrung belegt.

## Evidence

- Funktionstest: `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- Funktionstest: `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- Funktionstest: `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- Live-Kontrolllauf Siemens Energy: `logs/jobagent/daily-run-20260912T195044560Z.json`
- HTML-Report: `html/jobagent/daily-run-20260912T195044560Z.html`

## Bewertung

Der fruehere Siemens-Energy-`result_limit_reached`-Pfad ist geschlossen: Der Kontrolllauf erzeugte 4 Raw-Jobs und 1 Snapshot statt 100 Raw-Jobs und 2 Snapshots im ersten Avature-Kontrolllauf. Der Lauf bleibt fachlich korrekt `PARTIAL`, weil Avature weiterhin nicht vollstaendig abgearbeitete zielrollenbezogene Pagination meldet.

## Naechster Schritt

JA-041 weiterfuehren: Avature-Pagination fuer Siemens Energy gezielt abschliessen oder als belegte Quellenbegrenzung mit reproduzierbarem Vertrag behandeln; danach BMW-Erreichbarkeit pruefen und die breitere Abschlussstichprobe erneut laufen lassen.
