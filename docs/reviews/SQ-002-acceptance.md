# SQ-002 SonarQube-Authentifizierung

Stand: 2026-09-17T10:32:58+02:00

## Ergebnis

- Status: `blocked`
- SonarQube-Status: `UP`
- API-Authentifizierung: `valid:false`, HTTP `200`, Fehlerklasse `sonar_auth_invalid`
- Secret-Audit: Tokenwert, Authorization-Header, Basic-Auth-Fragmente, Query-Token und Tokenlängen werden weder ausgegeben noch versioniert.

## Umgesetzter Vertrag

- Die Tokenquelle ist explizit in `.ci/ci.config.json` konfiguriert.
- Der neue Command `./ci.cmd sonar-auth` liest ausschließlich `GET /api/authentication/validate` und schreibt nur sekretfreie Metadaten nach `logs/verify/sq-002-sonar-auth.json`.
- Reine Werte sowie markierte `SONAR_TOKEN=<wert>`-Zeilen werden normalisiert. Mehrdeutige Marker werden deterministisch als `sonar_token_format_invalid` abgewiesen.
- Der Fallback auf Prozess-, private JSON-, Benutzer- und Maschinenumgebung bleibt für vorhandene lokale Setups erhalten. `./ci.cmd sonar` bleibt `not-supported`; keine Analyse, Projektanlage oder Quality-Gate-Änderung wurde ausgelöst.

## Funktionstests

| Command | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1` | Exit `0`; fünf Format- und API-Antwortfälle grün |
| `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` | Exit `0` |
| `./ci.cmd sonar-auth` | Exit `1`; reproduzierbar `sonar_auth_invalid` |

## Nächster zulässiger Schritt

Ein neuer, berechtigter SonarQube-Token muss außerhalb des Repositorys bereitgestellt werden. Anschließend ist ausschließlich `./ci.cmd sonar-auth` erneut auszuführen. Eine Tokenrotation, Projektanlage, Scannerinstallation oder Quality-Gate-Änderung ist nicht Teil dieses Arbeitsschritts.
