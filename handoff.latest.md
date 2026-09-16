# Handoff – M4-Playwright- und AJV-Testinfrastruktur abgeschlossen

Stand: 2026-09-16T16:55:00+02:00

## Abgeschlossen und archiviert

- CI-002: AJV-Schema läuft mit projektlokaler Tool-/Cache-Umgebung. `Test-JobAgentSchema.ps1` und `Test-JobAgentSchemaTooling.ps1` endeten mit Exit 0.
- CI-003: Playwright-Daemon, Fehler-, Temp- und npm-Pfade sind pro Lauf unter `.ci\cache\playwright` isoliert; die Prozessumgebung wird wiederhergestellt und fehlende lokale Artefakte werden fail-closed abgewiesen.
- CI-004: `.ci\playwright-cli.runtime.json` pinnt `@playwright/cli` 0.1.20 und `playwright-core` 1.64.0-alpha-2026-09-14. Die Runtime wird direkt aus dem projektlokalen npm-Cache aufgelöst. Der Browserstart benötigt `--no-sandbox`; danach bestehen `open`, `snapshot` und `close` unter Node 24.
- Die drei Punkte wurden nach `Roadmap_archive.md` rotiert. Der Supertest wurde nicht angefragt und ist gemäß Nutzerregel als erledigt dokumentiert.

## Bestandene Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSchemaTooling.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentPlaywrightTooling.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentPlaywrightCliRuntime.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSupertestContract.ps1`

## Offener nächster Arbeitsschritt

`TD-0056 CI: Resolve drift (observer/route/immutables)` bleibt offen. Ausgangsnachweis: `logs/observer/drift-latest.json`. Zuerst read-only Drift-/Route-/Immutable-Audit mit `./ci.cmd` durchführen; keine Pins, Immutable-Dateien oder Beobachterartefakte zur reinen Grünfärbung ändern. Danach Ursache gezielt beheben, Funktionstest ausführen und Todo-/Handoff-/Roadmap-Zustand synchronisieren.

## Grenzen

- Sonar: `not-supported` laut Projektkonfiguration.
- Android-/Device-Lane: `not-applicable` für die lokale Web-Berichtslane.
- Der Devserver auf Port 8500 war für die Browser- und Viewport-Funktionstests erreichbar; keine neue Devserver-Instanz gestartet.
