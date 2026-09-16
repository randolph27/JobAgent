# SQ-001 – Blocker Evidence

Stand: 2026-09-16

## Ergebnis

Status: `open`.

Der lokale SonarQube-Container wurde neu installiert und ist unter `http://127.0.0.1:9000` erreichbar (`UP`). Das Standard-Admin-Passwort wurde ersetzt. Der neue, ausschließlich außerhalb des Repositories gespeicherte `Token:`-Eintrag in `D:\_Scripte\_Sonar\token.txt` liefert bei `GET /api/authentication/validate` den Wert `valid:true`; `GET /api/projects/search?ps=1` liefert HTTP 200. Weder Passwort noch Tokenwert wurden ausgegeben.

Die aktuelle Konfiguration bleibt auf `sonar.mode: not-supported`; es wurde weiterhin kein Scanner, keine Projektanlage und keine Analyse gestartet.

## Nächste technische Aktion

Die Tokenvoraussetzung ist erfüllt. Als Nächstes müssen die unterstützte Scanner-/Analyzer-Kombination und ein Projekt-Key für die vorhandenen PowerShell-, JSON- und statischen HTML-Dateien anhand offizieller SonarQube-Dokumentation belegt werden. Erst dann darf ein projektlokaler Analysemodus aktiviert werden.

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
