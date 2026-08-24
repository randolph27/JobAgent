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

## Validierung

Funktionale Pflichttests:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1
```

Der Supertest ist Abschluss-Gate nach gruenen Funktionstests:

```powershell
.\ci.cmd supertest
```
