# Handoff latest

Stand: 2026-09-18T11:26:00.434+02:00

## Zustand

- Active: `TD-0080`
- Status: `in-progress`
- Ziel: M2 – Stellenboersen-Oberflaeche: JA-052 Bewerbungsuebersicht mit Status, Notizen und Wiedervorlagen erweitern #comment: Persoenliche Bewerbungsarbeit braucht einen konsistenten Verlauf und Fristen, waehrend Bewerbungsstern und Detailstatus dieselbe Wahrheit darstellen.
- Branch: `master`
- HEAD: `bfe8cd0a539d`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `docs/reviews/JA-052-work-status.md`
- `handoff.latest.md`
- `src/JobAgent.Report.psm1`
- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

Isolierten Browserprofiltest fuer Statuswechsel, Notiz- und Termin-CRUD erweitern; danach Bewerbungsuebersicht um Stufen-/Faelligkeitsfilter und Sortierung abnehmen.

## Detaillierter Arbeitsstand fuer den Folgeagenten

### Aktiver Roadmap-Punkt: JA-052 / TD-0080

- Die browserlokale V2-Persistenz in `html/jobagent/assets/jobboard-state.js` ist vorhanden und durch `tests/Test-JobAgentUserState.ps1` abgedeckt: V1-Migration mit erhaltener Sicherung, Statusprojektion, Korrekturhistorie, Textgrenzen, Termin-CRUD, Offsetpflicht, Loeschmarker, Quota-Atomaritaet sowie Export/Import.
- `src/JobAgent.Report.psm1` erzeugt nun in Stellenliste und Stellendetail einen lokalen Bearbeitungsbereich fuer Status, Notiz, naechste Aktion und Termin-CRUD. Die Formulare schreiben ausschliesslich in `localStorage`; sie erzeugen keine Netzwerkanfragen und veraendern keinen Reportstore.
- Ein regulaerer Statuswechsel nutzt den State-Vertrag direkt. Nicht regulaere Wechsel zeigen vor dem Speichern eine Bestaetigung und schreiben die vorhandene Korrekturhistorie. Das Zuruecksetzen eines fortgeschrittenen Status per Bewerbungsmarkierung verlangt ebenfalls eine Bestaetigung; Notiz, Termine und Chronik bleiben erhalten.
- Die Bewerbungsregisterkarte zeigt bisher nur die vorhandene Anzeige. Es fehlen noch Stufen- und Faelligkeitsfilter, Sortierung nach offenem Termin und danach Job-/Task-ID sowie lokale Notizsuche.
- `Test-JobAgentUiBrowserAudit.ps1` wurde nach der UI-Aenderung angestossen, lieferte innerhalb des Tool-Zeitlimits jedoch keinen Abschlussnachweis. Dieser Lauf ist nicht als gruen zu behandeln. Zuerst isolierte V2-Browserfaelle in diesem Test ergänzen: erlaubter und korrigierter Stufenwechsel, beide Sternrichtungen, Notiz 4000/4001, Termin anlegen/erledigen/loeschen, Offsetfehler, Quota, Speicherfehler ohne Datenverlust, Reload und kein Bediennetzwerk.
- Danach die Bewerbungsansicht vervollstaendigen, gezielt `Test-JobAgentUiBrowserAudit.ps1`, `Test-JobAgentUserState.ps1` und `Test-JobAgentReport.ps1` ausfuehren, Evidence unter `docs/reviews/JA-052-acceptance.md` und `logs/jobagent/JA-052/application-cases.json` erzeugen und erst dann JA-052 rotieren.

### Reihenfolge danach

1. JA-053 / TD-0081: fachliche Stellenchronik auf vorhandenen Snapshots und Change-Events.
2. JA-055 / TD-0082: reversible lokale Ausblendung auf dem gemeinsamen V2-Store.
3. JA-049 / TD-0077: atomare stabile HTML-Publikation.
4. JA-054 / TD-0083: Kalender auf Zeitprojektion und persoenlichen Terminen.
5. JA-056 / TD-0084: gespeicherte Suchen mit generationengebundener Sichtung.
6. JA-050 / TD-0078: integrierte Gesamtabnahme.

`TD-0085` bleibt ein separater CI-Driftpunkt. Der letzte STP-Nachweis meldet bekannte Route-Verstoesse ausschliesslich in gebuendelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...`; diese Dateien nicht ohne gezielte CI-Driftanalyse aendern.
