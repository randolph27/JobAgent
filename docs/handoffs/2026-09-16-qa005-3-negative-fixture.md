# Handoff: QA-005.2/QA-005.3

## Status

- Aktives Todo ist `TD-0062` / Roadmap `QA-005`; Status bleibt `in-progress`.
- `QA-005.1` ist erledigt. `QA-005.2` und `QA-005.3` sind nicht als erledigt markieren, bis der vollständige Browseraudit nach dem letzten Fix grün belegt ist und die visuelle Evidence versioniert wurde.
- `QA-006` (`TD-0063`) und CI-Drift (`TD-0056`) sind offen. Keine Rotation: Es ist kein vollständiger Roadmap-Punkt erledigt.

## Geänderter Testvertrag

`tests/Test-JobAgentUiBrowserAudit.ps1` enthält jetzt:

- Reset über fokussiertes `Space`, Pagination für Stellen und Firmen über fokussiertes `Enter` inklusive Fokusassertion nach der Aktualisierung;
- Assertion für fehlende sichtbare Fokusstile zusätzlich zu Labels, Tabs, Live-Status und berechnetem Kontrast;
- isolierte Negativfixture für zu kleines Control, Control-Overlap, Text-Clipping und unsichtbaren Fokus; die Fixture wird im `finally` entfernt;
- `Assert-JobAgentExpectedFailure` und `Set-JobAgentPaginationFocus` als lokale Testhilfen.

## Teststand

- PowerShell-Parser der geänderten Datei: erfolgreich.
- Browseraudit vor der Negativfixture: erfolgreich mit Reset-/Pagination-Tastaturreise.
- Erster Negativlauf: kleines Control, Overlap und Clipping wurden erkannt. Die Fokusnegativprobe schlug fehl, weil `reset.style.outline = none` vom Messansatz nicht erkannt wurde.
- Letzter, noch nicht vollstaendig belegter Fix: Der absichtlich defekte Button erhält zusätzlich `outlineWidth: 0px` und `outlineStyle: none`. Der vollständige Browseraudit muss danach erneut laufen.

## Nächster Arbeitsablauf

1. Alte eigene Browserauditprozesse prüfen; Devserver nur per `./ci.cmd devserver-status` prüfen bzw. per CI-Command starten.
2. Fokussiert ausführen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1
```

3. Bei Fehler nur den konkreten Negativ- oder Browserfall reparieren und denselben Test wiederholen.
4. Bei Erfolg `browser-cases.json` und die Screenshots im neuen `logs/jobagent/QA-004/qa004-*/playwright/`-Run auswerten. QA-005.3 danach mit Screenshotmanifest, Hashes, visueller Sichtung und versionierten Referenzen unter `doc/roadmap-screenshots/` vervollständigen.
5. Erst dann die drei QA-005-Funktionstests einzeln ausführen. Danach genau einmal `./ci.cmd supertest`, QA-005 schließen/rotieren und mit QA-006.1 fortfahren.

## Grenzen

- Android-/ADB-Nachweis ist für diesen Webbericht `not-applicable`.
- Sonar bleibt `not-supported`.
- Lokale `logs/` sind keine versionierte Freigabe-Evidence und bestehende Screenshot-Baselines dürfen nicht überschrieben werden.
