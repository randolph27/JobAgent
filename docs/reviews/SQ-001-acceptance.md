# SQ-001 – Abschlussnachweis

Stand: 2026-09-16 18:19 CEST

## Ergebnis

Status: `completed` als explizite Nichtanwendbarkeit.

Der lokale SonarQube-Container ist unter `http://127.0.0.1:9000` erreichbar (`UP`) und meldet Version `9.9.8.100196`. Das Standard-Admin-Passwort wurde ersetzt. Der aktuelle, ausschließlich außerhalb des Repositories gespeicherte `Token:`-Eintrag in `D:\_Scripte\_Sonar\token.txt` liefert bei `GET /api/authentication/validate` den Wert `valid:true`; `GET /api/projects/search?ps=1` liefert HTTP 200. Weder Passwort noch Tokenwert wurden ausgegeben.

Die Konfiguration bleibt auf `sonar.mode: not-supported`. `./ci.cmd sonar` bestätigt diesen Zustand mit `analysis_started:false`; es wurden kein Scanner, kein Projekt, keine Analyse-ID und kein Quality Gate erzeugt oder behauptet.

Die entscheidende Ursachenprüfung ist abgeschlossen: Die offizielle [Sprachübersicht für SonarQube 9.9](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/languages/overview) führt PowerShell nicht als unterstützte Sprache. Der vorhandene Quellbestand enthält außerhalb von Runtime-/Cachepfaden 216 `.ps1`- und 18 `.psm1`-Dateien. Die [Scanner-Dokumentation für SonarQube 9.9](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/scanners/sonarscanner) beschreibt zwar die allgemeine Projektkonfiguration, schafft aber keinen PowerShell-Analyzer. Eine reine Randanalyse statischer HTML-/JSON-Dateien wäre kein gültiger Qualitätsvertrag für das PowerShell-Projekt.

## Verifikation

- Serverstatus `UP`, Tokenvalidierung `true` und Projekt-API HTTP 200 wurden am 2026-09-16 sekretfrei geprüft.
- `./ci.cmd sonar` endete mit dem erwarteten Status `not-supported`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` endete mit Exit 0 und prüfte den `not-supported`-Pfad sowie `analysis_started:false`.
- Die vollständige funktionsbezogene Suite ohne Aggregator `Test-JobAgentSupertest.ps1` endete mit 31/31 Exit 0; Nachweis: `logs/terminal/functional-suite-20260916-1808.json`.

## Wiederaufnahmebedingung

Ein neuer Roadmap-Punkt ist nur erforderlich, wenn für den dominanten PowerShell-Quellbestand ein offiziell unterstützter SonarQube-Analyzer verfügbar wird oder der Produktcode auf eine unterstützte Hauptsprache erweitert wird. Erst dann sind Projekt-Key, lokaler Scanner, Analyse-ID und Quality-Gate separat zu planen und abzunehmen.

## Reproduzierbarer, sekretfreier Check

```powershell
$tokenLines = @(Get-Content -LiteralPath 'D:\_Scripte\_Sonar\token.txt' | Where-Object { $_ -match '^Token:\s*(.+)\s*$' })
$token = ($tokenLines[-1] -replace '^Token:\s*', '').Trim()
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token + ':'))
$headers = @{ Authorization = 'Basic ' + $encoded }
Invoke-RestMethod -Headers $headers -Uri 'http://127.0.0.1:9000/api/authentication/validate' -TimeoutSec 10
Invoke-WebRequest -Headers $headers -Uri 'http://127.0.0.1:9000/api/projects/search?ps=1' -TimeoutSec 10
```

Der Token darf weder in Logs, Handoff, Git-Diff noch Prozessargumenten erscheinen.
