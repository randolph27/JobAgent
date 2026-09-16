# Handoff: QA-005.2 Tastatur und Accessibility

## Aktiver Zustand

- Todo: `TD-0062`, Status `in-progress`.
- Roadmap: `QA-005`; QA-005.1 ist erledigt, QA-005.2 und QA-005.3 sind offen.
- Keine Rotation: Die Akzeptanz verlangt beide verbleibenden Unterpunkte und die drei festgelegten Funktionstests.

## Implementierter, noch nicht final verifizierter Stand

- Der Report-Renderer unterstuetzt die Standardnavigation der zwei Tabs mit `ArrowLeft`, `ArrowRight`, `Home` und `End`.
- Nach Klick auf eine Pagination wird die aktuell deaktivierte Seitentaste fokussiert.
- Der Browseraudit prueft berechneten Kontrast statt CSS-Stringvergleich, sichtbare Fokusumrandungen, Filterlabels, Tab-ARIA-Beziehungen, den `role=status`-/`aria-live=polite`-Trefferstatus sowie eine reale Filter- und Tab-Tastaturreise.

## Verifikation und bekannte Fehlerfolge

- Gruen: `Test-JobAgentReport.ps1`, `Test-JobAgentCiContracts.ps1`, PowerShell-Parser und `git diff --check`.
- Browseraudit ist offen. Behebene Fehler: leerer CSS-Selector fuer Buttons ohne ID; unpassende Labelregel fuer Buttons; falsche Reihenfolge der Hintergrundermittlung in der Kontrastberechnung.
- Letzter Fehler vor Uebergabe: Playwright-CLI entfernte doppelte Anfuehrungszeichen aus der Fokusinitialisierung und meldete `ReferenceError: jobagent is not defined`. Die beiden Fokus-IDs werden jetzt per `String.fromCharCode` erzeugt. Der Lauf nach dieser Aenderung fehlt.

## Startbefehl

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1
```

Außerhalb der Sandbox ausfuehren. Voraussetzungen: vorhandener lokaler npm-Cache `.ci/cache/npm`, Playwright-Daemon und Devserver auf Port 8500. Keine Abhaengigkeiten nachinstallieren.
