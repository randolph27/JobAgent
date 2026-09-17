# SQ-009 Compute-Engine-Read – Abnahme

Stand: 2026-09-17 15:21 CEST

## Realnachweis

- Command: `./ci.cmd sonar`
- Exit: `0`
- Evidence: `logs/verify/sq-009-20260917-152135.json`
- Projekt: `jobagent-external-powershell`
- Analyseumfang: `external-powershell-issues-only`
- Commit: `027fe60185a190ad5eb56159e3140377d186d329`
- Report-Befunde: `323`
- Compute-Engine-Endpointklasse: `sonar-api-ce-task`
- API-HTTP-Status: `200`
- Task: `AaCvh97JOhdKqVTDjfxk`
- Analyse: `AaCvh-LnotDYp2WltY0K`
- Terminalstatus: `SUCCESS`

Der Command las die Task- und Analyse-ID über die SonarQube-Compute-Engine-API. Die Evidence enthält weder Token, Header, Queryparameter, Tokenlängen, vollständige Serverantworten noch Scanner-Ausgaben.

## Fehlervertrag

`Invoke-SonarComputeEngineTaskRead` trennt die Endpointklasse von Querywerten und klassifiziert 401, 403, 404, 5xx, HTTP-Timeout, Transporttimeout, Transportfehler, ungültige Task-ID, fehlendes oder ungültiges `task`-Objekt, `FAILED`, `CANCELED`, ausstehende Tasks bis Timeout und ungültige `analysisId` fail-closed. Jede Fehlerevidence enthält Stage, Fehlerklasse, bekannte Task-ID, HTTP-Status soweit verfügbar und ausschließlich sekretfreie Diagnosefelder.

## Funktionstests

Alle mit Exit `0` am 2026-09-17:

- `pwsh -NoProfile -File .\tests\Test-SonarCiLifecycle.ps1`
- `pwsh -NoProfile -File .\tests\Test-SonarExternalIssues.ps1`
- `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1`
- `pwsh -NoProfile -File .\tests\Test-SonarToolchain.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`

Browser-, Viewport- und Android-Audit: nicht anwendbar. Ein Supertest wurde nicht ausgeführt; er ersetzt diesen Funktionsnachweis nicht.

## Grenzen

Der Nachweis betrifft ausschließlich PSScriptAnalyzer-External-Issues aus `.ci/bin` und `tools`. Er behauptet keine native PowerShell-Analyse, keine Coverage, keine Duplikatmetrik, kein Quality Profile und kein Quality Gate.
