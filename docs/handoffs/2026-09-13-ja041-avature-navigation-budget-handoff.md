# JA-041 Handoff: Avature-Navigation und Seitenbudget

Stand: 2026-09-13T02:54:00+02:00

## Ergebnis

- Avature-Listing-, Sprach- und Kategoriepfade werden nicht mehr als konkrete Stellen akzeptiert, nur weil sie unter `/jobs/...` liegen.
- Generische Avature-Navigationen wie `/jobs/Jobs/<Suchbegriff>`, `SearchJobs*`, Login/Profile/Register/StayConnected/ResumeUpload/ResetPassword bleiben Quellen-/Navigationspfade, keine Jobs.
- `FolderDetail`-Treffer bleiben als konkrete Stellen zulaessig.
- Avature-Seiten erzeugen keine zusaetzlichen generischen Jobportal-Follow-ups mehr, wenn zielrollenbezogene Avature-Such-Follow-ups aktiv sind.
- Pagination gilt nur dann als offen, wenn noch nicht besuchte Folgeseiten uebrig sind; bereits abgearbeitete Next-Links erzeugen kein kuenstliches `pagination_detected`.
- `MaxPagesPerSource` ist fuer Live-/Pilotlaeufe bis 100 steuerbar.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0
- Live-Kontrolllauf Siemens Energy: `logs/jobagent/daily-run-20260913T005454858Z.json`, `PARTIAL`, 1 Raw-Job, 1 Snapshot, 0 Zielrollentreffer. Die Partial-Ursache ist das bewusst enge Ergebnis-/Detailbudget des Kontrolllaufs, kein Abschlussgate.

## Offene Punkte

- Breiter Avature-Abschlusslauf fuer Siemens Energy braucht ein reproduzierbares Budget oder einen expliziten Quellenbegrenzungsvertrag; ein 60-Seiten-Lauf wurde wegen Laufzeit manuell abgebrochen.
- BMW-Erreichbarkeit und breitere JA-041-Abnahme bleiben offen.
