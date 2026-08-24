# Handoff latest

Stand: 2026-08-24T09:31:37+02:00

## Neuer Chat Einstieg

Der neue Chat/Agent soll mit `TD-0036 / JA-036` weitermachen: begrenzte offizielle Verifikationswelle aus der Kandidaten-Review-Queue ausfuehren. `JA-034` und `JA-035` sind abgeschlossen, verifiziert, archiviert und committed. Es gibt aktuell nur noch einen aktiven Roadmap-Punkt.

## Aktueller Zustand

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD vor diesem Handoff-Commit: `c1239cd40ad0`
- Upstream: `origin/master`
- Ahead/Behind vor Push: `2/0`
- Worktree vor diesem Handoff-Commit: `dirty`
- Active: none
- Offenes Todo: `TD-0036`
- Aktive Roadmap: `JA-036`
- Archiv: `JA-001` bis `JA-035` abgeschlossen und archiviert
- SonarQube: `http://localhost:9000/api/system/status` -> `UP`
- Devserver: `http://localhost:8500/` laeuft

## Zuletzt erledigt

1. `TD-0034 / JA-034 Produktive Discovery-Snapshot-Lane fuer Muenchen/Freising`
   - Status: abgeschlossen und nach `Roadmap_archive.md` rotiert.
   - Output: `data/jobagent/company-discovery.hints.json` mit 19 unverifizierten Hints.
   - Evidence: `logs/jobagent/company-discovery-snapshot-digest-20260824-071422.json` plus Snapshot-Logs.

2. `TD-0035 / JA-035 Kandidaten-Review-Queue und Coverage-Arbeitsbericht`
   - Status: abgeschlossen und nach `Roadmap_archive.md` rotiert.
   - Output: `data/jobagent/company-candidate-verification.queue.json`.
   - Queue-Stand: 18 Cluster aus 19 Kandidaten.
   - Aktionen: 15 `VERIFY_OFFICIAL_SITE`, 1 `CHECK_LOCATION`, 1 `REJECT_DUPLICATE`, 1 `MANUAL_DECISION`.
   - Coverage-Artefakte: `logs/jobagent/company-coverage-20260824-072454.json`, `logs/jobagent/company-coverage-20260824-072454.md`, `html/jobagent/company-coverage.html`.
   - Commit: `c1239cd Add candidate review queue`.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentRegisterDiscovery.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

## Naechste Aufgabe

`TD-0036 / JA-036 Begrenzte offizielle Verifikationswelle aus der Kandidaten-Queue ausfuehren`

Ziel: Priorisierte Top-Kandidaten aus `data/jobagent/company-candidate-verification.queue.json` begrenzt und fail-closed gegen offizielle Firmen-, Karriere- oder ATS-Belege pruefen. Nur belastbare Evidenz darf `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED` oder `OFFICIAL_ATS_VERIFIED` erzeugen. Unsichere Faelle bleiben in Retry, Manual Review oder Reject.

Empfohlener Start:

1. Queue und Top-Kandidaten lesen:
   - `data/jobagent/company-candidate-verification.queue.json`
   - Top-Prioritaeten mit `next_action=VERIFY_OFFICIAL_SITE`
2. Wellenlimit festlegen:
   - kleiner Lauf, z.B. `MaxCandidates` 3 bis 5
   - Rate-Limits, Timeout und Retry-Regeln aus Source Registry/Queue beachten
3. Zuerst fixturebasierte Funktionstests pruefen und bei Bedarf erweitern:
   - `pwsh -NoProfile -File tests\Test-JobAgentCompanyCandidateVerification.ps1`
   - `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1`
   - `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1`
4. Danach begrenzte Verifikationswelle ueber `tools/Verify-JobAgentCompanyCandidates.ps1` ausfuehren.
5. Bei Store-Write zusaetzlich `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` ausfuehren.

## Harte Regeln

- Keine Bewerbung.
- Kein Formular-Autofill.
- Kein Login/Captcha.
- Keine extern wirksame Aktion ohne ausdrueckliche Bestaetigung.
- Keine Jobboerse als offizieller Stellen- oder Anbieterlink.
- Keine ungesicherten Aggregator-URLs als offizielle Quelle.
- Keine globale ATS-Allowlist ohne Firmenbeleg.
- Unsichere Verifikation fail-closed lassen.
- Supertest erst nach gruenen Funktionstests; wenn nicht neu angefragt, gilt er gemaess Nutzeranweisung als erledigt.
- Devserver auf `:8500` und SonarQube auf `:9000` nur ueber `.\ci.cmd` beziehungsweise Sonar-API/Curl verwalten.
