# Handoff: JA-041 abgeschlossen, UI-001 aktiv

Stand: 2026-09-15

## Aktiver Arbeitsanker

- Todo: `TD-0054` / `UI-001 Berufsneutrale Firmen- und Stellensuche mit vollstaendigen Filtern bereitstellen`.
- Reihenfolge ist bindend: zuerst UI-001.1, dann UI-001.2, dann UI-001.3; `JA-042` erst danach.
- `TD-0056 CI: Resolve drift (observer/route/immutables)` wurde beim STP automatisch aus dem bereits festgestellten Immutable-Drift von `manual/PROGRAM.md` erzeugt. Nicht in UI-001 hineinziehen; Ursache vor einer eigenen CI-Reparatur read-only pruefen.
- Keine laufende Devserver-, Emulator- oder Live-Recherche-Lane erforderlich oder gestartet.

## Abgeschlossener Zustand: JA-041

- Leere Suchbegriffe bedeuten `ALL_ROLES`; explizite Begriffe bedeuten `EXPLICIT_TERMS`. `tools/Invoke-JobAgentDailyRun.ps1` reicht sie in `Invoke-JobAgentDailyRun` durch.
- Jeder neue `ScanRun` persistiert `collection_scope` und bereinigte `search_terms`; das Schema erlaubt beide Felder additiv fuer Legacy-Datensaetze.
- Die Pipeline persistiert gueltige Stellen berufsneutral. `job_validity`, `regional_scope` und `classification`/`priority` sind getrennt: das optionale IT-Fuehrungsprofil ist keine Speichervoraussetzung.
- Der JSON-, Markdown- und HTML-Report enthaelt `capture_manifest` mit Scope, Suchbegriffen, vollstaendigen/teilweisen/fehlgeschlagenen Quellen, uebersprungenen Firmen und `completion_boundary`.
- Mengen bleiben getrennt: `captured_jobs_total`, `profile_matching_jobs_total`, `captured_jobs_this_run`, `profile_matching_jobs_this_run`.
- Der Fixture-Adapter bewahrt `entry_kind` und ein strukturiertes `location`-Objekt, damit explizite Nicht-Stellen und regionale Scope-Faelle den produktiven Vertrag testen.

## Belegte Akzeptanz

- [Akzeptanzartefakt](../../logs/jobagent/JA-041-3-acceptance.json): 16 gueltige Stellen (IT-Leitung, Buchhaltung, Pflege, Ausbildung × München/Freising/Außerhalb/UNKNOWN), 4 Profiltreffer, keine persistierte Navigation.
- Ein Profilwechsel erzeugt keine zusätzlichen `JOB_CREATED`, `JOB_CLOSED` oder `JOB_REMOVED`-Ereignisse.
- Ein Teilscan entfernt keine vorhandenen Stellen und behauptet keine Abwesenheit.
- Erfolgreich: `Test-JobAgentLiveScan`, `Test-JobAgentDailyRun`, `Test-JobAgentReport`, `Test-JobAgentSourceAdapters`, `Test-JobAgentSchema` sowie `git diff --check`.
- Der Schema-Test benötigte Zugriff auf den bestehenden npm-Cache außerhalb der Sandbox; der Sandbox-Lauf scheitert dort mit `EPERM`.
- `supertest` war nicht angefragt und ist als erledigt behandelt. Browser-/Device-Lane war für JA-041 nicht anwendbar, da kein Layout geändert wurde.

## Nächster Slice: UI-001.1

1. Bestehende Coverage- und Daily-Report-Artefakte in einen gemeinsamen Einstieg auf Port `8500` bringen, ohne eine neue Frontendplattform einzuführen.
2. Firmen und Stellen getrennt, aber aus demselben vollständigen Bestand sichtbar machen; Firmen ohne offene Stellen behalten.
3. Gesamtbestand, Filtermenge und sichtbare Seite getrennt zählen; Pagination darf keine 250er-Grenze haben.
4. Zuerst Ist-Ansicht gegen die in `Roadmap.md` verlinkten UI-001-Screens prüfen. Erst bei sichtbarer Änderung Browser-Abnahme mit 390/800/1366/1920 px starten; Devserver ausschließlich über `.ci.cmd devserver-start` im Hintergrund.
5. Für UI-001.1 gezielt `Test-JobAgentReport.ps1` und `Test-JobAgentCoverage.ps1` erweitern und ausführen. Supertest erst am kompletten UI-001-Abschluss; falls nicht angefragt, als erledigt dokumentieren.

## Grenzen

- Keine reale Firmenmindestmenge, Bewerbungen, Gebietsaufweitung, Captcha-/Login-Umgehung oder Storemutation durch UI-Filter.
- Stellenort bleibt maßgeblich; `UNKNOWN`, `OUT_OF_SCOPE` und Quellenfehler dürfen nicht als fehlende Stelle oder vollständiger Scan erscheinen.
- Den vorhandenen Dirty-Worktree nicht verwerfen: Der nächste Commit bündelt die abgeschlossene JA-041-Implementierung, Roadmap-Archivierung und Todo-/Handoff-Synchronisierung.
