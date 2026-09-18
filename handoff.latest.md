# Handoff latest

Stand: 2026-09-18T12:25:02.919+02:00

## Zustand

- Active: `TD-0081`
- Status: `open`
- Ziel: M2 – Stellenboersen-Oberflaeche: JA-053 Fachliche Aenderungen einer Stelle als belegte Chronik anzeigen #comment: Eine erneute Erfassung ist keine neue Stelle und eine technische Quellenstoerung kein belegtes Ende einer Ausschreibung.
- Branch: `master`
- HEAD: `7e383feb5f0e`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

TD-0081 / JA-053: Snapshot-/Change-Event-Felder und feste Vorher/Nachher-Fixtures pruefen; danach die fachliche Chronikprojektion implementieren. JA-055 folgt erst nach JA-053.

## Uebergabe fuer den naechsten Chat

- JA-052 ist vollstaendig nach `Roadmap_archive.md` rotiert. Die Evidence liegt unter `docs/reviews/JA-052-acceptance.md`, `logs/jobagent/JA-052/application-cases.json` und den zwei JA-052-Screenshots.
- Der neue fokussierte Browsermodus `pwsh -NoProfile -File ./tests/Test-JobAgentUiBrowserAudit.ps1 -ApplicationOverviewOnly` endet mit Exit 0. Er prueft APPLIED -> INTERVIEW, Notizsuche, Stufen-/Faelligkeitsfilter, Sortierung, offenen Offset-Termin, 0 Bediennetzwerk und 390/800/1366/1920 ohne Ueberlauf, Overlap oder Clipping.
- `Test-JobAgentUserState.ps1` und `Test-JobAgentReport.ps1` endeten ebenfalls mit Exit 0. Der Vollsupertest wurde nicht angefragt und gilt gemaess Nutzerregel als erledigt.
- Aktiver Punkt ist TD-0081 / JA-053. Keine Produktivdaten, Live-Crawls oder privaten Browserdaten verwenden. Chronik nur aus vorhandenen Snapshots und Change-Events ableiten; technische Quellenfehler duerfen nie ein Stellenende behaupten.
- Bekannter unabhängiger CI-Drift bleibt TD-0085: Route-Verstoesse liegen ausschliesslich in gepinnten Sonar-JRE-Lizenzdateien. Ohne eigene Driftentscheidung nicht aendern.
