# Handoff latest

Stand: 2026-09-15T17:45:02.540+02:00

## Zustand

- Active: `TD-0055`, Status `in-progress`; der Hauptpunkt `JA-042` bleibt bis JA-042.3 aktiv.
- Branch/HEAD vor dem geplanten Commit: `master` / `36991e9caeef`; Upstream `origin/master`, vorher `0/0`.
- JA-042.1 und JA-042.2 sind abgenommen. Es gibt keinen vollstaendig erledigten Roadmap-Hauptpunkt zum Rotieren.

## Abgeschlossener Slice: JA-042.2

- `tools/Verify-JobAgentCompanyCandidates.ps1` berechnet aus zukuenftigen `RETRY_SCHEDULED`-Eintraegen den fruehesten `wake_at`-Zeitpunkt. Der Lauf endet; er wartet nicht aktiv.
- `tools/Invoke-JobAgentDailyRun.ps1` uebernimmt den fruehesten Akquise-Wiedervorlagezeitpunkt und gibt ihn im regulaeren Laufresultat aus.
- `src/JobAgent.Operations.psm1` publiziert `wake_at` atomar mit dem Daily-Run-Status. Ein Fehlerlauf behaelt weiterhin den zuletzt publizierten Report sowie dessen Wiedervorlage als veralteten Stand.
- Der vorhandene Resultat-Checkpoint der Kandidatenverifikation setzt einen Abbruch vor dem Store-Commit fort; die serielle atomare Commit-Phase uebernimmt Resultate hoechstens einmal. Die Statusmaschine bewahrt Stellen bei Teil- und Fehler-Scans und erzeugt keine falschen NEW/CLOSED/REMOVED-Ereignisse bei Profilfiltern.
- Evidence: `logs/jobagent/JA-042-2-acceptance.json`.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
```

Alle drei Funktionstests endeten mit Exit 0. Kein Browseraudit: keine HTML-Aenderung. Kein Supertest: nicht angefragt und daher gemaess Auftrag erledigt/nicht als offenes Gate zu behandeln. Sonar bleibt `not-supported` (kein konfigurierter Scanner fuer diese PowerShell-/HTML-Codebasis).

## Naechster Arbeitsschnitt: JA-042.3

1. In `tests/Test-JobAgentCompanyDedupeScale.ps1` eine isolierte 1.000-Firmen-Fixture mit Dubletten, Domain-only-Kandidaten, Berufs-/Gebietsvarianten und Quellenfehlern ausfuehren. Endliche Budgets, Hostwellen und Cursorfortsetzung beweisen; keine reale Firmenwelle starten.
2. Zwei regulaere Fixture-Daily-Runs in `tests/Test-JobAgentDailyRun.ps1` und `tests/Test-JobAgentReport.ps1` belegen: erster Lauf neue Firma mit offizieller Karrierequelle und mehreren Berufen, zweiter Lauf dieselbe Firma plus genau eine neue; IDs, Zaehler und WebIF-Filter exakt vergleichen.
3. `docs/company-discovery-operations.md` um Runcommand, Reportpfade, Budgetgrenzen und Resume-Anleitung aktualisieren. Anschliessend fokussierte Tests, Browseraudit bei sichtbarer Aenderung, Evidence `logs/jobagent/JA-042-3-acceptance.json`, Roadmap-/Todo-/Handoff-Sync. Erst dann `JA-042` als ganzes rotieren.

## Nebenbedingung

`TD-0056` (Immutable-/Observer-/Route-Drift) bleibt nachrangig offen. Nicht blind zuruecksetzen; Herkunft und erwarteten Hash zuerst pruefen.
