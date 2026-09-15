# Handoff latest

Stand: 2026-09-15T19:41:21.063+02:00

## Uebergabestatus

- Branch: `master`, Upstream: `origin/master`. Der STP-Lauf endete mit Exit `0`.
- Kein aktiver Todo-Eintrag. Der Arbeitsbaum enthaelt ausschliesslich diesen QA-002-Schnitt sowie synchronisierte Todo-/Handoff-Artefakte und wird nach diesem Handoff committed und gepusht.
- QA-001 ist archiviert. QA-002 bleibt offen, weil nur QA-002.1 und QA-002.2 abgeschlossen sind; QA-002.3 fehlt. QA-003 bis QA-006 sowie `TD-0056` bleiben offen. Es wurde kein weiterer Roadmap-Punkt rotiert.
- Der Supertest wurde nicht ausgefuehrt. Nach Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt; dies ist kein behaupteter gruener Lauf.

## Abgeschlossene Arbeit in QA-002

- QA-002.1: `JobAgent.Persistence` prueft und bereinigt atomare Schreibunterbrechungen vor Tempdatei, vor Austausch und nach Backup. Tests decken Store-/Backup-Hashes, unbekannte Migrationen, korrupte Stores, Parallel-/Stale-Locks, wiederholte Freigabe sowie absolute und `..`-Traversalpfade in isolierten Temp-Wurzeln ab.
- QA-002.2: Tests decken offizielle Job-ID, firmengebundene ATS-ID, kanonische und alternative URL, Trackingparameter, Titel-/URL-Update, gleiche ATS-ID unterschiedlicher Firmen, unsichere Neuausschreibung, `NEW -> ACTIVE -> UPDATED -> CLOSED`, `REMOVED` und Wiederauftauchen ab. Fehlgeschlagene oder unvollstaendige Quellen aktualisieren `last_seen` nicht und entfernen keine Stellen.
- Die Klassifikationsmatrix prueft IT-Leitung, Pflege, Buchhaltung und Ausbildung in Muenchen, Freising, ausserhalb und `UNKNOWN`. Es gibt keine Distanzfunktion und keinen konfigurierbaren Profilwechsel im aktuellen Scope; beides wird nicht als getestet behauptet.
- `New-JobAgentDailyReport` leitet `generated_at` nun aus dem festen Scanabschluss statt aus der aktuellen Uhr ab. Reporttests pruefen deterministisches Rendering, HTML-Escaping und die Ablehnung von `javascript:`-Links.
- `Test-JobAgentCoverage.ps1` trennt den fokussierten Core-Vertrag von der optionalen, produktnahe Artefakte schreibenden Tool-Integration (`-IncludeToolIntegration`).

## Nachweise

- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentPersistence.ps1`
- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1` (ausserhalb der Sandbox wegen lokalem npm-Cache)
- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentClassification.ps1`
- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentDeduplication.ps1`
- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1`
- Exit `0`: `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`
- Exit `0`: STP-validierter `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`; Nachweis `logs/verify/verify-20260915-183432.log`.
- Nicht als gruen behauptet: `Test-JobAgentCoverage.ps1`. Der frühere kombinierte Lauf startete produktnahe Tool-Integration und wurde nach anhaltender CPU-Last kontrolliert beendet. Den neuen fokussierten Core-Lauf zuerst einzeln ausführen; Tool-Integration nur ausdrücklich mit `-IncludeToolIntegration` und mit isolierten Pfaden weiter analysieren.

## Naechster konkreter Auftrag

QA-002.3 abschliessen. Eine einzige feste, isolierte Storegeneration erzeugen und JSON, Markdown, Daily-HTML und Coverage gegen explizite Soll-IDs, Mengen, Capture-Manifest, Teilquellen, A/B/C-Begründungen, `UNKNOWN`, lange Unicodewerte, HTML-/Scriptfragmente und unzulässige URL-Schemata vergleichen. Danach zwei normalisierte, fachlich identische Läufe vergleichen. Den fokussierten `Test-JobAgentCoverage.ps1`-Core mit Exit `0` belegen; bei Fehlern nur den betroffenen Coverage-Fall reparieren. Erst nach allen acht QA-002-Funktionstests mit Exit `0` darf QA-002 rotiert werden.

Danach QA-003.1 beginnen. Keine Live-Webrecherche, keine produktiven Stores und keine fremden Prozesse verändern. Devserver ausschliesslich über `.\ci.cmd devserver-status` und bei Bedarf `.\ci.cmd devserver-start` auf Port 8500 verwalten. `TD-0056` nur fachlich analysieren; `manual/PROGRAM.md` nicht durch Pin-/Snapshot-/Immutable-Manipulation kosmetisch bereinigen.
