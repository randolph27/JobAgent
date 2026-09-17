# Handoff latest

Stand: 2026-09-17T10:35:16.513+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: Keine aktive Roadmap-Aufgabe.
- Branch: `master`
- HEAD: `a836895229c2`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Aktueller SQ-002-Befund

- Roadmap/Todo: einzig aktiver Punkt `SQ-002` / `TD-0065`; nicht archivieren. Der technische Teil ist umgesetzt, die Akzeptanz `valid:true` bleibt extern blockiert.
- Implementierung: `.ci/ci.config.json` enthält nur den lokalen Tokenpfad. `ConvertTo-SonarNormalizedToken` akzeptiert einen reinen Wert oder genau einen markierten `SONAR_TOKEN=<wert>`-Eintrag, entfernt BOM/äußere Anführungszeichen und verwirft NUL, Leerwerte sowie mehrdeutige Marker. Kein Geheimniswert wird persistiert.
- Command: `./ci.cmd sonar-auth` ruft ausschließlich `GET /api/authentication/validate` auf. Der lokale Evidence-Report enthält nur Zeitpunkt, Serverstatus, `valid`, HTTP-Status, Fehlerklasse, Quellen- und Formatklasse.
- Tests: `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` jeweils Exit `0`. Testfälle: reiner Token, markierter Token, mehrdeutiger Marker, API `valid:true`, API `valid:false`.
- Live-Befund: SonarQube ist `UP`, `./ci.cmd sonar-auth` endet reproduzierbar mit Exit `1` und `sonar_auth_invalid` bei HTTP `200`. Der geprüfte letzte Kandidat stammt aus der Prozessumgebung; damit ist keine gültige lokale Quelle nachgewiesen.
- Evidence: `docs/reviews/SQ-002-acceptance.md` und lokal `logs/verify/sq-002-sonar-auth.json`. Tokenwert, Header, Query und Tokenlänge fehlen aus Codeausgaben, Logs, Todo und Handoff.
- Nächster zulässiger Schritt: Einen neuen berechtigten SonarQube-Token außerhalb des Repositorys bereitstellen. Danach nur `./ci.cmd sonar-auth` ausführen; bei `valid:true` die restlichen SQ-002-Gates abschließen. Keine Tokenrotation, Projektanlage, Scannerinstallation, Quality-Gate- oder Infrastrukturänderung ohne separate Freigabe.
- `./ci.cmd sonar` bleibt absichtlich `not-supported`, da kein unterstützter Analyzer konfiguriert ist. Der Supertest wurde nicht angefragt und gilt gemäß Nutzerregel als erledigt.

## Versionierte Aenderungen

- `.ci/bin/modules/ci-commands-main.ps1`
- `.ci/ci.config.json`
- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/.ci/ci.config.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `tests/Test-JobAgentCiContracts.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`
- `./ci.cmd sonar-auth` -> Exit `1` (`sonar_auth_invalid`, erwarteter externer Blocker)
- `./ci.cmd sonar` -> `not-supported` (kein Analyzer konfiguriert)

## Naechster Anker

SQ-002 SonarQube-Tokenformat sekretfrei normalisieren und API-Authentifizierung reproduzierbar nachweisen #comment: Der Server auf `localhost:9000` ist `UP`, aber die direkte, sekretfreie Verwendung des lokal hinterlegten Tokeninhalts lieferte für `GET /api/authentication/validate` `valid:false`; ohne erfolgreiche Authentifizierung darf keine projektbezogene SonarQube-Aussage getroffen werden.
