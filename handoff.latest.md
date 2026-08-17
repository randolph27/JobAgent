# Handoff latest

Stand: 2026-08-17T14:02:00+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `89c120ec8cbe`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-006` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0005 / JA-007 Stellenklassifikation fuer IT-Fuehrungspositionen entwickeln`

## Erledigter Arbeitsschritt

`JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren` ist abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. `TD-0004` wurde aus `todo.current.md` entfernt und im Todo-Index auf `done` gesetzt.

Implementiert:

- `src/JobAgent.SourceVerification.psm1`
  - `ConvertTo-JobAgentCanonicalUrl`: normalisiert absolute HTTP(S)-URLs, entfernt Fragment, Trackingparameter und Sessionparameter, erhaelt jobrelevante Parameter wie `jobId`.
  - `Get-JobAgentOfficialSourceEvaluation`: prueft URL gegen Firmendomain, explizite Karriere-URL und firmengebundene ATS-Domain aus `Company.ats`.
  - `New-JobAgentVerifiedJobSource`: erzeugt `JobSource` nur bei offizieller Quelle, sonst fail-closed.
  - `Resolve-JobAgentOfficialJobUrl`: liefert primaere offizielle URL und gefilterte alternative offizielle URLs.
  - Aggregator-Ablehnung fuer StepStone, Indeed, LinkedIn, XING, Kununu und Glassdoor.
- `tests/Test-JobAgentSourceVerification.ps1`
  - Deckt Kanonisierung, Firmen-/Subdomain, Karriere-URL, ATS-Domain, Aggregator-Ablehnung, unbekannte Drittquelle, validierte JobSource und alternative offizielle URLs ab.
- `schemas/jobagent.schema.json`
  - `job.alternative_official_urls` als Pflichtfeld ergaenzt.
- `src/JobAgent.Persistence.psm1`
  - Persistenzvalidierung verlangt `alternative_official_urls`.
- `docs/data-model.md`
  - Abschnitt zur Quellenverifikation und URL-Kanonisierung ergaenzt.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-140037.log`
- `.\ci.cmd stp` -> Exit `0`

Supertest:

- Nicht erneut angefragt. Nach Nutzerregel gilt Supertest fuer diesen Abschluss als erledigt.
- Historischer Lauf `.\ci.cmd supertest` hatte Exit `1`, Ursache ausserhalb JA-006: kein Gradle-Build im Projektroot und fehlender lokaler `D:\_Scripte\JobAgent\sonar.cmd`. Log: `logs\terminal\supertest-20260817-135315.log`.

## Dienste und Umgebung

- Devserver wurde per `.\ci.cmd devserver-start` gestartet und laeuft auf `http://localhost:8300/`, PID `39872`.
- SonarQube auf `localhost:9000` war per HTTP nicht nutzbar; `.\ci.cmd sonar-start` scheiterte wegen fehlendem lokalem `sonar.cmd`.
- Keine Live-Webrecherche und keine produktiven Bewerbungs-/Jobdaten wurden erzeugt.

## Offene Aufgaben

1. `TD-0005 / JA-007 Stellenklassifikation fuer IT-Fuehrungspositionen entwickeln`
   - Regelbasierte Klassifikation fuer IT-Fuehrungsrollen implementieren.
   - Positive Signale: Head/Director/CIO/IT-Leitung, IT-Gesamtverantwortung, Budget-/Personalverantwortung, strategische IT-Verantwortung.
   - Negative Signale: reine Entwicklerstellen, Spezialistenrollen, Projektleitung ohne IT-Gesamtverantwortung, Teamlead ohne wesentliche Fuehrungsverantwortung.
   - Ergebnis: `MATCH`, `POSSIBLE`, `REJECTED` mit Score, Prioritaet und nachvollziehbaren Gruenden.
   - Tests: deutsche/englische Titel, leere Beschreibung, widerspruechlicher Titel, unklarer Standort, Remote-Deutschland-Bezug, Teamlead-Ausschluss.
2. `TD-0006 / JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren`
   - Erst nach oder parallel zu JA-007 sinnvoll, nutzt offizielle/kanonische URLs aus JA-006.
3. `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`
   - Nach Deduplikation bearbeiten.
4. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`
   - Nach Persistenz, Adaptervertrag, Quellenverifikation, Klassifikation, Deduplikation und Statusmaschine.

## Risiken fuer neuen Agenten

- `Company.ats` muss pro Firma belegt gepflegt werden; es gibt keine globale ATS-Allowlist.
- Redirect-Pruefung ist ohne Live-Lane nicht implementiert, nur kanonische Ziel-URL-Bewertung.
- Der bestehende Projekt-Supertest ist noch nicht auf den PowerShell-basierten JobAgent-Funktionsstack zugeschnitten.
