# Handoff latest

Stand: 2026-08-24T09:05:57+02:00

## Neuer Chat Einstieg

Der naechste Chat/Agent soll mit `TD-0034 / JA-034` weitermachen. Es wurden drei neue Roadmap-Punkte angelegt und via `todo-seed` in Todo uebernommen. Es sind keine Roadmap-Punkte komplett erledigt, daher wurde nichts nach `Roadmap_archive.md` rotiert.

## Aktueller Zustand

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor diesem Handoff-Commit: `15461ad488c8`
- Upstream: `origin/master`
- Worktree vor diesem Handoff-Commit: `dirty`
- Active: none
- Offene Todos: `TD-0034`, `TD-0035`, `TD-0036`
- Roadmap: `JA-034`, `JA-035`, `JA-036` aktiv
- Archiv: JA-001 bis JA-033 abgeschlossen und archiviert

## Offene Aufgaben

1. `TD-0034 / JA-034 Produktive Discovery-Snapshot-Lane fuer Muenchen/Freising aus erlaubten Quellen aufbauen`
   - Prioritaet: 94/100
   - Abhaengigkeiten: JA-023 bis JA-030 abgeschlossen; Grundlage sind Source Registry und vorhandene Discovery-Importer.
   - Ziel: Reale, erlaubte Quellen aus `data/jobagent/company-discovery.sources.json` begrenzt und reproduzierbar in lokale Kandidaten-Hints ueberfuehren.
   - Scope: `tools/Import-JobAgentCompanyDiscovery.ps1`, Discovery-Module, `data/jobagent/company-discovery.hints.json`, Snapshot-Logs, `docs/company-discovery-operations.md`, Discovery-Funktionstests.
   - No-Go: kein Login/Captcha, keine Robots-/Terms-Umgehung, keine Jobboerse als offizieller Beleg, keine Vollstaendigkeitsbehauptung, kein produktiver Store-Write.
   - Funktionstests: `tests\Test-JobAgentCompanyInventory.ps1`, `tests\Test-JobAgentRegisterDiscovery.ps1`, `tests\Test-JobAgentJobBoardDiscovery.ps1`, `tests\Test-JobAgentRegionalDiscovery.ps1`.

2. `TD-0035 / JA-035 Kandidaten-Review-Queue und Coverage-Arbeitsbericht fuer Muenchen/Freising operationalisieren`
   - Prioritaet: 86/100
   - Abhaengigkeiten: JA-034 muss mindestens aktuellen Snapshot oder belastbare Fixture liefern.
   - Ziel: Discovery-Hints nach Evidenzklasse, Zielgebietsbezug, Dublettencluster, Verifikationsstatus, Freshness, Risiko und Nutzen priorisieren.
   - Scope: `src/JobAgent.Coverage.psm1`, `src/JobAgent.CompanyInventory.psm1`, Coverage-Tool, Verification-Queue, `html/jobagent/company-coverage.html`, Coverage-/Dedupe-/HTML-Audit-Tests.
   - No-Go: keine automatische Loeschung unsicherer Hints, kein produktiver Upsert, keine Personen-/Kontaktdaten-Anreicherung, keine Bewerbung.
   - Funktionstests: `tests\Test-JobAgentCoverage.ps1`, `tests\Test-JobAgentCompanyDedupeScale.ps1`, `tests\Test-JobAgentHtmlAudit.ps1`.

3. `TD-0036 / JA-036 Begrenzte offizielle Verifikationswelle aus der Kandidaten-Queue ausfuehren`
   - Prioritaet: 78/100
   - Abhaengigkeiten: JA-034 und JA-035 abgeschlossen oder mit belastbaren Snapshot-/Fixture-Artefakten verifizierbar.
   - Ziel: Priorisierte Top-Kandidaten fail-closed gegen offizielle Firmen-, Karriere- oder ATS-Belege pruefen.
   - Scope: `tools/Verify-JobAgentCompanyCandidates.ps1`, `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.LiveScan.psm1`, Verification-Queue, Verification-Logs, SourceVerification-/LiveScan-Tests.
   - No-Go: keine Bewerbungen, kein Formular-Autofill, kein Login/Captcha, keine globale ATS-Allowlist ohne Firmenbeleg, keine ungesicherten Aggregator-URLs.
   - Funktionstests: `tests\Test-JobAgentCompanyCandidateVerification.ps1`, `tests\Test-JobAgentSourceVerification.ps1`, `tests\Test-JobAgentLiveScan.ps1`, bei Store-Write zusaetzlich `tests\Test-JobAgentCompanyInventory.ps1`.

## Zuletzt erledigt

- `JA-033` ist abgeschlossen, verifiziert und archiviert.
- Danach wurden `JA-034` bis `JA-036` priorisiert in `Roadmap.md` angelegt.
- `.\ci.cmd todo-seed` hat daraus `TD-0034` bis `TD-0036` erzeugt.
- Commit `15461ad Add next roadmap discovery wave` wurde bereits nach `origin/master` gepusht.

## Verifikation

- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd todo-seed` -> Exit `0` aus vorherigem Schritt
- `.\ci.cmd repin-immutables` -> Exit `0` aus vorherigem Schritt
- `.\ci.cmd self-check` -> Exit `0` aus vorherigem Schritt
- Supertest wurde in diesem Handoff nicht neu angefragt und gilt gemaess Nutzeranweisung als erledigt.

## Harte Regeln fuer Folgechat

- Keine Bewerbung, kein Formular-Autofill, keine extern wirksame Aktion ohne ausdrueckliche Bestaetigung.
- Keine Jobboerse als offizieller Stellen- oder Anbieterlink.
- Keine ungesicherten Aggregator-URLs als offizielle Quelle ausgeben.
- Keine neue Live-Abhaengigkeit in Funktionstests.
- Supertest erst nach gruenen Funktionstests; wenn nicht angefragt, gilt er gemaess Nutzeranweisung als erledigt.
- Devserver auf Port `8500` und SonarQube auf Port `9000` ueber `.\ci.cmd`-Befehle verwalten.
- Git-Kommandos non-interactive mit `git -c core.pager=cat -c color.ui=false --no-pager ...` ausfuehren.
