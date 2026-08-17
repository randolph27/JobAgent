# JobAgent Datenmodell v1

Stand: 2026-08-17

## Speicherentscheidung

Für den ersten fachlichen Stand wird ein versioniertes JSON-Dokument als kanonischer Austausch-, Test- und Persistenzvertrag verwendet. Die fachliche Persistenz liegt unter `data/jobagent/store.json`; Tests verwenden isolierte temporäre Projektwurzeln und schreiben keine produktiven Daten.

Begründung:

- Das Projekt besitzt noch kein separates Runtime-Framework; PowerShell passt zur bestehenden lokalen CI-Umgebung.
- JSON Schema bleibt der stabile Vertrag für Tests, Fixtures, Migrationen und Repository-APIs.
- Atomare Dateiablage unter `data/jobagent/` vermeidet eine frühe Datenbankbindung und ist für idempotente lokale Daily-Runs ausreichend.

## Persistenzschicht

`src/JobAgent.Persistence.psm1` implementiert die lokale Store-Schicht:

- `Read-JobAgentStore` lädt `data/jobagent/store.json` oder liefert ein leeres `jobagent/v1`-Dokument.
- `Write-JobAgentStore` validiert das Dokument und schreibt atomar über temporäre Datei plus best-effort Flush.
- `Invoke-JobAgentStoreTransaction` kapselt Laden, exklusives Locking, Änderung und atomaren Write.
- `Update-JobAgentStoreMigration` migriert bekannte Altversionen auf `jobagent/v1`, erzeugt vorher ein Backup und schreibt `migration.log.jsonl`.
- `Enter-JobAgentStoreLock` und `Exit-JobAgentStoreLock` schützen gegen parallele Daily-Runs über `data/jobagent/store.lock`.

Repository-Funktionen:

- `Upsert-JobAgentCompany`
- `Upsert-JobAgentJobSource`
- `Upsert-JobAgentScanRun`
- `Upsert-JobAgentJobSnapshot`
- `Record-JobAgentScanAttempt`
- `Mark-JobAgentMissingJobs`
- `Get-JobAgentDailyOutputCandidates`

Backups liegen unter `data/jobagent/backups/`. Die Pfadprüfung verhindert absolute oder relative Store-Pfade außerhalb des Projektverzeichnisses.

Recovery:

1. Bei beschädigtem `store.json` schlägt `Read-JobAgentStore` fail-closed fehl.
2. Letztes passendes Backup aus `data/jobagent/backups/` manuell prüfen.
3. Backup nach `data/jobagent/store.json` zurückkopieren.
4. `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` ausführen.

## Root-Dokument

Das Root-Dokument trägt `schema_version: "jobagent/v1"` und enthält getrennte Sammlungen:

- `companies`
- `jobs`
- `job_sources`
- `scan_runs`
- `scan_attempts`
- `job_snapshots`
- `change_events`

Fachliche Daten dürfen nicht mit `todo.*`, `handoff.*` oder CI-Laufzeitdaten vermischt werden.

## Company

Eine Firma beschreibt eine offizielle Rechercheeinheit.

Pflichtfelder:

- `company_id`: stabile ID im Format `company:<wert>`.
- `canonical_name`: kanonischer Anzeigename.
- `canonical_domain`: Hauptdomain ohne Protokoll.
- `official_website_url`: offizielle Website.
- `career_url`: offizielle Karriere-URL; unbekannte Karriere-URLs werden erst nach Persistenzstrategie über einen gesonderten Firmenstatus modelliert, nicht geraten.
- `aliases`: bekannte Namensvarianten.
- `locations`: mindestens ein Standort- oder Zielgebietsobjekt.
- `industry`: Branche oder `UNKNOWN`.
- `ats`: firmengebundene ATS-Domains mit Beleg-URL.
- `scan_status`, `created_at`, `updated_at`, `last_successful_scan_at`.

## JobSource

`JobSource` ist der Beleg, dass eine URL als offizielle Quelle verwendet werden darf.

Zulässige `source_type`-Werte:

- `COMPANY_WEBSITE`
- `CAREER_PAGE`
- `OFFICIAL_ATS`
- `JOB_DETAIL`

`is_official` ist immer `true`. Aggregatoren, Jobbörsen und soziale Netzwerke werden hier nicht gespeichert. Sie können später als Discovery-Hinweis in einem getrennten Modell ergänzt werden, dürfen aber keinen Treffer belegen.

## Job

Eine Stelle ist ein deduplizierter fachlicher Zustand.

Pflichtfelder:

- `job_id`: stabile ID im Format `job:<wert>`.
- `company_id`: Referenz auf `Company`.
- `official_url`: offizielle Detail- oder ATS-URL; ohne dieses Feld ist ein Treffer ungültig.
- `source_id`: Referenz auf den offiziellen Beleg.
- `external_job_id`, `ats_job_id`: offizielle oder ATS-ID, sonst `UNKNOWN`.
- `title`, `location`, `work_model`, `employment_type`.
- `status`: `NEW`, `ACTIVE`, `UPDATED`, `CLOSED`, `REMOVED` oder `INVALID`.
- `first_seen`, `last_seen`, `changed_at`.
- `classification`, `priority`, `requirements`, `salary`, `identity_basis`.

Identitätspriorität:

1. `OFFICIAL_JOB_ID`
2. `ATS_JOB_ID`
3. `CANONICAL_URL`
4. `COMPOSITE_FINGERPRINT`

Eine bekannte unveränderte Stelle darf in späteren Läufen nicht erneut als `NEW` erscheinen.

## ScanRun

`ScanRun` beschreibt einen gesamten Daily-Run oder Testlauf.

Pflichtfelder:

- `scan_run_id`
- `started_at`, `finished_at`
- `status`
- `company_ids`
- `artifact_paths`
- `errors`

Ein einzelner Firmenfehler darf den Gesamtlauf nur dann auf `FAILED` setzen, wenn kein konsistenter Abschluss mit Bericht und Persistenz möglich ist.

## ScanAttempt

`ScanAttempt` beschreibt den isolierten Versuch, eine Quelle einer Firma zu prüfen.

Fehlerklassen:

- `NONE`
- `NOT_REACHABLE`
- `TIMEOUT`
- `BLOCKED`
- `NO_JOBS_FOUND`
- `UNCLEAR_SOURCE`
- `PARSING_ERROR`
- `TECHNICAL_LIMITATION`

Ein fehlgeschlagener Versuch darf bestehende Jobs nicht automatisch schließen oder entfernen.

## JobSnapshot

`JobSnapshot` hält den beobachteten Stand eines Jobs in einem Lauf fest.

Pflichtfelder:

- `snapshot_id`
- `job_id`
- `scan_run_id`
- `source_id`
- `captured_at`
- `content_hash`
- `status`
- `title`
- `location`
- `official_url`
- `summary`

Der `content_hash` dient der Änderungserkennung. Er ersetzt nicht den Quellbeleg.

## ChangeEvent

`ChangeEvent` dokumentiert fachliche Änderungen.

Event-Typen:

- `JOB_CREATED`
- `JOB_UPDATED`
- `JOB_CLOSED`
- `JOB_REMOVED`
- `JOB_INVALIDATED`

Jedes Event enthält alten und neuen Status, geänderte Felder und eine Begründung. Bei neuen Jobs ist `old_status` `null`.

## Beispiel: gültiger Mindestbestand

```json
{
  "schema_version": "jobagent/v1",
  "generated_at": "2026-08-17T10:30:00Z",
  "companies": [
    {
      "company_id": "company:example_ag",
      "canonical_name": "Example AG",
      "canonical_domain": "example.invalid",
      "official_website_url": "https://example.invalid/",
      "career_url": "https://example.invalid/careers",
      "aliases": ["Example"],
      "locations": [
        {
          "label": "Muenchen",
          "city": "Muenchen",
          "region": "Bayern",
          "country": "DE",
          "target_area": "MUNICH"
        }
      ],
      "industry": "UNKNOWN",
      "ats": [],
      "scan_status": "SUCCESS",
      "created_at": "2026-08-17T10:00:00Z",
      "updated_at": "2026-08-17T10:30:00Z",
      "last_successful_scan_at": "2026-08-17T10:30:00Z"
    }
  ],
  "jobs": [
    {
      "job_id": "job:example_ag_head_it_123",
      "company_id": "company:example_ag",
      "official_url": "https://example.invalid/careers/head-it-123",
      "source_id": "source:example_ag_career",
      "external_job_id": "123",
      "ats_job_id": "UNKNOWN",
      "title": "Head of IT",
      "location": {
        "label": "Muenchen",
        "city": "Muenchen",
        "region": "Bayern",
        "country": "DE",
        "target_area": "MUNICH"
      },
      "work_model": "HYBRID",
      "employment_type": "FULL_TIME",
      "status": "NEW",
      "first_seen": "2026-08-17T10:30:00Z",
      "last_seen": "2026-08-17T10:30:00Z",
      "changed_at": "2026-08-17T10:30:00Z",
      "classification": {
        "result": "MATCH",
        "priority": "A",
        "score": 92,
        "reasons": ["IT-Gesamtverantwortung belegt", "Zielgebiet Muenchen"],
        "rejected_reasons": [],
        "evaluated_at": "2026-08-17T10:30:00Z"
      },
      "priority": "A",
      "requirements": ["Fuehrungserfahrung", "IT-Strategie"],
      "salary": "UNKNOWN",
      "identity_basis": "OFFICIAL_JOB_ID"
    }
  ],
  "job_sources": [
    {
      "source_id": "source:example_ag_career",
      "company_id": "company:example_ag",
      "source_type": "CAREER_PAGE",
      "url": "https://example.invalid/careers",
      "canonical_url": "https://example.invalid/careers",
      "is_official": true,
      "verified_at": "2026-08-17T10:30:00Z",
      "verification_basis": "CAREER_URL"
    }
  ],
  "scan_runs": [
    {
      "scan_run_id": "scanrun:20260817T103000Z",
      "started_at": "2026-08-17T10:30:00Z",
      "finished_at": "2026-08-17T10:31:00Z",
      "status": "SUCCESS",
      "company_ids": ["company:example_ag"],
      "artifact_paths": ["logs/jobagent/daily-run-2026-08-17.json"],
      "errors": []
    }
  ],
  "scan_attempts": [
    {
      "scan_attempt_id": "scanattempt:example_ag_20260817T103000Z",
      "scan_run_id": "scanrun:20260817T103000Z",
      "company_id": "company:example_ag",
      "source_id": "source:example_ag_career",
      "started_at": "2026-08-17T10:30:00Z",
      "finished_at": "2026-08-17T10:30:10Z",
      "status": "SUCCESS",
      "adapter": "fixture-html",
      "error_class": "NONE",
      "retry_recommendation": "NONE",
      "http_status": 200
    }
  ],
  "job_snapshots": [
    {
      "snapshot_id": "snapshot:example_ag_head_it_123_20260817",
      "job_id": "job:example_ag_head_it_123",
      "scan_run_id": "scanrun:20260817T103000Z",
      "source_id": "source:example_ag_career",
      "captured_at": "2026-08-17T10:30:10Z",
      "content_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "status": "NEW",
      "title": "Head of IT",
      "location": {
        "label": "Muenchen",
        "city": "Muenchen",
        "region": "Bayern",
        "country": "DE",
        "target_area": "MUNICH"
      },
      "official_url": "https://example.invalid/careers/head-it-123",
      "summary": "IT-Fuehrungsrolle mit offizieller Detailseite."
    }
  ],
  "change_events": [
    {
      "change_event_id": "change:example_ag_head_it_123_created",
      "job_id": "job:example_ag_head_it_123",
      "scan_run_id": "scanrun:20260817T103000Z",
      "event_type": "JOB_CREATED",
      "created_at": "2026-08-17T10:30:10Z",
      "old_status": null,
      "new_status": "NEW",
      "changed_fields": ["status"],
      "reason": "Erstmals ueber offizielle Karriere-URL erkannt."
    }
  ]
}
```

## Negativregeln

- Ein Job ohne `official_url` ist ungültig.
- Ein Job ohne stabile `job_id` ist ungültig.
- Nicht offizielle Quellen dürfen nicht als `JobSource` gespeichert werden.
- Fehlende optionale Werte werden mit `UNKNOWN` modelliert, nicht erfunden.
- Fehlerhafte Scans erzeugen `ScanAttempt`-Fehler, aber keinen automatischen Jobstatus `CLOSED` oder `REMOVED`.
