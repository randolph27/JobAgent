# Handoff: QA-003 abgeschlossen, QA-004 als naechster Arbeitsschnitt

## Verbindlicher Stand

- Branch: `master`; QA-003 ist aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.
- `TD-0060` ist abgeschlossen. Offen bleiben `TD-0061` (QA-004), `TD-0062` (QA-005), `TD-0063` (QA-006) und der unabhaengige CI-Driftbefund `TD-0056`.
- Der Arbeitsbaum wird mit diesem Handoff bereinigt, gestaged, committed und gepusht. Der neue Agent beginnt bei QA-004.1; keine laufende Entwicklung, keine offenen Temp-Roots und kein aktiver Daily-Run werden vorausgesetzt.

## QA-003: gelieferter Nachweis

- Alle 14 festgelegten QA-003-Funktionstests liefen mit Exit 0: CandidateVerification, FetchEnvironment, FetchErrorInspection, SourceAdapters, SourceVerification, LiveScan, RegisterDiscovery, JobBoardDiscovery, RegionalDiscovery, CompanyDedupeScale, DiscoverySourceInventory, ImportWaves, DailyRun und Operations.
- `Test-JobAgentCiContracts.ps1` lief mit Exit 0.
- `Test-JobAgentDailyRun.ps1` erzeugt nun zwei frische, bytegleiche CLI-Fixturewurzeln. Es vergleicht normalisierte SHA-256-Hashes der Firmen, Quellen, Stellen, Kandidatencheckpoints sowie JSON-, Markdown- und HTML-Reports. Lauf-IDs, UTC-Zeitstempel, Laufstempel und absolute Temp-Pfade werden als volatile Werte normalisiert.
- `docs/reviews/QA-003-cli-cases.md` beschreibt die produktiven CLI-Einstiege und den Zweiwurzelvergleich. Die vorhandenen Resume-, `PARTIAL`-, `wake_at`-, Lock-, Logrotations- und atomaren Publikationsfaelle bleiben in DailyRun-, Operations- und Candidate-Verification-Tests abgedeckt.
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -WriteInventory` aktualisierte das kanonische QA-001-Inventar auf 577 Eintraege; der anschliessende Matrix-Contract lief mit Exit 0.
- `./ci.cmd supertest` lief vollstaendig mit Exit 0 in 384,59 s. Der erste Versuch scheiterte ausschliesslich an einer Sandbox-Sperre des vorhandenen npm-Caches beim AJV-Schematest. Der gezielte Schematest und der Wiederholungslauf mit Zugriff auf den lokalen Cache liefen Exit 0.

## Naechster Arbeitsschnitt: QA-004.1

Ziel: Die vorhandene UI-Funktionspruefung von Stichproben zu einer vollstaendlichen, datenunabhaengigen Bedienmatrix erweitern.

1. Bestehende 251-Firmen-/256-Stellen-Fixture erhalten und Grenzfaelle fuer 0, 1, 49, 50, 51, 250 und 251 Datensaetze ergaenzen. Firmen ohne offene Stelle und Firmen mit mehreren Stellen explizit abbilden.
2. Jede vorhandene Gebiets-, Arbeitsmodell-, Anstellungsart-, Arbeitszeit- und Aktualitaetsoption einschliesslich `UNKNOWN` einzeln pruefen. Mehrfachwerte desselben Felds sind ODER; unterschiedliche Felder sind UND.
3. Unicode mit NFC/NFD, Gross-/Kleinschreibung, Umlaute, Leerzeichen, mehrere Suchbegriffe, Sonderzeichen sowie die exakten 7-/30-Tage-Grenzen bei festem Bezugsdatum abdecken. Ein leerer Filter muss den vollstaendigen berufsneutralen Bestand zeigen.
4. Nur isolierte Fixtures und echte Browserinteraktionen verwenden. Keine produktiven Store-Mutationen, keine externen Browserrequests und keine unbelegten Controls erfinden. Beim Browsertest Devserver ausschliesslich ueber `./ci.cmd devserver-status` und gegebenenfalls `./ci.cmd devserver-start` verwalten; fremde Listener nie beenden.
5. Erst nach vollstaendlichem QA-004-Abschluss ist genau ein Supertest faellig. Bei Fehlern zuerst nur den betroffenen Funktionstest reparieren. QA-005 und QA-006 bleiben nachgelagert.

## Relevante Dateien

- Roadmap und Detailvertrag: `Roadmap.md`, Abschnitt QA-004.
- UI-Test: `tests/Test-JobAgentUiBrowserAudit.ps1`.
- Daten-/Renderervertraege: `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentCoverage.ps1`, `src/JobAgent.Report.psm1`, `src/JobAgent.Coverage.psm1`.
- Vorbedingung und Testinventar: `docs/test-matrix.json`, `docs/reviews/QA-001-function-inventory.json`.
- Statusquellen: `todo.current.md`, `todo.state.json`, `handoff.latest.md`.

## Bekannte Grenzen

- Sonar bleibt fuer dieses PowerShell-/HTML-Projekt `not-supported`; ein laufender Server auf Port 9000 ersetzt keine Analyse.
- Android-/Emulatornachweise sind fuer QA-004 nicht anwendbar.
- Die Roadmap verlangt keine reale Firmenwelle und keine Live-Netzwerkrecherche als Testnachweis.
