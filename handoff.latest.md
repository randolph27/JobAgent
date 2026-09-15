# Handoff latest

Stand: 2026-09-15T17:17:19.461+02:00

## Zustand

- Active: `TD-0055`
- Status: `in-progress`
- Ziel: JA-042 Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.
- Branch: `master`
- HEAD: `819f0b9f00eb`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `.ci/bin/modules/ci-commands-main.ps1`
- `Roadmap.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.Operations.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentOperations.ps1`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Invoke-JobAgentDailyRun.ps1`

## Verifikation

- `.\ci.cmd sonar` -> Exit ``

## Naechster Anker

JA-042.2: Resume, Retry-After und Dublettenfreiheit ueber Abbruch, Storecommit und Reportpublikation nachweisen.

## Fachlicher Uebergabestand: JA-042.1

- `JA-042.1` ist in [Roadmap.md](Roadmap.md) abgehakt; der Hauptpunkt `JA-042` und `TD-0055` bleiben aktiv. Nicht rotieren: JA-042.2 und JA-042.3 sind noch offen.
- Der regulaere Einstieg bleibt `tools/Invoke-JobAgentDailyRun.ps1`. `Invoke-JobAgentManagedDailyRun` erzeugt jetzt eine gemeinsame `dailyrun:<UTC-Stempel>`-ID und uebergibt sie an den Orchestrator; die bestehende `scanrun:<UTC-Stempel>`-ID bleibt fuer den Scan erhalten.
- Akquise und Scan behalten getrennte Budgets (`AcquisitionCandidateBudget`, `MaxCompanies`). Ein Fehler in Refill, Website-Ermittlung oder Kandidatenverifikation wird als `PARTIAL` mit Grund protokolliert und verhindert den anschliessenden Scan bekannter Firmen nicht. Ein Storefehler bleibt fail-closed, weil die Reportpublikation erst nach erfolgreichem Store-Commit erfolgt.
- `logs/jobagent/daily-run.status.json` ist der atomar geschriebene Publikations-Pointer. Er liefert `display_state` mit `laeuft`, `abgeschlossen`, `teilweise` oder `fehlgeschlagen`; bei Neuberechnung und Fehler bleiben die zuletzt publizierten Reportpfade sichtbar und werden als `is_stale` markiert.
- Die STP-Auswahl bevorzugt nun `next_action` des aktiven Todos. Dadurch verweist der Handoff trotz des nachrangigen offenen Drift-Todos `TD-0056` korrekt auf JA-042.2.

## Nachweise und Verifikation

- Lokale, ignorierte Evidence: `logs/jobagent/JA-042-1-acceptance.json`; enthält Gitstand, IDs, Budgets, erwartete/erhaltene Zähler sowie positive und negative Fälle.
- `pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1` -> Exit 0. Deckt Run-ID, lesbare Statuswerte, Lock, Logrotation und die Stale-Erhaltung des letzten publizierten Reports ab.
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0. Deckt Akquise plus Scan im selben Lauf sowie einen isolierten Akquisefehler (`missing-fixture-map.json` -> `PARTIAL`, vorhandene Stelle bleibt erhalten) ab.
- Isolierter leerer Store: `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot <temp> -DisableAcquisition -MaxCompanies 1` -> Exit 0, `run_id=dailyrun:20260915T151019142Z`, `scan_run_id=scanrun:20260915T151019142Z`.
- Kein Browseraudit: Es wurde keine HTML-Ansicht geaendert. Kein Supertest: JA-042 ist noch nicht vollstaendig; gemaess Nutzeranweisung ist kein zusaetzlicher Supertest fuer diesen Teilabschluss erforderlich.

## Naechster Arbeitsschnitt: JA-042.2

1. In `src/JobAgent.Persistence.psm1`, `src/JobAgent.StatusMachine.psm1` und `src/JobAgent.Operations.psm1` gezielt Abbruchpunkte vor/nach Resultatsicherung, Store-Commit und Reportpublikation als isolierte Fixtures abbilden.
2. Resume muss Cursor, bereits persistierte Resultate und Retry-After wiederverwenden. Keine erneute Neufirmenzaehlung bei gleicher Evidence; `wake_at` ausgeben und nicht warten.
3. Vollstaendige, eingeschraenkte und partielle Quellabdeckung fuer Stellenstatus pruefen. Nur vollstaendige relevante Abdeckung darf Abwesenheit belegen; lokale Webfilter duerfen persistierte aktive Stellen nicht veraendern.
4. Fuer JA-042.2 die fokussierten Tests aus der Roadmap ausfuehren und `logs/jobagent/JA-042-2-acceptance.json` erzeugen. Roadmap, Todo, Handoff und STP erst nach vollstaendigem Nachweis synchronisieren.

## Nebenbedingung

- `TD-0056` bleibt nachrangig offen: `manual/PROGRAM.md` meldet Immutable-Drift. Nicht blind zuruecksetzen; zuerst erwarteten Hash und Herkunft pruefen. Der Befund blockiert JA-042 nicht.
