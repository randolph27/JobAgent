# JA-041 Live-Stichprobe und False-Positive-Filter

Stand: 2026-09-12T21:35:00+02:00

## Ergebnis

- Breiter 10-Firmen-Live-Pilot: `logs/jobagent/daily-run-20260912T190510537Z.json`
  - Status `PARTIAL`
  - 10 Firmen gescannt, 12 Adapterversuche
  - 99 Raw-Jobs, 74 Snapshots
  - 7 vollstaendig erfolgreiche Quellen, 2 unsichere Quellen, 1 nicht erreichbare Quelle
  - 0 Zielrollentreffer
- Gefundener Adapter-Hotspot:
  - Siemens Energy: ATS-Kategorie-/Accountseiten wurden als Jobdetails akzeptiert.
  - Bayerischer Rundfunk: Bewerbungs-/CheckLogin-Seiten wurden zusaetzlich zu Description-Seiten als Jobdetails akzeptiert.
- Umsetzung:
  - `src/JobAgent.LiveScan.psm1` schliesst ATS-Kategorie-, Account-, Registrierungs-, Bewerbungs-/CheckLogin- und Labor-Condition-Seiten vor Jobdetail-Erkennung aus.
  - `tests/Test-JobAgentLiveScan.ps1` deckt ATS-Kategorie-/Accountseiten und Bewerbungs-/CheckLogin-Ausschluss ab.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- Siemens-Kontrolllauf: `logs/jobagent/daily-run-20260912T192545574Z.json`
  - Status `PARTIAL`
  - 1 Firma, 10 Raw-Jobs, 1 Snapshot, 0 Zielrollentreffer
  - Keine Kategorie-/Accountseiten mehr als gespeicherte offizielle Detailseiten; offen bleibt Ergebnislimit/Oracle-ATS-Familie.
- Bayerischer-Rundfunk-Kontrolllauf: `logs/jobagent/daily-run-20260912T192801804Z.json`
  - Status `SUCCESS`
  - 1 Firma, 10 Raw-Jobs/gepruefte Jobs/Snapshots
  - 0 unsichere Quellen, 0 Zielrollentreffer

## Naechster Anker

JA-041 weiterfuehren: Siemens-Energy-Ergebnislimit/Oracle-ATS-Familie priorisieren, danach BMW-Erreichbarkeit pruefen und Abschlussgate/breitere Stichprobe erneut laufen lassen.
