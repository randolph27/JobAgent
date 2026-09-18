# Handoff latest

Stand: 2026-09-18T09:34:00+02:00

## Zustand

- Branch: `master`; vor Commit/Persistierung keine fremden Aenderungen im Worktree.
- Aktiver Roadmap-Anker: `TD-0076` / `JA-048`; nicht rotieren, da die Browser- und Viewport-Abnahme noch fehlt.
- `TD-0085` bleibt offen: Route-Drift stammt ausschliesslich aus bestehenden Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/**/jre/legal/**`; nicht loeschen oder umschreiben.
- Kein Supertest offen: Der Nutzer hat ihn nicht angefragt; für vollständige Roadmap-Punkte gilt er als erledigt. JA-048 ist dennoch nicht vollständig abgenommen.

## Implementierte, commitbereite Änderungen

- `tests/JobAgent.PlaywrightEnvironment.psm1`: isolierte CLI-Prozesse, 120-Sekunden-Timeout, Leerlauf-Timeout, Sitzungs-/Daemon-Cleanup.
- `src/JobAgent.Report.psm1`: kanonischer unbekannter Detail-Hash und verstärkter Rückfokus.
- `tests/Test-JobAgentUiBrowserAudit.ps1`: Fokusdiagnose mit aktivem Element, Tag und ID.

## Verifiziert

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentPlaywrightTooling.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentPlaywrightCliRuntime.ps1
.\ci.cmd stp
```

Alle Befehle endeten mit Exit 0.

## Offener, reproduzierbarer Fokusfall

`pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` scheiterte vor dem letzten Rückfokus-Fix wiederholt im Fall `Rueckfokus aus Detailansicht`:

```text
Detailansicht: Der Fokus kehrt nicht zum zuvor geoeffneten Stellentitel zurück
(erhalten: '', tag: 'INPUT', id: 'jobagent-query').
```

Der Hash ist dabei bereits `#view=jobs`; Ergebnisliste und Markierungen sind vorhanden. Der letzte direkte, doppelte `requestAnimationFrame`-Rückfokus in `detailCard` ist noch nicht im vollständigen Browseraudit nachgetestet.

## Nächste Schritte

1. Einen vollständigen Lauf von `Test-JobAgentUiBrowserAudit.ps1` starten; keinen parallelen Browserlauf.
2. Bei Fehler den Fokuszeitpunkt im konkreten Fall isolieren, korrigieren und denselben Audit wiederholen.
3. Bei grünem Browseraudit `Test-JobAgentHtmlViewportAudit.ps1` ausführen.
4. Erst mit allen drei grün belegten JA-048-Funktionstests Evidence aktualisieren und JA-048/TD-0076 rotieren.
