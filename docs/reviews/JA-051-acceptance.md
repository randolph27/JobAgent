# JA-051 Akzeptanz

Stand: 2026-09-17T19:10:38+02:00

## Ergebnis

Die Reportprojektion trennt Publikationszeit/-datum, erste und letzte konkrete Jobsichtung, letzten Abrufversuch, letzten erfolgreichen Abruf, letzte vollstaendige Listenpruefung und geplante Firmenpruefung. Die Referenzzeit ist die gespeicherte Endzeit des ausgewaehlten Scan-Runs; sichtbare Zeitwerte nutzen Europe/Berlin mit UTC-Offset.

`published_at` ohne Offset wird verworfen. Reine Quelldaten werden als `published_on` mit Tagespraezision gespeichert und ohne erfundene Uhrzeit dargestellt. Zukunft, fehlender Offset, ungueltige Werte und fehlende Historie bleiben als Datenhinweis bzw. unbekannt sichtbar. PARTIAL-Sichtungen aktualisieren nur konkret vorhandene Jobs; die bestehende Vollstaendigkeitsgrenze bleibt an `scan_complete=true` gebunden.

## Evidence

| Artefakt | SHA-256 |
|---|---|
| `tests/fixtures/jobagent/time-projection.json` | `7D241C5A5FA0E22922B72FE58F8CC940CC06F6265B75D2586815A2BD31745F30` |
| `schemas/jobagent.schema.json` | `058EDD8D762EA10371F90F7475588A3974E5EEF43E51B735768C1CCE0DECC056` |
| `src/JobAgent.Report.psm1` | `5384F9FB773AB0CEF755F3D67C7C364184404881B69938D5F0D94510A145D37F` |
| `src/JobAgent.StatusMachine.psm1` | `E45A1A19AED02C74EDA5B3D1824E54F6B436655478FADD449594BB2A22587FC3` |

| Funktionstest | Exit |
|---|---:|
| `pwsh -NoProfile -File ./tests/Test-JobAgentReport.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentStatusMachine.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentSchema.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentOperations.ps1` | 0 |

Die Fixture prueft zusaetzlich 24 Stunden und sieben Tage jeweils unmittelbar davor, exakt auf der Grenze und unmittelbar danach; bei weniger als 24 Stunden zeigt die Altersansicht `Unter 1 Tag`.

`./ci.cmd supertest` scheiterte zunaechst ausschliesslich an einem veralteten QA-001-Funktionsinventar. Nach kanonischer Regeneration durch `Test-JobAgentTestMatrix.ps1 -WriteInventory` und erfolgreichem Matrixfunktionstest endete der Abschlusslauf mit 29/29 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgefuehrt und Exit 0 in 682,67 Sekunden.
