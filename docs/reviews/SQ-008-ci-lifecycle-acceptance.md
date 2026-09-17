# SQ-008 SonarQube-CI-Lifecycle – Abnahme

Stand: 2026-09-17 15:21 CEST

`./ci.cmd sonar` schloss den begrenzten External-Issue-Lifecycle mit Exit `0` ab. Der sekretfreie Nachweis ist `logs/verify/sq-009-20260917-152135.json`:

- Projekt: `jobagent-external-powershell`
- Scope: `external-powershell-issues-only`
- Commit: `027fe60185a190ad5eb56159e3140377d186d329`
- External Issues: `323`
- Task: `AaCvh97JOhdKqVTDjfxk`
- Analyse: `AaCvh-LnotDYp2WltY0K`
- Compute-Engine-Status: `SUCCESS`
- Compute-Engine-API-Status: `200`

Toolchain-, Report-, Authentifizierungs-, Projekt-, Scanner- und Compute-Engine-Grenzen brechen bei jeder Fehlerklasse mit nichtnull Exit ab. Die fokussierten Lifecycle-, External-Issue-, Auth-, Toolchain- und CI-Contract-Tests liefen am selben Tag mit Exit `0`.

Die CI nimmt keine native PowerShell-Analyse, Coverage, Duplikatmetrik, Quality Profile oder Quality Gate in Anspruch. Token, Header, Queryparameter, Tokenlängen und Scanner-Debugausgaben werden weder versioniert noch in Evidence geschrieben. Ein Supertest wurde nicht ausgeführt und ist kein Ersatz für diesen Nachweis.
