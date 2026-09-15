# Handoff latest

Stand: 2026-09-15T20:15:42.228+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel:
- Branch: `master`
- HEAD: `1f4319b52073`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `handoff.latest.md`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
- `tests/Test-JobAgentJobBoardDiscovery.ps1`
- `tests/Test-JobAgentRegionalDiscovery.ps1`
- `tests/Test-JobAgentRegisterDiscovery.ps1`
- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-003 Discovery, Quellenverifikation, Wiederanlauf und CLI-Betrieb vollstaendig testen #comment: Der regulaere Start muss vom Firmenhinweis bis zur atomaren WebIF-Publikation einschliesslich Transportfehlern deterministisch nachgewiesen sein.

## Detailhandoff fuer den Folgechat

### Abgeschlossener Teilschnitt

- QA-003.1 ist abgeschlossen; die Roadmap-Unteraufgabe ist abgehakt. Der Nachweis steht in `docs/reviews/QA-003.1-discovery-verification.md`.
- `Resolve-JobAgentCandidateOfficialWebsiteDiscovery` akzeptiert keine fremddomainigen Redirects mehr. Dasselbe gilt fuer die Initial- und Zielabrufe von `Resolve-JobAgentCompanyCareerVerification`.
- Neue isolierte Fälle pruefen fremddomainige Karriere- und Verzeichnisredirects sowie Login-/Captcha-Inhalte. Keiner davon darf eine offizielle Firmenwebsite, Karrierequelle oder ATS-Quelle erzeugen.
- Register-, Jobboersen- und Regionalhints behaupten Quellhash und den festen Verifikationsentscheid. Unvollstaendige Registeridentitaeten bleiben `UNKNOWN` und erhalten keinen starken Register-Dedupe-Key.
- Gleichnamige Kandidaten mit verschiedenen Register-IDs bleiben getrennt und erhalten den Konflikt `NAME_MATCH_WITHOUT_STRONG_IDENTITY`.
- Die Skalierungsfixture liefert unveraendert 1.008 Kandidaten und 1.006 Cluster. Die nichtdeterministische Laufzeitassertion wurde entfernt.

### Verifizierte Tests

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` — Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` — Exit 0

### Nächster Arbeitsschnitt: QA-003.2

1. Ausschliesslich Fixture-/Stub-basierte Adaptertests erweitern: wiederholte Seiten/IDs, leere Seite, Pagination-Limit, fehlender REQUIRED-Suchterm, Navigation statt Stelle und ungueltige Detailseite.
2. 200/404/429/503, Timeout, DNS-/TLS-Fehler, defektes JSON, Redirectschleife und Retry-After mit Requestanzahl, Reihenfolge und Fehlerklasse testen. Keine echte Netzprobe.
3. `Test-JobAgentFetchEnvironment.ps1`, `Test-JobAgentFetchErrorInspection.ps1`, `Test-JobAgentSourceAdapters.ps1`, `Test-JobAgentSourceVerification.ps1` und `Test-JobAgentLiveScan.ps1` zuerst einzeln ausführen. Tokens weder in Fixtures noch in Logs aufnehmen.
4. Danach QA-003.3 mit isolierten CLI-/Resume-Läufen, Checkpoint-/Store-/Reporthashes und atomarer Publikation umsetzen. Port 8500 nur über `./ci.cmd devserver-status` und bei Bedarf `./ci.cmd devserver-start` verwalten; keinen fremden Listener beenden.

QA-003 bleibt offen; deshalb wurde kein Supertest gestartet und keine Roadmap-Rotation vorgenommen. QA-004 bis QA-006 sowie TD-0056 bleiben unverändert offen.
