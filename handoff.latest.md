# Handoff latest

Stand: 2026-09-15T16:56:35.990+02:00

## Zustand

- Active: `TD-0055`
- Status: `in-progress`
- Ziel: `JA-042 Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern`.
- Branch: `master`; HEAD vor diesem Abschlusscommit: `e47888623bf5`; Upstream: `origin/master`.
- Roadmap: UI-001 ist vollständig nach `Roadmap_archive.md` rotiert. Aktiver Produktpunkt ist ausschließlich JA-042; `TD-0056` bleibt ein nachrangiger Drift-Todo.

## Abgeschlossen: UI-001

- Berufsneutrale Firmen- und Stellensuche mit Pagination, lokalen Kombinationsfiltern, Reset und Browser-Rücknavigation ist umgesetzt.
- Der isolierte Browseraudit nutzt 251 Firmen und 256 Stellen und deckt Treffer hinter der ehemaligen 250er-Grenze, Freising/Pflege, München/Buchhaltung, Teilzeit/Hybrid, `UNKNOWN`, Unicode-Freitext, Nulltreffer sowie 390/800/1366/1920 px ab.
- Nachweise: `logs/jobagent/ui-001-browser-audit.json`, die vier Screenshots unter `output/playwright/ui-001-browser-audit-<width>.png` und `logs/jobagent/ui-001-supertest.log`.
- Funktionstests: `Test-JobAgentHtmlAudit.ps1`, `Test-JobAgentReport.ps1` und `Test-JobAgentUiBrowserAudit.ps1` jeweils Exit 0. `./ci.cmd supertest` Exit 0 in 475,55 s.
- Wesentliche Implementierungscommits: `a45a366`, `cfb6ba3`, `5b4f77a`; `e478886` dokumentiert den ursprünglichen UI-001-Handoff.

## Nächster Arbeitsschnitt: JA-042.1

Ziel: Einen regulären, endlichen Jobstart unter einer gemeinsamen Run-ID liefern, der budgetierte Akquise, berufsneutrale Stellenerfassung und atomare WebIF-Publikation verbindet.

1. Bestehenden Einstieg in `tools/Invoke-JobAgentDailyRun.ps1` erhalten und die Phasen in `src/JobAgent.Operations.psm1` sowie `src/JobAgent.DailyRun.psm1` verbinden. Kein manueller Import-, Verify- oder Reportschritt im Normalbetrieb.
2. Globale/Host-Limits sowie getrennte Akquise-/Scan-Budgets strikt prüfen. Ein Doppelstart darf keinen zweiten Writer erzeugen; Quellenfehler und Retry dürfen andere Firmen nicht blockieren; ein Storefehler beendet schreibende Folgearbeit fail-closed.
3. `tools/Get-JobAgentDailyRunStatus.ps1` und WebIF müssen `laeuft`, `abgeschlossen`, `teilweise` oder `fehlgeschlagen` mit Zeit und lesbarem Grund ausgeben. Vorherige Reportdaten bleiben bis zu einer erfolgreichen atomaren Publikation sichtbar und werden bei Fehlern als alter Stand markiert.

Fokustests nach Umsetzung von JA-042.1:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
```

Erforderliche neue Evidence: `logs/jobagent/JA-042-1-acceptance.json` mit Gitstand, Run-ID, erwarteten/erhaltenen IDs und Zählern, Befehlen/Exitcodes sowie positiven und negativen Fällen. Browseraudit nur bei sichtbarer Änderung. Kein Supertest pro Unterpunkt; nach Abschluss aller drei JA-042-Unterpunkte den vollständigen Supertest, Roadmap-Rotation, Todo/Handoff und STP zusammen ausführen.

## Bekannte Nebenbedingung

`./ci.cmd self-check` meldet derzeit ausschließlich `immutable_modified: manual\PROGRAM.md`. Diese Datei wurde in diesem Abschluss nicht geändert und ist nicht im Git-Diff. Vor einer Korrektur zuerst Herkunft und erwarteten Immutable-Hash prüfen; nicht blind zurücksetzen. Der Befund ist als `TD-0056` nachrangig erfasst und blockiert JA-042 nicht.

## Abschluss dieses Chats

- STP lief erfolgreich am 2026-09-15T16:56:35.990+02:00.
- Roadmap-, Todo-, Checkpoint- und Handoff-Status sind auf `TD-0055` synchronisiert.
- Der nachfolgende Commit enthält ausschließlich die UI-001-Rotation und die dazugehörige Zustandsdokumentation.
