# Handoff: QA-001 abgeschlossen

Stand: 2026-09-15

## Abschluss

`QA-001 Funktionsinventar und verbindliche Testfallmatrix vervollstaendigen` ist abgeschlossen und nach `Roadmap_archive.md` rotiert. `TD-0058` wurde aus dem aktiven Todo-State entfernt. Die aktiven Roadmap-Punkte beginnen nun mit `QA-002` / `TD-0059`.

## Gelieferte Artefakte

- `docs/reviews/QA-001-function-inventory.json`: Kanonisches, deterministisch aus PowerShell-AST und Renderer-Controls erzeugtes Inventar. Stand: 570 Einträge, darunter 9 UI-Controls. Jeder Eintrag führt relativen Quellpfad, SHA-256, Symbol, Einstiegspunkt, Seiteneffekt, Vertragsquelle und vorhandene Testreferenzen.
- `docs/test-matrix.json`: Matrix v2 mit festem UTC-Bezugspunkt, `de-DE`, festem Seed und lokaler Toolauflösung. Neun geplante Folgefälle besitzen stabile IDs, Funktions-/Control-Referenzen, Fixtures, Eingaben, Sollwirkungen, Negativfälle, Testdateien, Lanes, Abhängigkeiten und Eigentümer QA-002 bis QA-006.
- `docs/test-matrix.md`: Lesbare Zuordnung der geplanten Folgefälle und deterministischen Rahmenbedingungen.
- `docs/reviews/QA-001-gap-register.md`: Verbleibende Testlücken mit verbindlichem Eigentümer und Abnahmekriterium.
- `tests/Test-JobAgentTestMatrix.ps1`: Prüft Inventar-Synchronität, Matrixvertrag, Dateireferenzen, Lanes, produktive Pfade, Live-Aufrufe, Abhängigkeitszyklen und Supertest-Synchronität. Isolierte Negativfixtures prüfen fehlendes Symbol, doppelte Fall-ID, fehlende Testdatei, unbekannte Lane, produktiven Datenpfad, Liveaufruf und Zyklus.

## Verifikation

```text
pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1 -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1 -> Exit 0 außerhalb der Sandbox
.\ci.cmd supertest -> erfolgreich außerhalb der Sandbox
```

Der erste Supertest-Versuch in der Sandbox scheiterte ausschließlich an `EPERM` beim Zugriff auf den npm-Cache während `Test-JobAgentSchema.ps1`. Der fokussierte Schema-Test und der anschließende vollständige Supertest außerhalb der Sandbox liefen erfolgreich. Testgenerierte Runtime-Artefakte wurden vor dem Commit entfernt.

## Nächster Arbeitsschnitt: QA-002 / TD-0059

1. Die QA-001-Matrix als Nenner verwenden; `planned`-Fälle bleiben geplant und dürfen nicht als bestanden markiert werden.
2. `Test-JobAgentPersistence.ps1`, `Test-JobAgentDeduplication.ps1`, `Test-JobAgentStatusMachine.ps1`, `Test-JobAgentDailyRun.ps1` und `Test-JobAgentReport.ps1` gegen isolierte Grenz- und Fehlerfälle ausbauen.
3. Atomare Persistenz, Backups, Locks, Fremdpfade und Traversal mit isolierten Fehlerpunkten nachweisen.
4. Identitätspriorität, regionale Grenzen und die Statusfolgen `NEW -> ACTIVE -> UPDATED -> CLOSED`, `REMOVED` sowie Wiederauftauchen als feste Sequenzen prüfen.
5. JSON-, Markdown-, Daily-HTML- und Coverage-Reports gegen IDs, Mengen, Escaping, sichere Links und deterministische Wiederholung prüfen.
6. Ausschließlich fokussierte Funktionstests verwenden. Den Supertest erst nach vollständiger QA-002-Abnahme ausführen; bei Fehlern zuerst den konkreten Teiltest reparieren.

## Unverändert offen

- `QA-002` bis `QA-006` / `TD-0059` bis `TD-0063`.
- `TD-0056 CI: Resolve drift (observer/route/immutables)`: bekannter Befund `immutable_modified: manual\PROGRAM.md`; nicht durch Repinning verdecken und getrennt behandeln.
- Sonar bleibt gemäß `.ci/ci.config.json` `not-supported`; ein Server auf Port 9000 ist kein Analysebeleg.
