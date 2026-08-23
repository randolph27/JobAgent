# Handoff latest

Stand: 2026-08-23T12:28:00+02:00

## Ziel fuer neuen Chat

Direkt mit TD-0031 / JA-031 starten. Nutzerproblem: `html/jobagent/company-coverage.html` zeigt Statistiken, aber keine ausreichend sichtbaren anklickbaren Links, die direkt zur Anbieter-, Karriere- oder offiziell belegten ATS-Seite fuehren.

## Aktueller Zustand

- Active: TD-0031
- Status: open
- Branch: master
- HEAD vor diesem Handoff-Commit: aee605819c33
- Upstream: origin/master
- Worktree vor Commit: dirty
- Roadmap: JA-031, JA-032, JA-033 neu angelegt
- Todo: TD-0031, TD-0032, TD-0033 offen
- Devserver: http://localhost:8500 antwortete zuletzt mit HTTP 200
- HTML-Output aus letztem Coverage-Lauf: `html/jobagent/company-coverage.html`

## Neue Roadmap-Reihenfolge

1. JA-031 Anbieter-Link-Vertrag fuer Coverage- und Daily-Reports definieren.
2. JA-032 Coverage-HTML mit anklickbaren Anbieter-, Karriere- und ATS-Links ausgeben.
3. JA-033 Daily-Run-HTML und Detailberichte mit klickbaren offiziellen Stellen- und Anbieterlinks vereinheitlichen.

Die Reihenfolge ist bewusst so gesetzt: erst zentraler Daten-/Sicherheitsvertrag fuer Links, dann sichtbarer Coverage-HTML-Fix fuer das gemeldete Nutzerproblem, danach Vereinheitlichung der Daily-Run-Berichte.

## Wichtig fuer Umsetzung

- Keine Links erfinden.
- Bevorzugte offizielle Linkquellen: `career_url`, `official_website_url`, offizielle `job_sources.canonical_url`, verifizierte ATS-Evidenz.
- Jobboersen-/Discovery-Hints duerfen nur als Review-Hinweise erscheinen, nicht als offizielle Anbieterlinks.
- HTML darf keine externen Skripte oder Stylesheets laden.
- Links brauchen sichere Attribute wie `rel="noopener noreferrer"` bei neuem Tab.
- Lange URLs duerfen Tabellen nicht sprengen; `overflow-wrap:anywhere`, Scrollcontainer und Sticky-Header beibehalten.

## Konkreter Startpunkt TD-0031

Erwartete erste Umsetzung:

1. In `src/JobAgent.Coverage.psm1` zentrale Linkauswahl fuer Firmen/Quellen erstellen.
2. Linkobjekte in Coverage-JSON pro Firma bereitstellen, inklusive Linktyp, Label, URL, Verifikation, Quelle, Clickability und Fail-Closed-Grund.
3. Tests in `tests/Test-JobAgentCoverage.ps1` und bei Report-Bezug in `tests/Test-JobAgentReport.ps1` fuer Karriere-URL, Website-only, ATS, fehlenden Link und unverified Jobboersen-Hint ergaenzen.

## Verifikation fuer naechsten Chat

Funktionstests zuerst:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File tests\Test-JobAgentReport.ps1
```

Nach JA-032:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1
```

Supertest erst nach abgeschlossenen Roadmap-Punkten oder wenn angefragt:

```powershell
.\ci.cmd supertest
```

## Harter Kontext

- Keine Bewerbung, kein Kontaktformular, kein externer Schreibzugriff.
- Keine Massenaufnahme unverifizierter Kandidaten.
- Keine Vollstaendigkeitsbehauptung fuer alle Muenchner/Freisinger Firmen.
- Wenn Supertest nicht explizit angefragt wurde, gilt er fuer reine Roadmap-Erstellung als erledigt/nicht erforderlich.

CAPSULE:{"ts":"2026-08-23T12:28:00+02:00","agent_id":"codex","workspace_root":"D:\\_Scripte\\JobAgent","project":"JobAgent","active_id":"TD-0031","status":"open","goal":"Klickbare Anbieter-, Karriere- und ATS-Links in Coverage- und Daily-Reports planen und umsetzen.","changed":[".ci/pins/immutable.hashes.json",".ci/pins/immutable.snapshot/Roadmap.md","Roadmap.md","handoff.latest.json","handoff.latest.md","html/jobagent/company-coverage.html","todo.checkpoint.json","todo.current.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json","todo.state.json"],"verified":[{"cmd":".\\ci.cmd stp","exit":0,"status":"pass"},{"cmd":".\\ci.cmd todo-seed","exit":0,"status":"pass"}],"route_ok":null,"route_violations":[],"git":{"has_repo":true,"branch":"master","detached":false,"head":"aee605819c33","upstream":"origin/master","remote":"origin","ahead":0,"behind":0,"worktree":"dirty"},"next":"Mit TD-0031 / JA-031 starten: zentralen Anbieter-Link-Vertrag implementieren.","refs":["todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json","Roadmap.md","Roadmap_archive.md"],"manual_missing":false,"env_inventory_missing":false,"env_inventory_used":false,"env_inventory_path":null}
