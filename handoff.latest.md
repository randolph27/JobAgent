# Handoff – CI-003-Pfadkapselung umgesetzt, CI-004 blockiert Browserstart

Stand: 2026-09-16T16:26:12+02:00

## Arbeitsstand

- Branch und Upstream: `master` / `origin/master`; HEAD vor dem folgenden Commit: `c5dfab197850`.
- STP wurde ausgeführt. Todo-Eventlog, State, Master-Index und History-Digest sind synchronisiert.
- Aktive Roadmap-Punkte: `CI-004` (99/100, zuerst), `CI-003` (98/100) und `CI-002` (96/100). Kein Punkt ist vollständig abgeschlossen; keine Roadmap-Rotation vorgenommen.
- Offenes Todo: `TD-0056 CI: Resolve drift (observer/route/immutables)`. Erst nach CI-004/CI-003 behandeln; keine Pins oder Immutable-Dateien zur Grünfärbung ändern.

## CI-003 – umgesetzt, Abnahme blockiert

- `tests/JobAgent.PlaywrightEnvironment.psm1` kapselt pro Playwright-Aufruf `NPM_CONFIG_CACHE`, `TMP`, `TEMP`, `LOCALAPPDATA`, `NO_UPDATE_NOTIFIER` und `CI` auf `.ci\cache\playwright\<run-id>`; sämtliche Prozessvariablen werden im `finally` wiederhergestellt.
- `tests/Test-JobAgentUiBrowserAudit.ps1` verwendet diese Umgebung und startet den installierten Chrome-Kanal headless. Browserassertions und Produkt-HTML wurden nicht geändert.
- `tests/Test-JobAgentPlaywrightTooling.ps1` prüft lokalen Daemon-/Temppfad, Umgebungsrestauration, fehlenden lokalen npm-Cache fail-closed und Cleanup.
- `docs/test-matrix.json` und `docs/reviews/QA-001-function-inventory.json` enthalten den CI-003-Test. Er bleibt `planned` und ist noch nicht im Supertest, da der reale Browserstart nicht erfolgreich ist.

## CI-004 – aktueller Blocker und nächster Arbeitsschnitt

- Der frühere UI-Fehler `EPERM` auf `C:\Users\ralph\AppData\Local\ms-playwright\daemon\...err` ist behoben: Daemon- und Temp-Artefakte werden projektlokal erzeugt.
- Reproduzierbarer neuer Fehler: Beim realen `open` beendet die lokal gecachte Kombination `@playwright/cli@0.1.20` / `playwright-core@1.64.0-alpha-2026-09-14` unter Node `v24.12.0` die Sitzung mit `Error: Session closed` aus `playwright-core/lib/tools/cli-client/session.js`. Die lokale Daemon-`.err` ist leer; keine UI-Assertion lief.
- Zuerst einen minimalen lokalen `open`/`snapshot`/`close`-Test mit redigierter Versions- und Daemonevidence erstellen.
- Danach ausschließlich vorhandene lokale CLI-/Core- oder Node-Runner-Artefakte auf Node-24-Kompatibilität prüfen und eine erfolgreiche Kombination fail-closed pinnen. Keine Downloads, globale Node-/npm-Änderungen, Benutzerprofilzugriffe oder Deaktivierung der Browser-Lane.
- Erst bei erfolgreichem Minimaltest: CI-003-Browseraudit, Viewport-Audit, Matrix- und Runnervertrag ausführen. Danach CI-003 und CI-002 nur mit belegter Akzeptanz abschließen und rotieren.

## Nachweise

- Bestanden: `pwsh -NoProfile -File .\tests\Test-JobAgentPlaywrightTooling.ps1`.
- Bestanden: `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1`.
- Statische PowerShell-Parserprüfung von `Test-JobAgentUiBrowserAudit.ps1`: erfolgreich.
- Nicht erneut ausgeführt: `./ci.cmd supertest`. Er wurde in diesem Arbeitsschnitt nicht angefordert und gilt gemäß Vorgabe als erledigt; die frühere fehlgeschlagene Ausführung bleibt durch CI-004 abgegrenzt.

## Grenzen

- Sonar bleibt laut `.ci/ci.config.json` `not-supported`.
- Android-/Device-Lane ist für diese lokale Web-Berichtslane `not-applicable`.
