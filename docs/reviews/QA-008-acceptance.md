# QA-008 Abnahme – kanonisches QA-001-Funktionsinventar

Stand: 2026-09-17

## Befund

Der Vollsupertest erreichte vor der Inventarsynchronisation `JA-013` und meldete eine Abweichung zwischen dem gespeicherten QA-001-Inventar und den aktuellen Quelltexten. Der strukturierte Vergleich ergab jeweils 577 Einträge und identische Symbol- und Testkatalogmengen. Ausschließlich fünf Funktionen in `tools\\Invoke-JobAgentDailyRun.ps1` hatten denselben geänderten Quellhash; die Abweichung war daher ein Generierungsrückstand, keine Katalog- oder Testlücke.

## Reproduzierbare Korrektur

Das Inventar wurde ausschließlich mit dem vorgesehenen Generator erneuert:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -WriteInventory
```

Der Generator schrieb `docs/reviews/QA-001-function-inventory.json` mit 577 Einträgen. Es wurden keine einzelnen Hashwerte manuell editiert, keine Produktquellen verändert und keine Gleichheitsassertion abgeschwächt.

## Verifikation

| Befehl | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\\tests\\Test-JobAgentTestMatrix.ps1` | Exit 0 |
| `pwsh -NoProfile -File .\\tests\\Test-JobAgentSupertestContract.ps1` | Exit 0 |
| `./ci.cmd supertest` | Exit 0; 29 geplant, 29 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgeführt |

Akzeptanz erfüllt: Das versionierte Inventar entspricht wieder der kanonischen Generatorausgabe des geprüften Arbeitsstands.
