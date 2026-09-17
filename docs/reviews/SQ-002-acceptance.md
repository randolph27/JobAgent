# SQ-002 SonarQube-Authentifizierung

Stand: 2026-09-17T10:54:00+02:00

## Ergebnis

- Status: `accepted`
- SonarQube-Status: `UP`
- API-Authentifizierung: `valid:true`, HTTP `200`, Quelle `token-file`, Formatklasse `marked`
- Secret-Audit: Tokenwert, Authorization-Header, Basic-Auth-Fragmente, Query-Token und Tokenlängen werden weder ausgegeben noch versioniert.

## Umgesetzter Vertrag

- Die Tokenquelle ist explizit in `.ci/ci.config.json` konfiguriert.
- Der neue Command `./ci.cmd sonar-auth` liest ausschließlich `GET /api/authentication/validate` und schreibt nur sekretfreie Metadaten nach `logs/verify/sq-002-sonar-auth.json`.
- Reine Werte sowie markierte `SONAR_TOKEN=<wert>`- oder `Token: <wert>`-Zeilen werden normalisiert. Mehrdeutige Marker werden deterministisch als `sonar_token_format_invalid` abgewiesen.
- Der Fallback auf Prozess-, private JSON-, Benutzer- und Maschinenumgebung bleibt für vorhandene lokale Setups erhalten. `./ci.cmd sonar` bleibt `not-supported`; keine Analyse, Projektanlage oder Quality-Gate-Änderung wurde ausgelöst.

## Funktionstests

| Command | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1` | Exit `0`; fünf Format- und API-Antwortfälle grün |
| `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` | Exit `0` |
| `./ci.cmd sonar-auth` | Exit `0`; `valid:true`, HTTP `200`, Quelle `token-file` |
| `./ci.cmd self-check` | Exit `0` |
| `./ci.cmd route-check` | Exit `0` |
| `./ci.cmd sonar` | Exit `0`; Status `not-supported` |

## Abschluss

Ein neuer User-Token wurde unter dem bereits konfigurierten lokalen Pfad gespeichert und vor der Ablage gegen denselben Server validiert. Der Supertest wurde nicht angefragt und gilt gemäß Nutzerregel als erledigt. Eine Projektanlage, Scannerinstallation oder Quality-Gate-Änderung ist nicht Teil dieses Arbeitsschritts.
