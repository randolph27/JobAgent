# JA-027 Handoff: Daily-Run-Akquise

Stand: 2026-09-13T14:55:00+02:00

## Ergebnis

Der regulaere Einstieg `tools/Invoke-JobAgentDailyRun.ps1` startet jetzt standardmaessig vor dem Scan eine budgetierte JA-027-Akquisephase, sofern ein Hint-Store vorhanden ist und `-AcquisitionCandidateBudget` groesser als 0 ist. Die Phase ruft die bestehende Website-Ermittlung und Kandidatenverifikation auf, dokumentiert deren Artefakte im CLI-JSON und zaehlt neue Arbeitgeber mit offizieller Karriere-/ATS-Quelle.

Neu verifizierte Karrierearbeitgeber werden im selben Daily-Run ueber `AlwaysIncludeCompanyIds` in `src/JobAgent.DailyRun.psm1` in die Scan-Auswahl aufgenommen, auch wenn ihr `next_scan_at` erst spaeter faellig waere. Der HTML-Bericht zeigt die im Lauf neu akquirierte Firma mit Website und Karrierequelle. `manual/PROGRAM.md` ist auf berufsneutrale Erfassung und die neue Akquisephase synchronisiert.

## Geaendert

- `tools/Invoke-JobAgentDailyRun.ps1`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `manual/PROGRAM.md`
- `Roadmap.md`
- `todo.state.json`
- `todo.events.jsonl`
- `logs/jobagent/JA-027-regular-start-acquisition.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0, 15 Faelle inklusive `daily_run_cli_acquires_and_scans_new_company`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0, 29 Faelle.
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0, 10 Faelle.

## Offen

JA-027 bleibt offen. Der naechste Hotspot ist JA-027.2: Quellen mit verwertbaren Website-/Karrierehinweisen priorisieren, Source-Inventory aktualisieren und den Nachfuellzyklus so schliessen, dass nicht nur vorhandene Hints verarbeitet werden.
