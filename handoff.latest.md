# Handoff latest

Stand: 2026-09-16T14:45:00+02:00

## Aktiver Auftrag

- Active: `TD-0063` / `QA-006`; Status: `in-progress`.
- Ziel: Supertest-Auswahl, Fehlerprotokoll und Vollstaendigkeitsnachweis abschliessen.
- `TD-0056` (CI-Drift) bleibt offen und unveraendert; keine Pins oder Immutable-Dateien zur Gruenfaerbung aendern.

## Erledigter Arbeitsschnitt

- `tests/JobAgent.Supertest.psm1` nutzt die Matrix als alleinige Planquelle und exportiert einen atomar schreibenden Runner.
- Der Runner protokolliert pro Child Testdatei, Command, Status, Fehlerart, Exitcode, stdout/stderr, Start/Ende, PowerShell-Version und CWD. Nach erstem Pflichtfehler werden Restfaelle begruendet als `not-run` erfasst.
- Neu: `tests/Test-JobAgentSupertestContract.ps1`. Er verwendet nur eigene Tempdaten und prueft Erfolg, Nichtnull-Exit, Exception, ungueltigen Plan, Timeout und Abbruch; keine Supertest-Rekursion.
- `docs/test-matrix.json` hat `QA-006-RUNNER-CONTRACT` mit Reihenfolge 28. Das kanonische Funktionsinventar ist aktualisiert.
- QA-006.1 und QA-006.2 sind in `Roadmap.md` abgeschlossen. QA-006.3 sowie QA-006 insgesamt bleiben offen; keine Roadmap-Rotation.

## Belegte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentSupertestContract.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit 0.
- `git diff --check` -> Exit 0.
- `.\ci.cmd stp` -> Exit 0 am 2026-09-16T14:41:37+02:00.

## Supertest-Status

- Der erste Supertestversuch brach bei `Test-JobAgentSchema.ps1` mit `EPERM` im lokalen npm-Cache ab.
- Der fokussierte Schema-Test lief danach mit Zugriff auf den lokalen npm-Cache gruen.
- Es gibt noch keinen belegten vollständigen Supertestlauf mit allen 28 Matrixeintraegen. Deshalb QA-006 nicht als erledigt markieren und nicht rotieren.

## Naechster konkreter Schritt

1. `.\ci.cmd supertest` mit Zugriff auf den lokalen npm-Cache ausfuehren; bei Fehler nur den ersten fehlenden Funktionstest isolieren.
2. Nach einem gruenen Lauf einen zweiten ausfuehren und die zwei `summary.json` normalisiert vergleichen (Soll-/Istzahl, Status, Inventar-/Matrixhash).
3. `logs/jobagent/QA-006/<run-id>/` und `docs/reviews/QA-006-acceptance.md` vervollstaendigen: Commands, Hashes, Browser-/Visual-Evidence, Sonar `not-supported`, Device `not-applicable`.
4. Erst dann QA-006 abschliessen, Roadmap nach `Roadmap_archive.md` rotieren und Todo/Checkpoint/Handoff erneut mit STP synchronisieren.

## Grenzen

- Keine Android-/Gradle-Lane einbauen. Produkt: PowerShell/HTML; Sonar bleibt laut Konfiguration `not-supported`.
- Lokale Logs sind keine versionierte Acceptance-Evidence. Keine Secrets in Logs, Evidence oder Handoff schreiben.
