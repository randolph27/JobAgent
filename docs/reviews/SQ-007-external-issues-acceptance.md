# SQ-007 – SonarQube-External-Issue-Import

Stand: 2026-09-17

## Abnahme

- Projekt: `jobagent-external-powershell`.
- Analyseumfang: `external-powershell-issues-only`; ausschließlich versionierte PowerShell-Dateien unter `.ci/bin` und `tools`.
- Import: 323 PSScriptAnalyzer-External-Issues, Report-SHA-256 `F91B440929EAF44A0357348842A7B6226A6E03DA068F66366310FE006799997D`.
- Compute Engine: Task `AaCvX7pnOhdKqVTDjfxf`, Analyse `AaCvX78SotDYp2WltXne`, terminaler Status `SUCCESS`.
- Sekretfreie Evidence: `logs/verify/sq-007-20260917-143744.json`.

## Technischer Vertrag

- Der Command `./ci.cmd sonar-external-import` prüft Paket-, Einstiegspunkt- und Scanner-JAR-Hashes unter `.ci/tools/sonar` vor jedem Lauf.
- Java 11 und SonarScanner laufen ausschließlich projektlokal. Der Token wird nur über die Child-Umgebung übergeben, nie als Scannerargument, Datei, Log, Evidence oder Handoff-Inhalt.
- Der Report ist UTF-8 ohne BOM, enthält nur projektrelative Pfade sowie validierte Zeilenbereiche und weist leere Reports, unbekannte Regeln, Traversierung, ausgeschlossene Pfade und ungültige Zeilen fail-closed ab.
- Der Scanner legt das eindeutig konfigurierte Projekt nur an, wenn es noch nicht existiert. Quality-Gates, Quality-Profile und globale Toolinstallationen bleiben unverändert.

## Funktionstests

```powershell
pwsh -NoProfile -File .\tests\Test-SonarToolchain.ps1
pwsh -NoProfile -File .\tests\Test-SonarExternalIssues.ps1
pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1
.\ci.cmd sonar-external-import
```

Alle fünf Läufe endeten mit Exit 0. Der negative Scannerpfad verwendet einen fehlenden lokalen JAR und endet deterministisch mit `sonar_external_scanner_failed`; ein Server-Upload erfolgt dabei nicht.

## Grenzen

External Issues sind keine native PowerShell-Sprachanalyse. Es werden keine Aussagen zu Coverage, Duplikation, Quality-Profile-Regeln oder einem Quality Gate als Gesamtfreigabe abgeleitet. Browser-, Viewport- und Android-Audit: `not-applicable`. Der Vollsupertest wurde gemäß Nutzerregel nicht ausgeführt.
