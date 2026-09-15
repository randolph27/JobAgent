# Handoff latest

Stand: 2026-09-15T19:15:59.433+02:00

## Uebergabestatus

- Branch: `master`, Upstream: `origin/master`; STP dieses Abschlusses lief mit Exit `0`.
- Kein aktiver Todo-Eintrag. QA-001 ist abgeschlossen und in `Roadmap_archive.md` rotiert. QA-002 bis QA-006 bleiben aktiv; `TD-0056` (CI-Drift) bleibt ebenfalls offen.
- Dieser Arbeitsbaum besteht ausschliesslich aus STP- und Handoff-Aenderungen und wird nach diesem Handoff gestaged, committed und gepusht.
- Verifiziert: `pwsh -NoProfile -File .\\tests\\Test-JobAgentCiContracts.ps1` mit Exit `0`; Nachweis: `logs/verify/verify-20260915-183432.log`.
- Nicht ausgefuehrt: Produkt-, Browser- und Supertest. Der Supertest war nicht angefragt und gilt nach Nutzeranweisung fuer diesen Abschluss als erledigt. Das ist kein behaupteter gruener oder ausgefuehrter Supertest-Lauf.

## Abgeschlossener Schnitt

QA-001 lieferte das Funktionsinventar und die verbindliche Testmatrix:

- `docs/test-matrix.json` und `docs/test-matrix.md`: 28 vorhandene JobAgent-Testdateien, 21 aktuelle Aggregator-Eintraege, Testfallzuordnung und Vertragsfelder.
- `tests/Test-JobAgentTestMatrix.ps1`: Matrixstruktur, eindeutige IDs, Referenzen und Pflichtmetadaten.
- `html/jobagent/ui-001-browser-audit.html`: lokaler UI-Audit-Beleg.
- `docs/reviews/2026-09-15-supertest-roadmap-plan.json`: Quellhashes, Inventar, bekannte Grenzen und Validierung. Sieben Tests werden nicht direkt vom Aggregator gestartet; daraus folgt keine Aussage ueber indirekte Abdeckung. Der Aggregator `tests/Test-JobAgentSupertest.ps1` darf sich niemals selbst starten.
- `Roadmap_archive.md` und `Roadmap_index.md` enthalten QA-001; `Roadmap.md` enthaelt nur die offenen Nachfolger.

## Naechster konkreter Auftrag

Mit QA-002.1 anfangen. In isolierten Temp-Wurzeln die Schema- und atomaren Persistenzgrenzen pruefen: Pflichtfelder, Typen, Enums, Legacy-/Migrationsfaelle, Abbruch vor Tempdatei/Austausch/Backup, Lock-/Stale-Lock-/Traversalfaelle sowie Store-/Backuphashes vor und nach Wiederanlauf.

Danach erst QA-002.2 (Identitaetsprioritaeten, Gebietskanten, `NEW -> ACTIVE -> UPDATED -> CLOSED`, `REMOVED` und Wiederauftauchen) und QA-002.3 (JSON, Markdown, Daily-HTML und Coverage aus derselben festen Storegeneration; Escape, Links und Determinismus).

Zum QA-002-Abschluss sind diese fokussierten Tests erforderlich: `Test-JobAgentSchema.ps1`, `Persistence`, `CompanyInventory`, `Classification`, `Deduplication`, `StatusMachine`, `Report` und `Coverage`; bei HTML-Aenderung zusaetzlich `HtmlAudit`. Fehler immer im betroffenen Einzeltest lokalisieren. Die Supertest-Zeile der Roadmap ist fuer diesen Uebergabeauftrag nicht als auszufuehrender Nachweis zu behandeln; fehlende Fachtests bleiben offen.

## Reihenfolge und Grenzen

- QA-002 (97): Daten-, Identitaets-, Status- und Berichtsvertraege; Voraussetzung fuer alle weiteren Orakel.
- QA-003 (95): Discovery, Quellenverifikation, Resume und CLI auf Basis von QA-002.
- QA-004 (91): UI-Control- und Ergebniszustandsmatrix nach QA-002/QA-003.
- QA-005 (87): Geometrie, Tastatur und Sichtung bei 390/800/1366/1920 px nach QA-004.
- QA-006 (84): Aggregator- und Vollstaendigkeitsvertrag zuletzt.
- Keine Live-Webrecherche, keine produktiven Storemutationen und keine fremden Prozesse beenden. Jeder Testlauf bekommt einen containment-geprueften Root.
- `TD-0056`: Der letzte `self-check` scheiterte am vorhandenen Immutable-Drift `manual/PROGRAM.md`. Nicht durch Pin-, Snapshot- oder Immutable-Aenderungen kosmetisch beheben.
- Sonar ist fuer das PowerShell-/HTML-Produkt `not-supported`; Port 9000 ist kein Analysebeleg. Devserver nur ueber `.\\ci.cmd devserver-status` und bei Bedarf `.\\ci.cmd devserver-start` auf Port 8500 verwalten.
- Roadmappunkte erst nach allen drei Unterpunkten, fokussierten Tests und Nachweisen rotieren. QA-002 bis QA-006 sind nicht rotationsfaehig.
