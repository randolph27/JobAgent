# JobAgent Discovery-Betrieb

Stand: 2026-08-23

## Ziel

Der laufende Betrieb trennt drei Arbeitsarten: Firmen-Jobscan, Kandidatenverifikation und Quellenrefresh. Coverage-Reports zeigen operative Naeherungen aus dem lokalen Store und behaupten keine vollstaendige Marktdeckung fuer Muenchen oder Freising.

## Freshness-Modell

Firmen, Kandidaten und Quellen fuehren einheitliche Felder:

- `last_imported_at`: Zeitpunkt der Aufnahme oder letzten Quellenuebernahme.
- `last_verified_at`: Zeitpunkt einer offiziellen Website-, Karriere- oder ATS-Verifikation.
- `expires_at`: Ablaufzeitpunkt nach Quellenklasse oder Verifikationsstatus.
- `next_refresh_at`: naechster geplanter Refresh oder Recheck.
- `refresh_reason`: fachlicher Grund fuer die naechste Aktion.
- `staleness_status`: `FRESH`, `REFRESH_DUE`, `EXPIRED` oder `UNKNOWN`.

Jobboersen- und Discovery-Hints laufen schnell ab, Register- und offizielle Quellen mittelfristig, regionale Verzeichnisse langsamer. Abgelaufene Hinweise werden sichtbar markiert und nicht still geloescht.

## Priorisierung

Der Daily-Run bevorzugt refresh-faellige Firmen vor regulaeren Scanfaellen. Innerhalb dieser Gruppe bleiben fehlende erfolgreiche Scans, hoehere `scan_priority`, `next_refresh_at`, `next_scan_at` und Firmenname deterministische Sortierkriterien.

## Reports

`tools/Measure-JobAgentCompanyCoverage.ps1` erzeugt JSON, Markdown und HTML. Die Reports enthalten Freshness-Metriken nach Status, Refresh-Grund, Zielgebiet, Quelle, Verifikationsstatus, Kandidaten-Freshness und segmentiertem Firmeninventar. Grosse HTML-Listen bleiben in Scroll-Containern mit Sticky-Headern.

## Anbieter-Link-Vertrag

Coverage-Firmeneintraege enthalten `links` und `primary_link`. Linkobjekte werden zentral aus dem Firmeninventar und offiziellen JobSources gebildet:

- `career`: `company.career_url` oder offizielle `job_sources.canonical_url` mit `source_type=CAREER_PAGE`.
- `website`: `company.official_website_url`, wenn keine verifizierte Karriere-URL vorhanden ist.
- `ats`: offizielle `job_sources.canonical_url` mit `source_type=OFFICIAL_ATS` oder `verification_basis=COMPANY_LINKED_ATS`.
- `review_hint`: unverifizierte `discovery_source.url`; nur Review-Hinweis, nicht produktiv anklickbar.
- `missing`: Fail-Closed-Platzhalter, wenn keine verifizierte Karriere-, Website- oder ATS-URL vorliegt.

Jeder Link fuehrt `link_type`, `label`, `url`, `source_id`, `source_field`, `verification_status`, `is_primary`, `is_clickable`, `review_only` und `reason`. Jobboersen- oder Discovery-Hints duerfen nicht als offizielle Anbieterlinks ausgegeben werden; sie bleiben `review_only` oder werden verworfen.

## Grenzen

Sekundaerquellen liefern nur Discovery-Hints. Produktive Firmen- oder JobSource-Aufnahme verlangt offizielle Firmen-, Karriere- oder ATS-Evidenz. Live-Refreshes muessen die Source Registry, Rate-Limits, Robots-/Terms-Hinweise und Fehlerbudgets einhalten.

## Snapshot-Lane

`tools/Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` verarbeitet ein lokales Manifest, standardmaessig `data/jobagent/company-discovery.snapshot.json`. Das Manifest darf nur Quellen aus `data/jobagent/company-discovery.sources.json` referenzieren, deren `import_mode` `BULK_SNAPSHOT` oder `FIXTURE_OR_SNAPSHOT_ONLY` ist. Quellen mit fehlendem `allowed_use`, `rate_limit_policy`, `robots_or_terms_note` oder `import_mode` werden fail-closed abgelehnt.

Die Lane unterstuetzt drei Snapshot-Arten:

- `register`: lokale Register-Dumps ueber `Import-JobAgentRegisterCandidates`.
- `regional`: lokale regionale Verzeichnis-Snapshots ueber `Import-JobAgentRegionalDirectories`.
- `jobboard`: lokale Jobboersen-Snapshots ueber `Import-JobAgentJobBoardEmployers`.

Die produktive Manifest-Lane fuehrt derzeit auch `source-registry:stadt_muenchen_boersennotierte_unternehmen`, `source-registry:landkreis_freising_wirtschaft`, `source-registry:munich_business_international_companies`, `source-registry:munich_business_ikt_companies`, `source-registry:munich_business_life_sciences_companies`, `source-registry:munich_business_automotive_mobility_companies`, `source-registry:munich_business_finance_companies`, `source-registry:munich_business_us_companies`, `source-registry:munich_business_japanese_companies`, `source-registry:munich_business_indian_companies`, `source-registry:munich_business_creative_companies`, `source-registry:munich_business_commercial_locations`, `source-registry:munich_business_klimapakt3_companies`, `source-registry:munich_startup_platform_ecosystem`, `source-registry:awesome_ml_startups_munich_github`, `source-registry:tech_companies_munich_github`, `source-registry:stadt_freising_weihenstephan` und `source-registry:stadt_muenchen_unternehmensbeteiligungen` als regionale Snapshot-Quellen. Die munich-business-Quellen basieren auf oeffentlichen Standort-, Gewerbeflaechen-, Branchenfokus-, Nachhaltigkeits- und internationalen Community-Seiten. Die Boersennotierte-Muenchen-Quelle basiert auf der oeffentlichen Liste der Wirtschaftsförderung mit DAX/MDAX/SDAX/TecDAX-Unternehmen am Standort Muenchen und Region. Die Klimapakt-3-Quelle basiert auf der oeffentlichen Liste teilnehmender Muenchner Grossunternehmen und Kooperationspartner der Landeshauptstadt Muenchen. Die Munich-Startup-Quelle basiert auf dem offiziellen Startup-Portal fuer Muenchen und Region; Profilseiten werden nur als regionale Arbeitgeberhinweise genutzt, nicht als Karriere- oder Firmenwebsite-Beleg. Die Landkreis-Freising-Quelle basiert auf der oeffentlichen Wirtschaftsseite des Landkreises und fuehrt nur die dort namentlich genannten grossen Arbeitgeber. Die Tech-Companies-Munich-Quelle basiert auf einer oeffentlichen, MIT-lizenzierten GitHub-Liste mit Muenchner Tech-Unternehmen; sie wird nur als Community-Discovery-Hinweis genutzt und ihre Karriere-Links werden nicht als offizielle Anbieterlinks persistiert. Die Awesome-ML-Startups-Munich-Quelle basiert auf einer oeffentlichen GitHub-Liste mit Muenchner Machine-Learning- und AI-Startups; sie wird nur als Community-Discovery-Hinweis genutzt und externe Firmenlinks werden nicht als offizielle Anbieterlinks persistiert. Die Freising-Weihenstephan-Quelle basiert auf der oeffentlichen Wirtschaftsseite der Stadt Freising; die staedtische Beteiligungsquelle basiert auf der oeffentlichen Unternehmensbeteiligungsliste der Landeshauptstadt Muenchen. Alle diese Quellen duerfen nur unverifizierte Arbeitgeberkandidaten liefern; offizielle Firmen- und Karriereverifikation bleibt Pflicht.

Beim Snapshot-Refresh ersetzt die Lane bestehende Hints der erneut verarbeiteten Quellen. Dadurch bleiben alte lokale Test- oder Stale-Hints nicht im produktiven Hint-Store, wenn eine Quelle auf einen neuen Snapshot umgestellt wird.

Manifest-Inputs koennen als einzelne Datei (`input_path`), als Glob (`input_glob`) oder als Verzeichnis plus Filter (`input_directory` und `input_pattern`) angegeben werden. Globs und Verzeichnisfilter muessen mindestens eine Datei finden; leere Matches brechen fail-closed ab. `snapshot_date` bleibt fuer Register-Snapshots Pflicht und kann am Item oder am einzelnen Input stehen.

Jede Quelle schreibt ein Log `logs/jobagent/company-discovery-snapshot-*.json` mit Abrufzeit, Input-Hash, Record-/Hint-Zaehlern, Reject-Gruenden, Nutzungsnotiz, Rate-Limit-Policy und `official_verification_required=true`. Der Digest `logs/jobagent/company-discovery-snapshot-digest-*.json` fasst Quellen, neue Hints, den gemergten Hint-Store und `source_gate` zusammen. Dieses Gate vergleicht alle importierbaren Snapshot-Quellen aus der Source Registry mit den eindeutig verarbeiteten Quellen und meldet fehlende oder unerwartete Quellen fail-closed als `failed`, ohne Hints in den produktiven Store zu schreiben. Die Lane schreibt ausschliesslich `data/jobagent/company-discovery.hints.json` und Snapshot-Logs; `data/jobagent/store.json` und `job_sources` bleiben unveraendert.

Beispiel:

```powershell
pwsh -NoProfile -File tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane
```

## Validierung

Funktionale Pflichttests:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1
pwsh -NoProfile -File tests\Test-JobAgentRegisterDiscovery.ps1
pwsh -NoProfile -File tests\Test-JobAgentJobBoardDiscovery.ps1
pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1
pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1
```

Der Supertest ist Abschluss-Gate nach gruenen Funktionstests:

```powershell
.\ci.cmd supertest
```
