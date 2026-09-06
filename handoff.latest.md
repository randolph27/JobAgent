# Handoff latest

Stand: 2026-09-06T17:56:11.051+02:00. STP wurde ausgefuehrt. Fuer neuen Chat/Agent: zuerst `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md` lesen. Projektwurzel ist `D:\_Scripte\JobAgent`.

## Aktiver Status

- Active: `TD-0041` / `JA-027`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD beim STP: `d5102dd06eef`
- Upstream: `origin/master`
- Ahead/Behind beim STP: `0/0`
- Worktree beim STP: `dirty`
- Roadmap-Rotation: nicht ausgefuehrt, weil kein Top-Level-Punkt komplett erledigt ist.

## Erledigter Stand

JA-027.1 ist als Retention-Schnitt umgesetzt und gepusht. JA-027.2 hat jetzt eine reproduzierbare Quelleninventur mit Evidence, aber noch keinen schreibenden Quellenrefresh und keine produktive Nachfuehrung neuer Quellen.

JA-027.2 aktueller Evidence-Stand:
- `tools/Measure-JobAgentDiscoverySourceInventory.ps1` erzeugt die drei Pflichtartefakte fuer Quelleninventur, Quellenrecherche und Kandidatenabgleich.
- 32 Registry-Quellen, 26 Snapshot-Manifesteintraege, 1.790 Hints, 1.785 Queueeintraege.
- Retention-Store: 2.269 Discovery-Funde und 1.401 URL-Funde.
- Fuenf Hints ohne Queueeintrag sind einzeln erklaert: Fraunhofer IVV, Texas Instruments Deutschland GmbH, QuEST Global Engineering Services GmbH, Deutsches Theater Muenchen, Stadtwerke Muenchen GmbH.
- Queue-ohne-Hint: 0.
- Sieben neue Quellenansaetze dokumentiert: HWK Muenchen/Oberbayern, Munich Startup Directory, IZB-Start-ups, BioM-Firmendatenbank, Landkreis-Muenchen-Gruenderzentren, Stadt Freising Wirtschaft, IHK-Standortportal Bayern. Diese Ansaetze sind nur Kandidatenquellen, keine offiziellen Karrierequellen.
- Supertest-Matrix ist synchronisiert; `Test-JobAgentDiscoverySourceInventory.ps1` ist im Supertest registriert. Supertest wurde nicht ausgefuehrt, weil JA-027 noch nicht komplett abgeschlossen ist. Nach Nutzeranweisung gilt er fuer diesen Handoff als freigestellt, nicht als bestandener Lauf.

Evidence:
- `logs/jobagent/JA-027-retention-migration.json`
- `logs/jobagent/JA-027-retention-regression.json`
- `logs/jobagent/JA-027-source-inventory.json`
- `logs/jobagent/JA-027-source-research.json`
- `logs/jobagent/JA-027-candidate-reconciliation.json`

## Verifikation

Ausgefuehrt und gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1
cmd /c .\ci.cmd self-check
git -c core.pager=cat -c color.ui=false --no-pager diff --check
cmd /c .\ci.cmd stp
```

Nicht erfolgreich:

```powershell
cmd /c .\ci.cmd sonar-start
```

Grund: lokaler Wrapper `D:\_Scripte\JobAgent\sonar.cmd` fehlt. SonarQube auf `localhost:9000` antwortete vorher nicht innerhalb von 5 Sekunden.

## Offene Arbeit fuer den naechsten Chat

Naechster Hotspot ist weiter JA-027.2: schreibende Quellenerschliessung/Nachfuehrung auf Basis der Inventur. Nicht zu JA-041 springen; `TD-0041` bleibt aktiv.

Konkrete naechste Schritte:
1. Die sieben Research-Kandidaten aus `logs/jobagent/JA-027-source-research.json` nach Source-Contract bewerten: registrieren, Snapshot-Lane definieren oder begruendet blockieren.
2. Fuer zulaessige Quellen Snapshot-/Parser-Erweiterungen bauen und Tests ergaenzen; keine Kontakte, Personenrollen oder Anzeigenvolltexte persistieren.
3. Die fuenf Hints ohne Queueeintrag durch Queue-Neuaufbau oder dokumentierte Filterentscheidung schließen.
4. Danach schreibenden Snapshot-Refresh laufen lassen und Retention-/Queue-Zahlen erneut mit `tools/Measure-JobAgentDiscoverySourceInventory.ps1` belegen.
5. Erst danach JA-027.3 starten: offizielle Firmen-/Karriereverifikation und 100er Benchmark.

## Grenzen

- Keine erfundenen Firmen, URLs, Stellen oder Vollstaendigkeitsnachweise.
- Jobboersen/Register/OSM/Communitylisten liefern nur Hinweise, keine offiziellen Karrierequellen.
- Unverifizierte Hints bleiben Retention-Kandidaten, keine produktiven Companies/JobSources.
- Keine Bewerbungen, Nachrichten, Login-/Captcha-/Paywall-Umgehung oder kostenpflichtigen Zugaenge.
- Devserver/Sonar nur ueber `.\ci.cmd`, Server im Hintergrund.
