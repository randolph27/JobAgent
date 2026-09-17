# QA-007 Abnahme – CI-005-Test ohne Kaspersky-auslösende Verhaltensmuster

Stand: 2026-09-17

## Ursache und Korrektur

Der gemeldete Security-Befund betraf `tests/Test-JobAgentCiContracts.ps1` während des Vollsupertests. Der direkt abhängige Test `tests/Test-Ci005Invariants.ps1` erzeugte zuvor für jeden Negativfall ein temporäres Repository-Fixture, kopierte darunter `.ci` und Truth-Dateien, veränderte Fixture-Dateien, startete mehrfach `ci.cmd self-check` und löschte das Fixture anschließend rekursiv. Diese Kombination aus Kopieren, Modifizieren, verschachteltem Prozessstart und rekursiver Löschung ist für verhaltensbasierte Sicherheitsüberwachung unnötig riskant.

Die Korrektur beschränkt sich auf Testscripts. `Test-Ci005Invariants.ps1` prüft nun die CI-005-Verifikationsverträge direkt und nicht mutierend: Immutable- und ReadOnly-Prüfung, Todo-Normalisierung, Git-Snapshot, Capsule-Parität und Markdown-Parität des vorhandenen Handoffs. Der Test erstellt keine temporären Repository-Kopien, schreibt oder löscht keine Fixture-Dateien und startet keine verschachtelten `ci.cmd`- oder `pwsh`-Prozesse. App- und Produktquellen wurden nicht geändert.

Der Kaspersky-Hinweis wurde nicht mit einer Ausnahme, Desinfektion oder Schutzrichtlinienänderung behandelt. Das vom Nutzer gezeigte Fenster liegt nicht als Workspace-Datei vor; es wird keine lokale Screenshotreferenz erfunden.

## Fokussierte Verifikation

| Befehl | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\\tests\\Test-Ci005Invariants.ps1` | Exit 0; sechs deterministische Vertragsfälle erfolgreich |
| `pwsh -NoProfile -File .\\tests\\Test-JobAgentCiContracts.ps1` | Exit 0 |
| `pwsh -NoProfile -File .\\tests\\Test-JobAgentSupertestContract.ps1` | Exit 0 |
| `./ci.cmd self-check` | Exit 0 |

## Abschlussnachweis

`./ci.cmd supertest` endete mit Exit 0 nach 692,59 Sekunden. Der Ergebnisbericht meldete `planned_test_count=29`, `passed=29`, `failed=0`, `blocked=0` und `not_run=0`.

Akzeptanz erfüllt: Der Vollsupertest ist vollständig ausgeführt, die relevante CI-Vertragskette ist grün und die Korrektur liegt ausschließlich in Testscripts.
