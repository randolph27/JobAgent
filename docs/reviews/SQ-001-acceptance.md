# SQ-001 – Blocker Evidence

Stand: 2026-09-16

## Ergebnis

Status: `blocked`.

Der SonarQube-Status-Endpunkt `http://127.0.0.1:9000/api/system/status` antwortet mit `UP`. Der lokale Token aus `D:\_Scripte\_Sonar\token.txt` ist vorhanden, wurde nicht ausgegeben und liefert bei `GET /api/authentication/validate` den Wert `valid:false`. Der authentifizierte Read `GET /api/projects/search?ps=1` liefert HTTP 401.

Die aktuelle Konfiguration bleibt deshalb korrekt auf `sonar.mode: not-supported`; es wurde kein Scanner, keine Projektanlage und keine Analyse gestartet.

## Benötigte externe Aktion

Ein SonarQube-Administrator muss einen neuen lokalen Token mit mindestens Browse- und Execute-Analysis-Berechtigung für den vorgesehenen Projekt-Key bereitstellen. Danach kann der authentifizierte API-Read erneut ausgeführt und erst bei HTTP 200 eine projektlokale Scannerkonfiguration bewertet werden.

## Reproduzierbarer, sekretfreier Check

```powershell
$token = (Get-Content -LiteralPath 'D:\_Scripte\_Sonar\token.txt' -Raw).Trim()
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token + ':'))
$headers = @{ Authorization = 'Basic ' + $encoded }
Invoke-RestMethod -Headers $headers -Uri 'http://127.0.0.1:9000/api/authentication/validate' -TimeoutSec 10
Invoke-WebRequest -Headers $headers -Uri 'http://127.0.0.1:9000/api/projects/search?ps=1' -TimeoutSec 10
```

Der Token darf weder in Logs, Handoff, Git-Diff noch Prozessargumenten erscheinen.
