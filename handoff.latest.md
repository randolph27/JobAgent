# Handoff latest

Stand: 2026-09-15T19:56:31.748+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel:
- Branch: `master`
- HEAD: `c23090541b1b`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-003 Discovery, Quellenverifikation, Wiederanlauf und CLI-Betrieb vollstaendig testen #comment: Der regulaere Start muss vom Firmenhinweis bis zur atomaren WebIF-Publikation einschliesslich Transportfehlern deterministisch nachgewiesen sein.

## Detaillierte Uebergabe fuer den Folgechat

### Arbeitsstand

- Branch `master`; vor diesem STP auf `c230905` und mit `origin/master` synchron. Der folgende Abschluss committtet die frischen STP-/Handoff-Artefakte.
- `QA-001` und `QA-002` sind vollstaendig abgeschlossen und in `Roadmap_archive.md` rotiert. Aktive Roadmap-Punkte sind `QA-003` bis `QA-006`; `TD-0056` bleibt als separater CI-Driftbefund offen.
- `QA-002` wurde mit Commit `c230905 test: complete qa-002 report contracts` abgeschlossen. `tests/Test-JobAgentReport.ps1` prueft jetzt eine feste isolierte Storegeneration gegen JSON-, Markdown-, Daily-HTML- und Coverage-JSON-Sollwerte: IDs, Mengen, Capture-Manifest, Teilgrenze, A/B-Prioritaeten, `UNKNOWN`, lange Unicodewerte, HTML-/Script-Escaping, Sperre von `javascript:` und zwei identische Laeufe mit festem Zeitpunkt.
- Die acht QA-002-Funktionstests sind belegt gruen: Schema, Persistence, CompanyInventory, Classification, Deduplication, StatusMachine, Report und Coverage. Der Schema-AJV-Test brauchte lediglich den bereits vorhandenen lokalen npm-Cache ausserhalb der Sandbox. Kein Produktionsmodul wurde in QA-002 geaendert.
- Der Supertest ist nicht ausgefuehrt. Nach Nutzerregel gilt ein nicht angefragter Supertest als erledigt; dies ist kein behaupteter gruener Gesamtlauf.

### Naechster Arbeitsschnitt: QA-003.1

Ziel: Discovery und offizielle Verifikation mit reproduzierbaren Fixtures vollstaendig abdecken. Keine Live-Webrecherche, keine produktiven Stores, keine externen Kontakte und keine fremden Prozesse veraendern.

1. Vorhandene Register-, Jobboersen- und Regionalfixtures fuer leer, dupliziert, veraltet, ungueltig, `UNKNOWN`, widerspruechliche Domains/Register-IDs und Namensgleichheit erweitern.
2. Fail-closed pruefen: Nur belegte offizielle Firmen-, Karriere- oder ATS-Quellen duerfen Firmen verifizieren. Aggregatoren, fremde Redirects, Login/Captcha und unbelegte URLs bleiben Discovery-Hinweise und duerfen keine offizielle JobSource erzeugen.
3. Vorhandene Kandidatenverifikation, Website-/Karriereverifikation und Refill-CLI ausschliesslich mit Fixtureeingaben ausfuehren; je importiertem Kandidaten Quellhash und Entscheidungsgrund behaupten. Die bestehenden 1.008-/1.006- und Skalierungsfixtures erhalten; keine willkuerliche Laufzeitgrenze und keine echte Firmenmindestmenge einfuehren.

Vorrangige Funktionstests fuer QA-003.1:

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1`

### Folgeschritte und Grenzen

- QA-003.2 behandelt Adapter- und Transportfehler nur mit kontrollierten Responses/Stubs (200/404/429/503, Timeout, DNS/TLS, defektes JSON, Redirectschleife, Retry-After); niemals über echte Netzproben.
- QA-003.3 prueft zwei isolierte CLI-/Resume-Laeufe, Checkpoint-, Store- und Reporthashes sowie atomare Publikation. Devserver ausschliesslich über `.\ci.cmd devserver-status` und bei Bedarf `.\ci.cmd devserver-start` auf Port 8500 verwalten; keinen fremden Listener beenden.
- Erst danach folgen QA-004 (UI-Zustandsmatrix), QA-005 (Geometrie/Tastatur/Sichtung) und QA-006 (matrixgesteuerter Aggregator). TD-0056 nur analysieren; keine Pins, Snapshots oder Immutables zur kosmetischen Driftbereinigung aendern.
- Sonar ist weiterhin `not-supported`; ein Dienst auf Port 9000 ist keine durchgefuehrte Analyse.
