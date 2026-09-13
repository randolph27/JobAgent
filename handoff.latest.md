# Handoff latest

Active: `TD-0041`; Status: `in-progress`; Branch: `master`.

# JA-027: Daily-Run-Akquise integriert

Stand: 2026-09-13T14:59:00+02:00

## Ergebnis

Der regulaere Einstieg `tools/Invoke-JobAgentDailyRun.ps1` fuehrt vor dem Scan automatisch eine budgetierte Akquisephase aus, wenn ein Hint-Store vorhanden ist. Die Phase nutzt die vorhandene Website-Ermittlung und Kandidatenverifikation, schreibt ihre Artefaktpfade ins CLI-JSON und ueberspringt kontrolliert bei fehlendem Hint-Store, Budget 0 oder `-DisableAcquisition`.

Neu verifizierte Firmen mit offizieller Karriere-/ATS-Quelle werden im selben Lauf in `src/JobAgent.DailyRun.psm1` per `AlwaysIncludeCompanyIds` in die Scan-Auswahl aufgenommen, auch wenn `next_scan_at` spaeter liegt. Der HTML-Bericht zeigt die automatisch akquirierte Firma unter `Neue Unternehmen` mit Website und Karrierequelle. `manual/PROGRAM.md` ist auf berufsneutrale Erfassung mit nachgelagerten Filtern synchronisiert.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0, 15 Faelle.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0, 29 Faelle.
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0, 10 Faelle.
- `.\ci.cmd route-check` -> Exit 0.
- `.\ci.cmd stp` -> Exit 0.
- SonarQube-Status auf `http://localhost:9000/api/system/status` war nicht erreichbar; `.\ci.cmd sonar-start` schlug fehl mit `docker_engine_unavailable; wsl_fallback=wsl_missing`.

## Naechster Anker

JA-027 bleibt offen. Naechster Hotspot: JA-027.2 Quellen-Nachfuellzyklus/Source-Inventory fuer verwertbare Website-/Karrierehinweise vervollstaendigen. Die automatische Startintegration verarbeitet vorhandene Hints, ersetzt aber noch keine vollstaendige Quellenzufuhr.
