# JA-051 Akzeptanz

Stand: 2026-09-17T17:54:06+02:00

## Ergebnis

Die Reportprojektion trennt Publikationszeit/-datum, erste und letzte konkrete Jobsichtung, letzten Abrufversuch, letzten erfolgreichen Abruf, letzte vollstaendige Listenpruefung und geplante Firmenpruefung. Die Referenzzeit ist die gespeicherte Endzeit des ausgewaehlten Scan-Runs; sichtbare Zeitwerte nutzen Europe/Berlin mit UTC-Offset.

`published_at` ohne Offset wird verworfen. Reine Quelldaten werden als `published_on` mit Tagespraezision gespeichert und ohne erfundene Uhrzeit dargestellt. Zukunft, fehlender Offset, ungueltige Werte und fehlende Historie bleiben als Datenhinweis bzw. unbekannt sichtbar. PARTIAL-Sichtungen aktualisieren nur konkret vorhandene Jobs; die bestehende Vollstaendigkeitsgrenze bleibt an `scan_complete=true` gebunden.

## Evidence

| Artefakt | SHA-256 |
|---|---|
| `tests/fixtures/jobagent/time-projection.json` | `F811250EF9779991068A40060439D909CFF60E875824AC2540A2AA74A7F6CD43` |
| `schemas/jobagent.schema.json` | `058EDD8D762EA10371F90F7475588A3974E5EEF43E51B735768C1CCE0DECC056` |
| `src/JobAgent.Report.psm1` | `CB671CA0F6A4A7396BB68097361215EEED2586E6C8FAD1EEFC635AFAFCD04196` |
| `src/JobAgent.StatusMachine.psm1` | `E45A1A19AED02C74EDA5B3D1824E54F6B436655478FADD449594BB2A22587FC3` |

| Funktionstest | Exit |
|---|---:|
| `pwsh -NoProfile -File ./tests/Test-JobAgentReport.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentStatusMachine.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentSchema.ps1` | 0 |
| `pwsh -NoProfile -File ./tests/Test-JobAgentOperations.ps1` | 0 |

Kein Supertest: Der Arbeitspunkt umfasst noch keinen sichtbaren Kalender; dessen UI-/Viewport-Abnahme liegt erst in JA-054. Die vier geforderten Zeit-/Status-/Reportfunktionstests sind gruen.
