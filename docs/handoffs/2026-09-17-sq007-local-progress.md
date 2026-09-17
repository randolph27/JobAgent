# Übergabe – SQ-007 lokaler Fortschritt

Stand: 2026-09-17T14:19:13+02:00

## Aktiver Punkt

- Todo: `TD-0068`, Status `blocked`.
- Roadmap: `SQ-007 PowerShell-Befunde als SonarQube-External-Issues deterministisch erzeugen und importieren`.
- Abhängiger Folgepunkt: `SQ-008` bleibt offen und darf erst nach einem erfolgreichen sowie einem erwarteten negativen SQ-007-Import beginnen.

## Fertiggestellt

1. Die lokale, gitignorierte Lieferkette liegt ausschließlich in `.ci/tools/sonar`:
   - SonarScanner CLI `4.8.1.3023`;
   - Temurin JRE `11.0.32.1+1`;
   - PSScriptAnalyzer `1.25.0`.
2. `.ci/ci.config.json` und `docs/reviews/SQ-006-toolchain.json` pinnen für jedes Originalpaket und jeden Einstiegspunkt einen SHA-256. `Test-SonarToolchain.ps1` prüft beide Hashklassen, Pfadcontainment, fehlende Artefakte, Traversierung und Hashabweichungen fail-closed.
3. `.ci/bin/modules/sonar-external-issues.ps1` enthält:
   - Toolchain-Validierung;
   - den eingeschränkten Source-Satz `.ci/bin` und `tools`;
   - PSScriptAnalyzer-Regel- und Severity-Normalisierung;
   - Generic-Issue-JSON für SonarQube 9.9 mit relativen Pfaden, UTF-8 ohne BOM, Deduplizierung und validierten Zeilenbereichen;
   - Ablehnung von `data/`, `logs/`, `.git`, Caches, Testquellen und Pfaden außerhalb des Repository-Roots.
4. Der lokale PSScriptAnalyzer-Lauf erzeugte `320` Befunde in `logs/sonar/sq-007-local-generic-issues.json`, SHA-256 `858BEBF1CE8D7CA2F8284F3BC44DEC54B14E26893208C7430189B773BC2C9C1B`.
5. `./ci.cmd sonar` bleibt absichtlich `not-supported` und startet keinen Scanner. Die Umstellung dieses Commands gehört zu SQ-008.

## Nachweise

Alle folgenden Funktionstests endeten mit Exit `0`:

```powershell
pwsh -NoProfile -File .\tests\Test-SonarToolchain.ps1
pwsh -NoProfile -File .\tests\Test-SonarExternalIssues.ps1
pwsh -NoProfile -File .\tests\Test-SonarAuth.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1
```

`Test-SonarExternalIssues.ps1` deckt leeren Bericht, unbekannte Regel, Pfad außerhalb des Roots, ausgeschlossenen Pfad, ungültige Zeilen, Deduplizierung, UTF-8 ohne BOM und einen lokalen PSScriptAnalyzer-Lauf ab.

Der Supertest wurde gemäß ausdrücklicher Nutzerregel nicht ausgeführt und in der Roadmap als erledigt markiert.

## Externer Blocker und nächster Arbeitsschnitt

Es existieren kein SonarQube-Projekt-Key, kein `sonar-project.properties`, kein Upload und keine Analyse-ID. Für den nächsten Schritt ist eine ausdrückliche Freigabe erforderlich, genau ein SonarQube-Projekt anzulegen und einen External-Issue-Report nach `localhost:9000` hochzuladen.

Nach Freigabe, in dieser Reihenfolge:

1. Projekt-Key und minimalen Scanner-Konfigurationsvertrag festlegen, ohne Token in Dateien, Argumentlisten oder Logs zu schreiben.
2. Einen separaten SQ-007-Importcommand mit lokal gepinnter Java-11-Runtime und Scanner-JAR implementieren; die mitgelieferte Scanner-Batchdatei überschreibt `JAVA_HOME` und ist daher nicht als Java-11.0.32.1+1-Wrapper geeignet.
3. Negativtests für Scanner-Exit, abgelaufene Compute-Engine-Task-Antwort und invalide Reportdaten ergänzen.
4. Einmalig importieren, Compute-Engine bis zu einem terminalen Status pollen und ausschließlich Projekt-Key, Task-/Analyse-ID, Befundzahl, Report-Hash und Exitcode dokumentieren.
5. Erst bei erfolgreichem Import und belegter Negativprobe SQ-007 abschließen, in `Roadmap_archive.md` rotieren und TD-0068 abschließen. Danach SQ-008 beginnen.

## Grenzen

- Keine globale Installation und keine Community-Plugins.
- Keine native PowerShell-Analyse, Coverage-, Duplikat-, Quality-Profile- oder Quality-Gate-Aussage.
- Keine Analyse oder Uploads aus `data/`, `logs/`, `.git`, Caches oder Testausgaben.
- Keine Tokens, Header, Queryparameter, Tokenlängen oder Scanner-Debugdumps in Evidence, Handoff oder Git.
