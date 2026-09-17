# SQ-006 – Analyseumfang und Lieferkette

Stand: 2026-09-17

## Entscheidung

Der Analyseumfang lautet verbindlich `external-powershell-issues-only`. SonarQube Server 9.9 analysiert PowerShell nicht nativ. Deshalb wird kein Community-Plugin installiert. Ein zukuenftiger Lauf darf ausschliesslich einen projektlokal ausgefuehrten PSScriptAnalyzer-Bericht als SonarQube Generic External Issues importieren. Er erzeugt damit weder native PowerShell-Regeln noch Coverage, Duplikatmetriken, Quality-Profile-Regeln oder eine Quality-Gate-Aussage.

Der Server meldet lokal Version `9.9.8.100196`. Die verwendbare Scanner-Linie ist SonarScanner CLI `4.8.x` mit einer Java-11-Laufzeit. Die aktuell im PATH gefundene Java-Laufzeit `26` ist nicht Teil dieser Lieferkette und darf nicht fuer den Scan verwendet werden. Die drei Artefakte liegen verifiziert unter `.ci/tools/sonar`; der CI-Command bleibt bis SQ-008 dennoch bewusst nicht scanfaehig.

## Belegter Vertrag

- Die [SonarQube-9.9-Scanner-Dokumentation](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/scanners/sonarscanner) nennt fuer SonarQube 9.9 mit Java 11 die letzte kompatible Scanner-Linie `4.8.x`.
- Das [SonarQube-9.9-Format fuer Generic External Issues](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/importing-external-issues/generic-issue-import-format) erlaubt einen vorab erzeugten JSON-Bericht ueber `sonar.externalIssuesReportPaths`; Version 9.9 erwartet das alte Top-Level-Format mit `issues`.
- Laut [SonarQube-Dokumentation zum Import dritter Befunde](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/importing-external-issues/importing-third-party-issues) verwaltet SonarQube weder die Aktivierung externer Regeln noch deren False-Positive-Status. Daher bleibt die Regelsteuerung bei PSScriptAnalyzer.
- [Microsoft Learn zu PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules) belegt die projektbezogen konfigurierbare Ausfuehrung von `Invoke-ScriptAnalyzer`; die vorgesehene Modulversion ist `1.25.0`.

## Projektlokale Lieferkette

Die kanonische, ignorierte Wurzel ist `.ci/tools/sonar`. Sie darf nur die in `.ci/ci.config.json` beschriebene Struktur enthalten. Benutzerprofil-, globale PowerShell-Modul-, NuGet- und PATH-Artefakte sind keine zulaessige Quelle.

| Artefakt | Version | Erwarteter relativer Einstieg | Zustand |
| --- | --- | --- | --- |
| SonarScanner CLI | 4.8.1.3023 | `sonar-scanner-4.8.1.3023-windows/bin/sonar-scanner.bat` | verifiziert |
| Java-Laufzeit | 11.0.32.1+1 | `jre/bin/java.exe` | verifiziert |
| PSScriptAnalyzer | 1.25.0 | `PSScriptAnalyzer/1.25.0/PSScriptAnalyzer.psd1` | verifiziert |

Die Originalpakete liegen unter `packages/`; jedes Paket und jeder Einstiegspunkt wird gegen einen erfassten SHA-256 abgeglichen. Ein fehlendes Artefakt, eine Pfadtraversierung, ein anderer Einstiegspfad oder ein abweichender Hash endet fail-closed. Die Projektanlage und jeder Upload sind nicht Teil von SQ-006 und benötigen eine getrennte Ausführungsfreigabe.

## Grenzen fuer SQ-007 und SQ-008

- Scanner-Argumente, Berichte, Evidence und Handoff enthalten keinen Token, Authorization-Header oder dessen Laenge.
- Zulässig sind nur projektrelative Quellpfade; `data/`, `logs/`, `.git/`, Caches und Testausgaben sind ausgeschlossen.
- Ein externer Befundimport ist keine native Sprachunterstuetzung. Ein technischer Quality-Gate-Status darf nicht als Gesamtfreigabe oder PowerShell-Qualitaetsurteil ausgegeben werden.
- Bis zum abgeschlossenen SQ-008-Lifecycle bleibt `./ci.cmd sonar` korrekt bei `not-supported` und startet keine Analyse.
