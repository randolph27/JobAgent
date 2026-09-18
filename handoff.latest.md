# Handoff latest

Stand: 2026-09-18T08:54:41.435+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: Keine aktive Roadmap-Aufgabe.
- Branch: `master`
- HEAD: `92441e14f5f8`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

M2 – Stellenboersen-Oberflaeche: JA-048 Stellendetails und zwei eindeutig bedienbare Sterne integrieren #comment: Jede Stelle muss vollstaendig pruefbar, separat merkbar und manuell als schon beworben markierbar sein.

## Fortsetzungsstand JA-048 / TD-0076

### Implementierung

- `src/JobAgent.Report.psm1` rendert fuer jede Stellenkarte und Detailansicht zwei getrennte Schalter: `favorite` und `applied`. Beide schreiben ausschliesslich in den browserlokalen v1-Store, besitzen getrennte Texte und `aria-pressed`-Werte und unterbinden Navigation.
- Nach jeder Markierungsaktion wird die Ansicht neu gerendert. Eine jobbezogene Statusmeldung bleibt dabei im aktuellen Browserdokument bestehen. Damit werden Liste, Detailansicht, Filter und Schalterzustand gemeinsam aktualisiert.
- Die Detailansicht verwendet `#job=<job_id>`, bewahrt Filterparameter, zeigt sichere Leeransicht bei unbekannter ID und setzt beim Rueckweg den Fokus auf den zuvor geoeffneten Stellentitel.
- Markierte, im offenen Report nicht mehr vorhandene Jobs bleiben als lokale historische Referenz in Favoriten- und Bewerbungsansicht sichtbar. Sie tragen den Status `Nicht mehr im aktuellen offenen Stellenbestand` und zaehlen nicht als offene Stellen.

### Bereits verifiziert

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit `0`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`.
- `git diff --check` -> Exit `0` vor dem Commit.

### Browser-/Viewport-Blocker

- `tests/Test-JobAgentUiBrowserAudit.ps1` enthaelt neue Assertions fuer Detail- und Kartenmarkierung, getrennte Zustandsfelder, fehlende Navigation, persistente Statusmeldung, Hash-Erhalt und Rueckfokus.
- Drei komplette Browseraudit-Starts erreichten keinen Abschluss und hinterliessen jeweils vom Test gestartete Unterprozesse. Beim dritten Versuch wurde die eigene Prozessstruktur nach rund sieben Minuten beendet; daraus resultiert kein gueltiger Testbefund.
- Der vorhandene Devserver auf Port 8500 war dabei erreichbar: `./ci.cmd devserver-status` meldete Listener-PID `23256`, `managed=False`. Dieser fremde Listener wurde nicht beendet.
- Vor einer erneuten Abnahme den Cleanup-Pfad in `tests/JobAgent.PlaywrightEnvironment.psm1` beziehungsweise die Prozessbeendigung der Playwright-CLI isoliert reproduzieren. Erst danach genau eine Instanz von `Test-JobAgentUiBrowserAudit.ps1` ausfuehren, anschliessend `Test-JobAgentHtmlViewportAudit.ps1`.

### Planungs- und Git-Status

- JA-048 / TD-0076 bleibt offen; die erforderlichen Browser- und Viewportnachweise fehlen. Der Punkt wurde nicht aus `Roadmap.md` rotiert.
- Kein Supertest wurde angefragt; fuer vollstaendig abgenommene Roadmap-Punkte gilt er nach Nutzerregel als erledigt. Diese Regel ersetzt nicht die noch fehlenden spezifischen Browser- und Viewporttests von JA-048.
- TD-0085 bleibt ein separater CI-Driftpunkt. Die Route-Verletzungen stammen unveraendert aus Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/**/jre/legal/**`; nicht loeschen oder umschreiben.
