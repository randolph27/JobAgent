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

## Firmeninventar-Seed

`src/JobAgent.CompanyInventory.psm1` ergaenzt die fachliche Firmeninventar-Schicht fuer `JA-004`.

- `Get-JobAgentCompanySeedInventory` liefert einen initialen, vorsichtig kuratierten Seed fuer Muenchen/Freising mit offiziellen Websites, Karriere-URLs, Standortbezug, Branche, Aliasnamen, Scanprioritaet und naechstem Scanzeitpunkt.
- `Add-JobAgentCompanySeedInventory` fuehrt Seeds idempotent in das Store-Dokument zusammen.
- Deduplikation nutzt stabile Keys in dieser Reihenfolge: `company_id`, kanonische Domain, rechtsformnormalisierter Name und Aliasnamen.
- Getrennte Tochter-/Konzernunternehmen werden nur bei gleicher Domain, gleicher ID oder gleicher rechtsformbereinigter Namensidentitaet zusammengefuehrt; gemeinsame Konzernbestandteile allein reichen nicht aus.
- Firmen ohne bekannte Karriere-URL bleiben als Company erhalten, erzeugen aber keine `JobSource` und erhalten `verification_status: COMPANY_DOMAIN_VERIFIED`.

Der schreibende Einstieg fuer den lokalen Store ist:

```powershell
pwsh -NoProfile -File tools\Seed-JobAgentCompanies.ps1
```

Das Skript schreibt `data/jobagent/store.json` transaktional und erzeugt einen Seed-Bericht unter `logs/jobagent/company-seed-*.json`.

Backups liegen unter `data/jobagent/backups/`. Die Pfadprüfung verhindert absolute oder relative Store-Pfade außerhalb des Projektverzeichnisses.

Recovery:

1. Bei beschädigtem `store.json` schlägt `Read-JobAgentStore` fail-closed fehl.
2. Letztes passendes Backup aus `data/jobagent/backups/` manuell prüfen.
3. Backup nach `data/jobagent/store.json` zurückkopieren.
4. `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` ausführen.

## Discovery Source Registry

`data/jobagent/company-discovery.sources.json` ist der maschinenlesbare Quellenvertrag fuer breite Arbeitgeber-Discovery. Das zugehoerige Schema liegt unter `schemas/jobagent.discovery-source.schema.json`.

Jede Quelle enthaelt:

- `source_id`, `source_class`, `source_url`, `operator`
- `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`
- `expected_fields`, `evidence_level`, `freshness_policy`, `retention_policy`
- `import_mode`, `review_required`, `legal_risk`

Importregeln:

- `OFFICIAL_REGISTER` und `OPEN_REGISTER_DUMP` erzeugen nur Register-/Kandidatenhints; offizielle Portale werden nicht massenhaft gescraped.
- `REGIONAL_DIRECTORY` und `PUBLIC_INSTITUTION_DIRECTORY` duerfen Kandidaten liefern, aber ohne separate Unternehmenswebsite-/Karrierepfadpruefung keine `JobSource`.
- `JOB_BOARD_DISCOVERY` erzeugt ausschliesslich volatile Arbeitgeber-Hints mit Suchparametern und Snapshot-Evidenz; Jobboersen duerfen nie als offizielle Karriere- oder Bewerbungsquelle gespeichert werden.
- `OFFICIAL_COMPANY` und `OFFICIAL_ATS` sind die einzigen Klassen mit `evidence_level: PRIMARY_OFFICIAL`.
- `MANUAL_REVIEW` wird nicht automatisch produktiv importiert.
- `REJECTED` ist fail-closed: `import_mode` muss `REJECT`, `evidence_level` muss `NOT_IMPORTABLE`, `review_required` muss `true`, und `legal_risk` muss `BLOCKED` sein.

`Assert-JobAgentDiscoverySourceRegistry` in `src/JobAgent.CompanyInventory.psm1` validiert fail-closed Pflichtfelder, Review-Pflichten und Primaerbeleggrenzen. `New-JobAgentDiscoverySourceCoverageReport` in `src/JobAgent.Coverage.psm1` wertet Quellebene und Firmenebene getrennt aus. Der Funktionsbericht zaehlt Quellen nach Klasse, Importmodus, Evidenzlevel, importierbaren Quellen, abgelehnten Quellen, Manual-Review-Quellen und offenen Verifikationsluecken. Der fokussierte Test schreibt `logs/jobagent/ja-023-source-coverage.json`.

Der ausfuehrliche fachliche Vertrag steht in `docs/company-discovery-source-contract.md`.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1
```

## Regionaler Firmen-Discovery-Feed

`data/jobagent/company-discovery.regional.json` ist der kuratierte Import-Feed fuer `JA-024`. Er enthaelt regionale Arbeitgeberkandidaten aus offiziellen oder halb-offiziellen Quellen fuer Muenchen, Muenchen 20 km und Freising. Der Feed erzeugt erst beim Import Firmen und nur dann `JobSource`-Eintraege, wenn `career_url` gesetzt ist.

Pflichtregeln:

- Jeder Eintrag enthaelt `canonical_name`, `official_website_url`, `career_url` oder `null`, `locations`, `industry`, `scan_priority`, `discovery_type`, `discovery_url`, `discovery_origin` und `evidence_note`.
- `discovery_origin` verweist auf eine `source_id` aus `company-discovery.sources.json`.
- Karriere-URLs duerfen nur offizielle Firmen-, Corporate- oder belegte firmeneigene Karriere-/ATS-Domains sein.
- Aggregatoren und Jobboersen wie LinkedIn, StepStone, Indeed, XING, Kununu oder Glassdoor duerfen im regionalen Feed nicht als Karriere-URL erscheinen.
- Bereits vorhandene Firmen wie Flughafen Muenchen oder Texas Instruments werden ueber Domain/Name dedupliziert und nicht als neue Firma dupliziert.
- Der Import schreibt fuer regionale Feeds ein Log nach `logs/jobagent/company-discovery-regional-import-<timestamp>.json`.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1
pwsh -NoProfile -File tools\Import-JobAgentCompanyDiscovery.ps1 -FeedPath data\jobagent\company-discovery.regional.json
```

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
- `scan_status`, `scan_priority`, `next_scan_at`, `verification_status`, `discovery_source`, `created_at`, `updated_at`, `last_successful_scan_at`.

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
- `alternative_official_urls`: weitere verifizierte offizielle Detail-/ATS-URLs derselben Stelle; Aggregatoren und unverifizierte Drittquellen werden nicht gespeichert.
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

## Job-Deduplikation

`src/JobAgent.Deduplication.psm1` implementiert den Vertrag fuer `JA-008`.

- `New-JobAgentJobIdentityCandidate` erzeugt aus Firmen-ID, Titel, offizieller URL, offizieller Job-ID, ATS-ID, Standort und Source-ID eine geordnete Identitaetsliste.
- Identitaetsprioritaet ist strikt: `OFFICIAL_JOB_ID`, danach `ATS_JOB_ID`, danach `CANONICAL_URL`, danach `COMPOSITE_FINGERPRINT`.
- `Resolve-JobAgentJobDeduplication` entscheidet fuer einen neuen Treffer deterministisch zwischen `NEW`, `KNOWN` und `UPDATED`.
- URL-Vergleiche nutzen `ConvertTo-JobAgentCanonicalUrl`; Tracking-, Session- und Fragment-Unterschiede erzeugen keine neue Stelle.
- `alternative_official_urls` bestehender Jobs werden fuer `CANONICAL_URL`-Matches beruecksichtigt.
- Eine neue offizielle Job-ID mit neuer kanonischer URL wird nicht allein wegen gleichem Titel/Standort zusammengefuehrt; solche Faelle bleiben als neue potenzielle Neuausschreibung getrennt nachvollziehbar.
- Geaenderte Felder wie `title`, `official_url`, `external_job_id` und `ats_job_id` werden im Ergebnis ausgewiesen, damit JA-009 daraus ChangeEvents ableiten kann.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1
```

## Stellenklassifikation

`src/JobAgent.Classification.psm1` implementiert den Vertrag fuer `JA-007`.

- `Get-JobAgentLeadershipClassification` bewertet Titel, Zusammenfassung, Beschreibung, Standort, Arbeitsmodell und Beschaeftigungsart deterministisch.
- Ergebniswerte sind `MATCH`, `POSSIBLE` und `REJECTED`; die Schema-Option `UNKNOWN` bleibt fuer noch nicht klassifizierte Alt- oder Rohdaten reserviert.
- Positive Signale sind IT-Gesamt-/Bereichsleitung, CIO/Head/Director/IT-Leitung, Budget- oder Personalverantwortung und strategische IT-Verantwortung.
- Negative Signale sind Entwickler-, Spezialisten-, Consultant-, Administrator-, reine Projektleitungs- und Teamlead-Rollen ohne belegte Gesamt- oder Strategie-Verantwortung.
- Standortbezug wird ueber `target_area` oder lesbaren Standorttext bewertet. `MUNICH`, `MUNICH_20KM`, `FREISING` und `REMOTE_WITH_TARGET_REFERENCE` sind positiv; `OUT_OF_SCOPE` schlaegt fail-closed fehl.
- Jede Bewertung enthaelt Score, Prioritaet, Gruende, Ausschlussgruende und `evaluated_at`, damit Daily-Reports spaeter nachvollziehbar bleiben.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentClassification.ps1
```

## Quellenverifikation und URL-Kanonisierung

`src/JobAgent.SourceVerification.psm1` implementiert den Vertrag fuer `JA-006`.

- `ConvertTo-JobAgentCanonicalUrl` normalisiert Schema/Host, entfernt Fragmente, trailing Slash, Tracking- und Sessionparameter, erhaelt aber jobrelevante Parameter wie `jobId`.
- `Get-JobAgentOfficialSourceEvaluation` bewertet URLs anhand der Firmendomain, der expliziten Karriere-URL und firmengebundener ATS-Domains aus `Company.ats`.
- `New-JobAgentVerifiedJobSource` erzeugt nur offizielle `JobSource`-Objekte; nicht-offizielle URLs schlagen fail-closed fehl.
- `Resolve-JobAgentOfficialJobUrl` liefert eine primaere offizielle URL und filtert alternative offizielle URLs.

Abgelehnte Primaerquellen:

- StepStone
- Indeed
- LinkedIn
- XING
- Kununu
- Glassdoor

Nicht verifizierbare Quellen erhalten `UNVERIFIED`; bekannte Aggregatoren erhalten `INVALID`. Beide duerfen nicht als Treffer gespeichert werden.

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

## Quellenadapter-Vertrag

`src/JobAgent.SourceAdapters.psm1` definiert den Vertrag fuer `JA-005`.

Adapter-Input:

- `company`: Company-Objekt mit `company_id`, `canonical_name` und `canonical_domain`.
- `source`: offizielle `JobSource` derselben Firma. `is_official` muss `true` sein; Aggregatoren und Jobboersen werden abgelehnt.
- `scan_context`: `scan_run_id`, Startzeit, Timeout, Ergebnisbudget und optionale Suchbegriffe.

Adapter-Output:

- `adapter`, `company_id`, `source_id`, `official_source_url`.
- `status`: `SUCCESS`, `PARTIAL`, `FAILED` oder `SKIPPED`.
- `error_class`: `NONE`, `NOT_REACHABLE`, `TIMEOUT`, `BLOCKED`, `NO_JOBS_FOUND`, `UNCLEAR_SOURCE`, `PARSING_ERROR`, `TECHNICAL_LIMITATION`.
- `retry_recommendation`: `NONE`, `RETRY_SOON`, `RETRY_NEXT_RUN`, `MANUAL_REVIEW`.
- `raw_jobs`: rohe, noch nicht deduplizierte Treffer mit Titel, Detail-URL, optionaler offizieller Job-ID/ATS-ID, Standorttext, Zusammenfassung und Extraktionsvertrauen.
- `scan_attempt`: persistierbarer ScanAttempt fuer das Laufprotokoll.
- `artifact_paths`: optionale lokale Nachweisartefakte.

Implementierte Adapter:

- `Invoke-JobAgentFixtureAdapter`: deterministischer Testadapter ohne externe Website.
- `Invoke-JobAgentGenericHtmlAdapter`: generischer HTML-Link-Extraktor fuer statische Karriere-/Suchseiten-Fixtures.

Grenzen:

- Keine Login-, Paywall-, Captcha- oder ToS-Umgehung.
- Keine Live-Webrecherche in Funktionstests.
- Keine Jobboerse als Primaerquelle.
- Ein leerer oder technisch fehlerhafter Adapterlauf schliesst keine bestehenden Jobs.

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

## Statusmaschine

`src/JobAgent.StatusMachine.psm1` implementiert den Vertrag fuer `JA-009`.

- `Invoke-JobAgentStatusMachine` verarbeitet Adapter-Ergebnisse eines Laufes, erzeugt oder aktualisiert Jobs, schreibt Snapshots, ScanAttempts und ChangeEvents.
- Neue offizielle Treffer werden als `NEW` mit identischem `first_seen`, `last_seen` und `changed_at` gespeichert.
- Wiedererkannte unveraenderte Treffer werden nach dem Folgelauf `ACTIVE`; `first_seen` bleibt stabil, `last_seen` wird aktualisiert.
- Wiedererkannte Treffer mit geaenderten deduplizierten Feldern werden `UPDATED` und erhalten ein `JOB_UPDATED`-Event mit konkreten `changed_fields`.
- Fehlgeschlagene Adapterlaeufe (`FAILED`, nicht autoritative Teilfehler) schliessen oder entfernen keine bestehenden Jobs.
- Nur ein erfolgreicher Firmenlauf mit `status: SUCCESS` und `error_class: NONE` darf nicht mehr gesehene aktive Jobs per `Mark-JobAgentMissingJobs` auf `REMOVED` setzen.
- Invalide Rohjobs ohne belastbaren Titel oder absolute Detail-URL werden nicht als Job gespeichert; sie erzeugen ein `JOB_INVALIDATED`-Event fuer das Laufprotokoll.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1
```

## Daily-Run-Orchestrator

`src/JobAgent.DailyRun.psm1` implementiert den Vertrag fuer `JA-010`.

- `Invoke-JobAgentDailyRun` laedt den Store unter exklusivem Lock, waehlt faellige Firmen mit offizieller Quelle, fuehrt Adapter je Firma isoliert aus, klassifiziert Rohjobs, ruft die Statusmaschine auf und schreibt den aktualisierten Store atomar.
- `Get-JobAgentDailyRunCandidateCompanies` priorisiert Firmen mit offizieller Quelle nach fehlendem erfolgreichem Scan, hoher `scan_priority`, faelligem `next_scan_at` und stabilem Namen. Mit `CompanyIds` kann ein Lauf fuer Tests oder fokussierte Wiederholungen begrenzt werden.
- Adapterfehler werden als `ScanAttempt` mit `FAILED` und konkreter Fehlerklasse persistiert; sie brechen den Gesamtlauf nicht ab und entfernen keine bestehenden Stellen.
- Jeder Lauf erzeugt genau einen `ScanRun` und ein JSON-Ergebnisartefakt unter `logs/jobagent/daily-run-<timestamp>.json`.
- `tools/Invoke-JobAgentDailyRun.ps1` stellt den lokalen CLI-Einstieg fuer deterministische Fixture-Laeufe bereit. Ohne `-FixturePath` bricht das Skript bewusst ab, bis Live-Adapter als getrennte Lane angebunden sind.
- Der Orchestrator nutzt in Funktionstests ausschliesslich Fixture-Adapter; Live-Recherche bleibt eine getrennte Lane.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1
```

## Recherchebericht

`src/JobAgent.Report.psm1` implementiert den Berichtvertrag fuer `JA-011`.

- `New-JobAgentDailyReport` erzeugt aus Store-Dokument und `scan_run_id` einen strukturierten Report mit neuen passenden Stellen, unveraenderten aktiven passenden Stellen, geaenderten Stellen, geschlossenen oder entfernten Stellen, neuen Unternehmen und Recherche-Statistik.
- Passende Stellen sind nur Klassifikationen mit `MATCH` oder `POSSIBLE` und Prioritaet `A`, `B` oder `C`; abgelehnte oder unbewertete Rollen werden nicht als passende Treffer gerendert.
- `ConvertTo-JobAgentDailyReportMarkdown` rendert den Bericht als Markdown mit offizieller URL, A/B/C-Prioritaet, Score, Standort, Arbeitsmodell, Beschaeftigungsart, Klassifikationsgruenden und Anforderungen.
- Fehlende optionale Werte bleiben `UNKNOWN`; der Renderer erfindet keine Standorte, Anforderungen, Gehaelter oder Verifikationsaussagen.
- Unveraenderte bekannte Stellen erscheinen nicht erneut als neue Treffer, sondern kompakt unter aktiven passenden Stellen.
- `Invoke-JobAgentDailyRun` schreibt weiterhin das JSON-Laufartefakt und zusaetzlich einen Markdown-Bericht unter `logs/jobagent/daily-run-<timestamp>.md`.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentReport.ps1
```

## Betriebsmodus: Daily-Run und Status

`src/JobAgent.Operations.psm1` implementiert den lokalen Betriebsvertrag fuer `JA-012`:

- `Invoke-JobAgentManagedDailyRun` kapselt den fachlichen Daily-Run mit separatem Betriebs-Lock unter `logs/jobagent/daily-run.lock`, Statusdatei `logs/jobagent/daily-run.status.json`, Run-Log und Exitcode-Vertrag.
- `Get-JobAgentDailyRunOperationalStatus` liefert nicht-interaktiv den letzten bekannten Laufzustand und erkennt einen laufenden Prozess ueber das Lock-Payload.
- `Invoke-JobAgentLogRotation` begrenzt `logs/jobagent/daily-run-*.log` auf die konfigurierte Anzahl und entfernt nur diese verwalteten Betriebslogs.
- `tools\Invoke-JobAgentDailyRun.ps1` nutzt den Betriebswrapper. Ohne `-FixturePath` bleibt die Live-Lane weiterhin fail-closed.
- `tools\Get-JobAgentDailyRunStatus.ps1` gibt den Status als JSON aus und ist fuer Scheduler-Checks geeignet.

Exitcodes:

- `0`: Lauf erfolgreich oder ohne fatalen technischen Fehler abgeschlossen.
- `1`: fachlicher Laufstatus `FAILED`, ungefangener Adapter-/Persistenzfehler oder aktives Lock.

Windows Task Scheduler:

```powershell
schtasks /Create /TN "JobAgent Daily Run" /SC DAILY /ST 07:30 /TR "pwsh -NoProfile -File D:\_Scripte\JobAgent\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot D:\_Scripte\JobAgent -FixturePath D:\_Scripte\JobAgent\tests\fixtures\jobagent\daily-run.json" /F
```

Hinweise:

- Arbeitsverzeichnis muss `D:\_Scripte\JobAgent` sein, wenn spaeter `.\ci.cmd daily-run` verwendet wird.
- Produktive Live-Recherche wird erst mit JA-014 aktiviert; bis dahin nur Fixture- oder Mock-Laeufe planen.
- Vor einem manuellen Re-Run `pwsh -NoProfile -File tools\Get-JobAgentDailyRunStatus.ps1` ausfuehren und bei `is_running=true` keinen zweiten Lauf starten.
- Logs und Statusdateien duerfen keine Secrets enthalten; Fixture- und Live-Parameter mit Secrets sind nicht vorgesehen.

Funktionstest:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1
```

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
      "alternative_official_urls": [],
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
