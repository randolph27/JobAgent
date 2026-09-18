# Handoff latest

Stand: 2026-09-18T12:39:48.609+02:00

## Zustand

- Active: `TD-0081`
- Status: `open`
- Ziel: M2 – Stellenboersen-Oberflaeche: JA-053 Fachliche Aenderungen einer Stelle als belegte Chronik anzeigen #comment: Eine erneute Erfassung ist keine neue Stelle und eine technische Quellenstoerung kein belegtes Ende einer Ausschreibung.
- Branch: `master`
- HEAD: `d40ff40a11c8`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `handoff.latest.json`
- `handoff.latest.md`
- `schemas/jobagent.schema.json`
- `src/JobAgent.Report.psm1`
- `src/JobAgent.StatusMachine.psm1`
- `tests/Test-JobAgentStatusMachine.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

TD-0081 / JA-053 abschliessen. Implementiert sind Status-/Snapshot-Erweiterung, Change-Projektion, Detailansicht und isolierte Fixturetests. Vor Roadmap-Rotation fehlt ausschliesslich der gezielte Browser-Detailaudit mit Chronikfixture, Screenshot `doc/roadmap-screenshots/JA-053-change-detail-1366.png` sowie Evidence unter `docs/reviews/JA-053-acceptance.md` und `logs/jobagent/JA-053/change-cases.json`.

## Arbeitsstand JA-053

- `src/JobAgent.StatusMachine.psm1` archiviert in neuen Snapshots Arbeitsmodell, Anstellungsart, Arbeitszeit, Anforderungen und Gehalt. Aenderungen dieser Felder erzeugen ein gemeinsames `JOB_UPDATED`-Event; technische Quellenfehler bleiben ohne Lebenszyklusereignis.
- `src/JobAgent.Report.psm1` projiziert vorhandene `JOB_CREATED`, `JOB_UPDATED`, `JOB_CLOSED` und `JOB_REMOVED`-Events je stabiler `job_id`. Die Detailansicht zeigt Quellenchronik, Erkennungszeit, Lauf, Quelle und textuelles Vorher/Nachher. Fehlende Altsnapshots werden mit „Vorheriger Inhalt nicht archiviert“ kenntlich gemacht. HTML wird als Klartext normalisiert; keine Altinhalte werden rekonstruiert.
- Die Detailansicht begrenzt die erste Ansicht auf 20 Ereignisse und blendet weitere per Schaltflaeche ein. Reihenfolge: Beobachtungszeit absteigend, bei Gleichstand `change_event_id` aufsteigend.
- Vertrag und Fixture: `docs/contracts/JA-053-change-projection.md`, `tests/fixtures/jobagent/job-change-history.json`, `tests/Test-JobAgentChangeHistory.ps1`.

## Belegte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentChangeHistory.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentPersistence.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -FixtureOnly` -> Exit 0

## Fuer den naechsten Agenten

1. Einen kleinen Browsermodus oder gezielten Browserfall fuer die JA-053-Chronikfixture ergaenzen: Detail oeffnen, Quellenchronik/„Vorher“/„Nachher“ pruefen, keine Browserfehler und kein Bediennetzwerk; 20/21-Ereignisse per Schaltflaeche verifizieren.
2. Die vier Viewports 1920/1366/800/390 und Tastaturbedienung der aufklappbaren Chronikeintraege pruefen; den geforderten 1366-Screenshot erzeugen.
3. Evidence erstellen, JA-053 erst danach vollstaendig nach `Roadmap_archive.md` rotieren und TD-0081 auf `done` setzen. Kein Supertest ausfuehren: nicht angefragt und damit erledigt.
4. Anschliessend TD-0082 / JA-055 beginnen. TD-0085 bleibt ein unabhaengiger CI-Drift in gepinnten Sonar-JRE-Lizenzdateien und wird nicht ohne eigene Entscheidung geaendert.
