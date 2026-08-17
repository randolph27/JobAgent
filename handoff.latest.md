# Handoff latest

Stand: 2026-08-17T14:13:00+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Abschluss-Commit: `27413124fb4c`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree: `dirty-before-commit`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-007` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0006 / JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren`

## Erledigter Arbeitsschritt

`JA-007 Stellenklassifikation fuer IT-Fuehrungspositionen entwickeln` ist abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. `TD-0005` wurde aus `todo.current.md` entfernt und im Todo-Index auf `done` gesetzt.

Implementiert:

- `src/JobAgent.Classification.psm1`
  - `Get-JobAgentLeadershipClassification`: bewertet Titel, Summary, Beschreibung, Standort, Arbeitsmodell und Beschaeftigungsart deterministisch.
  - Ergebniswerte: `MATCH`, `POSSIBLE`, `REJECTED`; `UNKNOWN` bleibt im Schema fuer noch nicht klassifizierte Roh-/Altdaten reserviert.
  - Positive Signale: CIO, Chief Information Officer, Head/Director/VP IT, IT-Leitung, IT-Gesamtverantwortung, Personal-/Budgetverantwortung, IT-Strategie, Technology Strategy.
  - Negative Signale: Entwickler-, Specialist-, Consultant-, Architect-, Admin-, reine Projektleitungs- und Teamlead-Rollen ohne belegte Gesamt- oder Strategie-Verantwortung.
  - Standortlogik: `MUNICH`, `MUNICH_20KM`, `FREISING` und `REMOTE_WITH_TARGET_REFERENCE` positiv; `OUT_OF_SCOPE` fail-closed `REJECTED`; `UNKNOWN` wird als Risiko markiert, lehnt starke IT-Leitung aber nicht automatisch ab.
  - Ausgabe enthaelt `score`, `priority`, `reasons`, `rejected_reasons` und `evaluated_at`.
- `tests/Test-JobAgentClassification.ps1`
  - Deckt deutsche und englische Fuehrungstitel, Remote-Deutschland-Bezug, Entwickler-Ausschluss, Projektleitungs-Ausschluss, Teamlead-Ausschluss, leeren Titel, unklaren Standort, ausserhalb Zielgebiet und Grenzfall `IT Manager` ab.
- `tests/Test-JobAgentSupertest.ps1`
  - Buendelt abgeschlossene JobAgent-Funktionstests fuer Schema, Persistenz, Firmeninventar, Quellenadapter, Quellenverifikation und Klassifikation.
- `docs/data-model.md`
  - Abschnitt `Stellenklassifikation` mit Vertrag, Signalen, Ausschluessen, Standortlogik und Testcommand ergaenzt.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentClassification.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, zuletzt Log `logs\terminal\self-check-20260817-141207.log`
- `.\ci.cmd stp` -> Exit `0`

Supertest:

- Der projektspezifische JobAgent-Supertest `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` ist gruen.
- Der historische CI-Command `.\ci.cmd supertest` ist weiterhin nicht als Abschlussblocker gewertet, weil der Nutzer Supertest nicht gesondert angefragt hat und laut Nutzerregel nicht angefragter Supertest als erledigt gilt.
- Bekannter historischer CI-Supertest-Fehler bleibt ausserhalb JA-007: kein Gradle-Build im Projektroot und fehlender lokaler `D:\_Scripte\JobAgent\sonar.cmd`.

## Dienste und Umgebung

- Devserver aus vorherigem Stand lief auf `http://localhost:8300/`; in diesem Abschluss wurde kein neuer Devserver gestartet.
- SonarQube API auf `localhost:9000` war nicht erreichbar; `.\ci.cmd sonar-start` scheiterte wegen fehlendem lokalem `sonar.cmd`.
- Kein Live-Webcrawl und keine produktiven Bewerbungs-/Jobdaten wurden erzeugt.

## Offene Aufgaben

1. `TD-0006 / JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren`
   - Nutze `ConvertTo-JobAgentCanonicalUrl` aus JA-006.
   - Prioritaet der Identitaet: offizielle Job-ID, ATS-ID, kanonische URL, danach zusammengesetzter Fingerprint.
   - Gleiche Stelle darf im zweiten Lauf nicht erneut `NEW` werden.
   - Testfaelle: Job-ID-Wechsel, URL-Parameteraenderung, Titelwechsel, echte Neuausschreibung, entfernte Stelle.
2. `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`
   - Erst nach JA-008 sinnvoll.
   - Muss Scanfehler von echten Entfernungen unterscheiden.
3. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`
   - Erst nach Klassifikation, Deduplikation und Statusmaschine sinnvoll.
   - Mock-Adapter zuerst; keine Live-Webrecherche in Funktionstests.

## Risiken fuer neuen Agenten

- Klassifikation ist regelbasiert und konservativ; `POSSIBLE` ist fuer Grenzfaelle vorgesehen und darf nicht als verifizierter Match ausgegeben werden.
- `Company.ats` muss pro Firma belegt gepflegt werden; keine globale ATS-Allowlist.
- `.\ci.cmd supertest` verweist noch auf Alt-/Android-/Gradle-Logik und ist nicht identisch mit `tests\Test-JobAgentSupertest.ps1`.
- SonarQube ist aus diesem Projekt heraus blockiert, solange `D:\_Scripte\JobAgent\sonar.cmd` fehlt oder der Server auf `localhost:9000` nicht antwortet.
