# Handoff: QA-005 Browseraudit – Daemon-Hänger und Fortsetzung

Stand: 2026-09-16T11:17:01+02:00

## Aktiver Arbeitspunkt

- Todo: `TD-0062`, Status `in-progress`.
- Roadmap: `QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen`.
- `QA-005.1` ist erledigt. `QA-005.2` und `QA-005.3` sind weiterhin offen.
- `QA-006` (`TD-0063`) darf erst nach vollständig belegtem QA-005 beginnen.
- `TD-0056` bleibt unverändert offen. Sonar ist für dieses PowerShell-/HTML-Projekt `not-supported`.

## In diesem Schnitt geänderte Logik

Datei: `tests/Test-JobAgentUiBrowserAudit.ps1`.

`Get-JobAgentAccessibilityMeasurement` markiert jedes relevante Element nun mit
`focusable`. Die Auswertung `focusable_without_focus_style` prüfte zuvor irrtümlich
den Elementnamen gegen die HTML-Tagliste und konnte dadurch einen fehlenden
Fokusindikator nicht zuverlässig finden. Sie prüft jetzt ausschließlich
`item.focusable && item.focus_outline === '0px'`.

Die vorbestehende Korrektur des XSS-Selectors bleibt erhalten:

```javascript
document.querySelectorAll("[id=jobagent-job-results] img")
```

## Verifikation

- PowerShell-Parser für `tests/Test-JobAgentUiBrowserAudit.ps1`: erfolgreich.
- `git diff --check`: erfolgreich.
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -FixtureOnly`:
  erfolgreich. Ergebnis: 251 Firmen, 264 Stellen, Grenzfälle `0, 1, 49, 50, 51, 250, 251`.
  Lokales Log: `logs/jobagent/QA-005/qa005-fixture-only-20260916-1109.log`.
- Kein Supertest wurde ausgeführt; gemäß aktuellem Nutzerauftrag ist dafür kein
  zusätzlicher Lauf erforderlich.

## Reproduzierter Blocker des vollständigen Browseraudits

Der vollständige Test benötigt lokalen Schreibzugriff auf den Playwright-CLI-Daemon
unter `%LOCALAPPDATA%\ms-playwright\daemon`. Im Sandbox-Lauf schlug der Start korrekt
mit `EPERM` beim Öffnen der Daemon-`.err`-Datei fehl.

Ein privilegierter Hintergrundlauf wurde danach mit demselben Testbefehl gestartet.
Die Fixture-Erzeugung lief an, der Daemon legte eine Sessiondatei an und startete
Chromium, aber der Aufrufer lieferte über mehrere Minuten weder stdout noch stderr
und führte keine weitere sichtbare Testphase aus. Der zugehörige, nachweislich eigene
Prozessbaum wurde anschließend beendet. Das ist kein bestandener Browseraudit.

Relevante Dateien:

- Fehler des Sandbox-Laufs:
  `logs/jobagent/QA-005/qa005-browser-audit-20260916-1110.log.err`
- Privilegierter Lauf ohne Ergebnis:
  `logs/jobagent/QA-005/qa005-browser-audit-elevated-20260916-1111.log`
- Privilegierte Daemon-Session:
  `%LOCALAPPDATA%\ms-playwright\daemon\9bea5c76237be5c7\jobagent-ui001-5b3a1b1890ce44ddb4ad37566edd1609.session`

Vor einem erneuten Volltest nur nachweislich zu diesem Lauf gehörende Daemon- und
Child-Prozesse beenden. Fremde Playwright-Sessions und den Devserver auf Port 8500
nicht pauschal beenden.

## Nächste Schritte

1. `.ci.cmd devserver-status` ausführen; nur bei fehlendem Listener `.ci.cmd devserver-start` verwenden.
2. Den Playwright-CLI-Daemonzustand mit einem minimalen privilegierten `open`-/`snapshot`-Lauf gegen eine lokale
   Berichtsfxture isolieren. Nur bei Exit 0 den vollständigen Befehl starten:

   ```powershell
   pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1
   ```

3. QA-005.2 erst als erledigt markieren, wenn Filter-Tastreise, Tab-Navigation,
   Reset- und Paginationfokus, Semantik, Live-Status und berechnete Kontraste im
   vollständigen Browseraudit grün belegt sind.
4. QA-005.3 ergänzen: isolierte Negativrenderer für Clipping, Control-Overlap,
   kleiner als 44 CSS-px und unsichtbaren Fokus. Jede Probe muss die konkrete
   Messassertion auslösen. Anschließend Screenshots und Sichtungsmanifest für Daily
   und Coverage bei 390, 800, 1366 und 1920 px erzeugen; erst dann Referenzbilder
   nach `doc/roadmap-screenshots/` übernehmen.
5. QA-005 erst rotieren, wenn alle drei Unterpunkte, die drei festgelegten
   Funktionstests und die versionierte Evidence vollständig grün sind.
