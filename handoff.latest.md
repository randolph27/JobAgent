# Handoff latest

Stand: 2026-08-17T18:05:25.093+02:00

## Zustand

- Active: `TD-0018`
- Status: `in-progress`
- Ziel: `JA-022 Lokale App-/Artefaktablage, Devserver-Port und Visual-Audit fuer HTML-Berichte absichern`
- Branch: `master`
- HEAD: `8ea93abe6645`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`

## Abgeschlossener Arbeitsschritt

- `JA-021` ist fachlich abgeschlossen und aus [Roadmap.md](D:/_Scripte/JobAgent/Roadmap.md) nach [Roadmap_archive.md](D:/_Scripte/JobAgent/Roadmap_archive.md) rotiert.
- [src/JobAgent.CompanyInventory.psm1](D:/_Scripte/JobAgent/src/JobAgent.CompanyInventory.psm1) unterstuetzt jetzt Discovery-Importe mit `OFFICIAL_WEBSITE`, `MANUAL_REVIEW` und `DISCOVERY_HINT`, inklusive sauberem `verification_status` und `verification_url`.
- [tools/Import-JobAgentCompanyDiscovery.ps1](D:/_Scripte/JobAgent/tools/Import-JobAgentCompanyDiscovery.ps1) importiert Discovery-Feeds transaktional in den Store, erzeugt Backups und schreibt ein Import-Log.
- [data/jobagent/company-discovery.official.json](D:/_Scripte/JobAgent/data/jobagent/company-discovery.official.json) enthaelt einen offiziellen Feed fuer acht neue Arbeitgeber im Zielgebiet oder mit anschliessend pruefbarem Zielgebietsbezug.
- [data/jobagent/store.json](D:/_Scripte/JobAgent/data/jobagent/store.json) wurde erfolgreich erweitert. Der Store enthaelt jetzt 20 Firmen und 20 offizielle Quellen.
- [tests/Test-JobAgentCompanyInventory.ps1](D:/_Scripte/JobAgent/tests/Test-JobAgentCompanyInventory.ps1) deckt jetzt auch Discovery-Hinweise, `COMPANY_DOMAIN_VERIFIED` ohne Karrierepfad und den CLI-Importpfad ab.

## Neu importierte Firmen

- `Microsoft Deutschland GmbH`
- `Google Germany GmbH`
- `MAN Truck & Bus SE`
- `Knorr-Bremse AG`
- `BWI GmbH`
- `Bayerische Landesbank`
- `Versicherungskammer Bayern`
- `msg systems ag`

## Wichtige Artefakte

- Discovery-Feed: [data/jobagent/company-discovery.official.json](D:/_Scripte/JobAgent/data/jobagent/company-discovery.official.json)
- Produktiver Store: [data/jobagent/store.json](D:/_Scripte/JobAgent/data/jobagent/store.json)
- Import-Log: [logs/jobagent/company-discovery-import-20260817-160219.json](D:/_Scripte/JobAgent/logs/jobagent/company-discovery-import-20260817-160219.json)
- Todo-Status: [todo.current.md](D:/_Scripte/JobAgent/todo.current.md), [todo.state.json](D:/_Scripte/JobAgent/todo.state.json), [todo.events.jsonl](D:/_Scripte/JobAgent/todo.events.jsonl)

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tools\Import-JobAgentCompanyDiscovery.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` gilt gemaess Nutzerregel als erledigt und ist im Verify-Digest weiterhin gruen

## Offene Aufgabe fuer den naechsten Chat

`JA-022` ist jetzt der einzige aktive Roadmap-Punkt.

1. Devserver-Portvertrag klaeren und implementieren.
   Dateien/Kontext: `.ci/ci.config.json`, `.ci/bin/modules/*`, README/Manual-Hinweise.
   Aktueller Konflikt: Nutzer nennt Port `8500`, Konfiguration verweist noch auf `8300`.
   Ziel: `.\ci.cmd devserver-start/status/stop` im Hintergrund, reproduzierbar und ohne Fremdprozesse zu beenden.
2. Lokalen HTML-Audit fuer `html/jobagent/*.html` bauen.
   Erwartung: Pflichtsektionen vorhanden, keine externen Ressourcen, keine abgeschnittenen oder ueberlaufenden Inhalte bei langen Texten.
   Wahrscheinliche Ziele: neuer Funktionstest neben [tests/Test-JobAgentOperations.ps1](D:/_Scripte/JobAgent/tests/Test-JobAgentOperations.ps1) oder eigener HTML-Audit-Test.
3. Betriebsstatus und Reportpfade absichern.
   Erwartung: letzter JSON-, Markdown- und HTML-Reportpfad ist fuer den Nutzer ohne weitere Serverinteraktion auffindbar.
   Relevante Module: `src/JobAgent.Operations.psm1`, Daily-Run-/Report-Artefakte, Handoff-Ausgabe.

## Risiken und No-Gos

- Keine Jobboerse oder Branchenliste als Primaerquelle in produktive Discovery-Feeds aufnehmen.
- `DISCOVERY_HINT` darf nie automatisch in eine offizielle Quelle hochgestuft werden.
- Fuer `JA-022` keine blockierenden Vordergrund-Server starten; Devserver nur ueber `.\ci.cmd`.
- Keine fremden Prozesse auf `8500` oder `8300` ohne Identitaetspruefung beenden.
