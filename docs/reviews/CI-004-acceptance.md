# CI-004 – Playwright-CLI-Laufzeit

Stand: 2026-09-16

Die projektlokale Laufzeit ist in `.ci/playwright-cli.runtime.json` auf `@playwright/cli` 0.1.20 und `playwright-core` 1.64.0-alpha-2026-09-14 gepinnt. Die Auflösung erfolgt direkt aus `.ci/cache/npm/_npx` und wird bei fehlendem oder abweichendem Pin fail-closed beendet. Die CLI wird mit projektlokalem `LOCALAPPDATA`, `TMP`, `TEMP` und npm-Cache gestartet.

Der Fehler `Session closed` war nicht durch Node 24 verursacht. Die Chrome-CLI-Konfiguration enthielt kein `--no-sandbox`; mit dem expliziten Startargument öffnen, snapshotten und schließen die Sitzungen stabil.

Bestandene Funktionstests:

- `Test-JobAgentPlaywrightTooling.ps1`
- `Test-JobAgentPlaywrightCliRuntime.ps1`
- `Test-JobAgentUiBrowserAudit.ps1` (Fixture, 390/800/1366/1920 px)
- `Test-JobAgentHtmlViewportAudit.ps1` (Fixture und Coverage-Bericht, 390/800/1366/1920 px)
- `Test-JobAgentTestMatrix.ps1`
- `Test-JobAgentSupertestContract.ps1`

Der Vollsupertest ist der noch ausstehende Release-Gate-Schritt.
