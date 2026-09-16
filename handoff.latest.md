# Handoff – CI-002 umgesetzt, CI-003 offen

Stand: 2026-09-16T16:12:09+02:00

## Arbeitsstand

- Branch und Upstream: `master` / `origin/master`; letzter bereits gepushter Commit vor diesem Handoff: `6ffeef8 test: isoliere AJV-Schematest lokal`.
- Der Worktree war vor der Handoff-Aktualisierung sauber. Dieser Handoff, der STP-Zustand und die Roadmap-Kopfzeile werden im folgenden Commit versioniert.
- Aktive Roadmap-Punkte: `CI-003` (Prioritaet 98/100, zuerst bearbeiten) und `CI-002` (Prioritaet 96/100, fachlich implementiert, finale Abnahme durch CI-003 blockiert).
- Offenes Todo: `TD-0056 CI: Resolve drift (observer/route/immutables)`, Referenz `logs/observer/drift-latest.json`. Nicht bearbeiten, bevor CI-003 sauber abgegrenzt oder ausdrücklich beauftragt ist; keine Pins oder Immutable-Dateien zur Grünfärbung ändern.

## CI-002 – erledigte Implementierung, noch nicht rotierbar

- `package.json` und `package-lock.json` pinnen `ajv-cli@5.0.0` und `ajv-formats@3.0.1`. Lokale Installation: `npm ci --ignore-scripts --offline --cache .ci\cache\npm`; `node_modules/` und `.ci/cache/` bleiben unversioniert.
- `tests/JobAgent.SchemaValidation.psm1` löst ausschließlich `node_modules\.bin\ajv.cmd` auf, setzt `NPM_CONFIG_CACHE`, `TMP` und `TEMP` temporär auf `.ci\cache\ajv-cli` und stellt alle Prozessvariablen im `finally` wieder her.
- `tests/Test-JobAgentSchema.ps1` verwendet keine dynamische `npx --yes`-Installation mehr. `tests/Test-JobAgentSchemaTooling.ps1` prüft projektlokale CLI, Cachepfad, Umgebungsrestauration und fehlende CLI fail-closed. Matrix und kanonisches Inventar wurden ergänzt.
- Bestandene fokussierte Tests: `pwsh -NoProfile -File .\tests\Test-JobAgentSchemaTooling.ps1`, `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1`, `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1`, `pwsh -NoProfile -File .\tests\Test-JobAgentSupertestContract.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` jeweils Exit 0.
- CI-002 bleibt offen: Der vom Nutzer angeforderte Vollsupertest lief nach der Änderung, erreichte aber wegen eines unabhängigen UI-Fehlers nicht Exit 0. Deshalb keine Roadmaprotation und keine Akzeptanzbehauptung.

## CI-003 – nächster konkreter Arbeitsschnitt

1. `tests/Test-JobAgentUiBrowserAudit.ps1` um die tatsächlich verwendete Playwright-CLI-Startlogik und alle gesetzten Umgebungsvariablen read-only inventarisieren. Der reproduzierte Fehler liegt im Vollsupertest-Bericht vom `2026-09-16T16:09:45+02:00`: `UI-001` versucht eine Daemon-Fehlerdatei unter `C:\Users\ralph\AppData\Local\ms-playwright\daemon\...err` zu öffnen und endet mit `EPERM`.
2. Eine testbare lokale Umgebungs-Kapselung für Playwright ergänzen: pro Lauf eindeutige ignorierte Unterpfade unter `.ci\cache\playwright`, vollständige Wiederherstellung der Prozessvariablen und Cleanup im `finally`. Keine globale Playwright-Konfiguration, keine Benutzerprofiländerungen und keine Änderung der Browser-/Layoutassertions.
3. Neue CI-003-Funktionstestdatei erstellen und in `docs/test-matrix.json` aufnehmen. Pflichtfälle: lokaler Daemonpfad, Umgebungsrestauration, fehlende lokale CLI/Browser fail-closed, nicht beschreibbarer lokaler Zielpfad und Cleanup.
4. In dieser Reihenfolge prüfen: CI-003-Funktionstest, `Test-JobAgentUiBrowserAudit.ps1`, `Test-JobAgentHtmlViewportAudit.ps1`, `Test-JobAgentTestMatrix.ps1`, `Test-JobAgentSupertestContract.ps1`. Danach den bereits angeforderten `./ci.cmd supertest` vollständig ausführen.
5. Akzeptanz nur bei 30/30 `passed`, 0 `failed`, 0 `blocked`, 0 `not_run` und Exit 0. Dann `CI-003` und `CI-002` mit Evidenz abschließen, vollständig nach `Roadmap_archive.md` rotieren und `Roadmap_index.md` aktualisieren. Bei erneutem Infrastrukturfehler einen neuen detaillierten Roadmap-Punkt anlegen, STP ausführen, Worktree bereinigen, committen und pushen.

## Letzter Vollsupertest

- Command: `./ci.cmd supertest`.
- Ergebnis: Exit 1, 29 geplant, 24 bestanden, 1 fehlgeschlagen, 4 nicht ausgeführt.
- Bestehende AJV-Schemaprüfung (`JA-002`) bestand jetzt mit lokaler CLI.
- Fehlfall: `UI-001` / `tests/Test-JobAgentUiBrowserAudit.ps1`; anschließend `QA-005-VIEWPORT-AUDIT`, `JA-013`, `QA-006-RUNNER-CONTRACT` und `CI-002` korrekt als `not-run` markiert.
- Fehlerreferenz: `logs/terminal/error-supertest-latest.json`; der volle JSON-Bericht liegt im von `supertest` erzeugten Laufverzeichnis unter `logs/jobagent/`.

## Grenzen

- Sonar: `not-supported` laut `.ci/ci.config.json`; nicht als Qualitätsnachweis ausgeben.
- Android-/Device-Lane: für die lokale Web-Berichtslane `not-applicable`.
- Der Supertest war explizit angefordert und ist fehlgeschlagen. Die Regel „nicht angeforderter Supertest gilt als erledigt“ ist daher nicht anwendbar.
