# SQ-007 – lokaler External-Issue-Adapter

Stand: 2026-09-17

## Nachgewiesener lokaler Teil

- Der projektlokale Lieferkettenvertrag steht auf `verified`. Originalpakete und Einstiegspunkte der drei Artefakte werden unter `.ci/tools/sonar` jeweils per SHA-256 und Root-Containment geprüft.
- `Invoke-SonarExternalIssuesReport` analysiert ausschließlich versionierte PowerShell-Dateien in `.ci/bin` und `tools`. `data/`, `logs/`, `.git`, Caches und Testquellen sind nicht Teil des Source-Satzes und werden vom Adapter auch bei projektrelativen Pfaden abgewiesen.
- Der Adapter erzeugt SonarQube-9.9-kompatibles Generic-Issue-JSON mit `engineId=PSScriptAnalyzer`, bekannter Regel-ID, projektrelativem Pfad und gültigem Zeilenbereich, sofern PSScriptAnalyzer eine Position liefert. Dateiweite PSScriptAnalyzer-Befunde ohne Zeilenposition bleiben dateigebunden.
- Der lokale Lauf erzeugte `320` Befunde als UTF-8-Report unter `logs/sonar/sq-007-local-generic-issues.json` mit SHA-256 `858BEBF1CE8D7CA2F8284F3BC44DEC54B14E26893208C7430189B773BC2C9C1B`. Der Report enthält keine Tokens oder Header.

## Funktionstests

- `pwsh -NoProfile -File .\tests\Test-SonarToolchain.ps1`
- `pwsh -NoProfile -File .\tests\Test-SonarExternalIssues.ps1`
- `pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`

Die Tests decken Paket- und Einstiegspunkthashes, leeren Bericht, unbekannte Regel, Pfad außerhalb des Roots, ausgeschlossene Pfade, ungültige Zeilenbereiche, UTF-8 ohne BOM, Deduplizierung und einen lokalen PSScriptAnalyzer-Lauf ab.

## Offener Abschlussblocker

Es wurde kein SonarQube-Projekt angelegt und kein Report hochgeladen. Die externe Projektanlage, ein erfolgreicher Import, Compute-Engine-Task-Polling und die erwartete negative Importprobe bleiben ausdrücklich offen.
