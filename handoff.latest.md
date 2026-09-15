# Handoff latest

Stand: 2026-09-15T20:54:00+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: QA-003.3 regulaeren Start, Wiederanlauf und Betrieb vollstaendig mit isolierten Fixture-Laeufen abnehmen.
- Branch: `master`
- HEAD: dieser Commit (`test: korreliere Akquise und Daily-Run`)
- Upstream: `origin/master`
- Worktree: `clean` nach Commit und Push
- Route: `True`

## Versionierter Teilschnitt

- Commit: dieser Handoff-Commit (`test: korreliere Akquise und Daily-Run`)
- `tools/Invoke-JobAgentDailyRun.ps1`: Die Akquisephase erhaelt dieselbe `run_id` wie der umschliessende Managed Daily-Run und gibt sie im CLI-Ergebnis aus.
- `tests/Test-JobAgentDailyRun.ps1`: Erst- und Folgelauf verlangen die gemeinsame Akquise-/Run-ID.
- `docs/reviews/QA-003-cli-cases.md`: Produktive CLI-Einstiege, isolierte Fixture-Aufrufe und zugehoerige Vertraege inventarisiert.
- STP-Artefakte: `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`, `handoff.latest.json`.

## Verifizierte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` — Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` — Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1` — Exit 0.
- AST-Parse von `tools/Invoke-JobAgentDailyRun.ps1` — Exit 0.
- Isolierter CLI-Smoke mit `-AcquisitionCandidateBudget 0` — Exit 0; `acquisition.run_id == run_id`.

Nicht als bestanden gewertet: `Test-JobAgentDailyRun.ps1`. Der vollstaendige Test wurde vor Abschluss beendet, damit keine parallelen Temp-Roots weiterlaufen. Kein Supertest ausgefuehrt; nach Nutzerregel ist ein nicht ausdruecklich angeforderter Supertest erledigt und wird nicht nachgeholt.

## Fachlicher Ausgangszustand

- QA-003.1 und QA-003.2 sind abgeschlossen. Der Adapter dedupliziert Seiten, URLs und externe Stellen-IDs, meldet Limitlaeufe `PARTIAL` und klassifiziert defektes strukturiertes JSON als `PARSING_ERROR`.
- Kontrollierte Transporttests decken 200/404/429/503, Timeout, DNS, TLS, Redirectschleife und `Retry-After` mit Requestanzahl, Reihenfolge und Fehlerklasse ab. `Retry-After` verhindert den unmittelbaren Wiederholungsabruf.
- Fetch-Environment und Fetch-Error-Inspection redigieren Authorization-/Tokenwerte und behandeln fehlende Probe-Fixtures sowie fehlerhafte Inspection-Logs fail-closed.
- Permanente Nachweise: `docs/reviews/QA-003.1-discovery-verification.md`, `docs/reviews/QA-003.2-adapter-error-handling.md`, `docs/reviews/QA-003-cli-cases.md`.

## Naechster Arbeitsschnitt: QA-003.3

1. `Test-JobAgentDailyRun.ps1` allein in kontrolliertem Hintergrundprozess starten, auf den echten Exitcode warten und die neue gemeinsame `run_id`-Assertion bestaetigen.
2. Die uebrigen QA-003-Tests aus `Roadmap.md` seriell ausfuehren: FetchEnvironment, FetchErrorInspection, SourceAdapters, SourceVerification, LiveScan, RegisterDiscovery, JobBoardDiscovery, RegionalDiscovery, CompanyDedupeScale und DiscoverySourceInventory. Bereits aktuelle Erfolge fuer CompanyCandidateVerification, ImportWaves und Operations nicht kuenstlich wiederholen.
3. Zwei frische isolierte Projektroots im FixtureMode mit identischer Eingabe ausfuehren. Soll-ID-Liste sowie Checkpoint-, Store- und Reporthashes vergleichen. Der Folgelauf darf keine Firmen oder Stellen duplizieren.
4. Fehler vor und nach Kandidatencheckpoint sowie vor Store-/Reportpublikation mit den bestehenden Resume- und Managed-Run-Tests belegen. Resume darf genau einmal committen; bis zum atomaren Austausch bleibt der letzte gueltige Bericht sichtbar.
5. Erst bei allen Einzel-Erfolgen QA-003.3 und QA-003 abhaken, Todo/Checkpoint synchronisieren und den Roadmap-Punkt rotieren. QA-004 bis QA-006 bleiben danach in `Roadmap.md` aktiv.

## Roadmap und Todo

- Keine Roadmap-Rotation vorgenommen: QA-003 ist offen; die drei Pflichtunterpunkte sind nicht vollstaendig belegt.
- `TD-0060` bleibt offen und ist der naechste priorisierte Punkt. `TD-0061` bis `TD-0063` bleiben nachgelagert offen. `TD-0056` ist ein separater CI-Driftbefund.
