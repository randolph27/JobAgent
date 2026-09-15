# QA-003.3 CLI-Fallkatalog

Stand: 2026-09-15

Alle Aufrufe verwenden einen neu angelegten, isolierten `ProjectRoot`. `FixturePath` und `AcquisitionFixtureMapPath` liegen ausschliesslich darunter. Es werden keine produktiven Daten, Netzwerkendpunkte oder Bewerbungsaktionen verwendet.

| Einstieg | Fixture-Aufruf | Gepruefter Vertrag |
| --- | --- | --- |
| `Invoke-JobAgentDailyRun.ps1` | `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot <root> -FixturePath <root>\daily-scan-fixture.json -AcquisitionFixtureMapPath acquisition-fixture-map.json -AcquisitionCandidateBudget 1 -MaxCompanies 1 -FetchClient curl -WslDistribution FixtureDistro` | Akquise und Stellenscan erhalten dieselbe `run_id`; eine neu verifizierte Karrierefirma wird trotz expliziter Firmenauswahl im selben Lauf gescannt und publiziert. |
| `Invoke-JobAgentDailyRun.ps1` | derselbe Aufruf mit unveraenderter Fixture und demselben Root | Wiederanlauf dupliziert weder Firma noch Stelle; bestehende IDs bleiben eindeutig. |
| `Invoke-JobAgentDailyRun.ps1` | derselbe Aufruf mit fehlender `-AcquisitionFixtureMapPath` und expliziter bestehender `-CompanyIds` | Akquisefehler wird als `PARTIAL` ausgewiesen; der Scan bleibt ausfuehrbar und entfernt keine vorhandenen Stellen. |
| `Invoke-JobAgentDailyRun.ps1` | `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot <root> -FixturePath <root>\daily-fixture.json -CompanyIds company:alpha_ag` | Fixturemodus publiziert JSON-, Markdown- und HTML-Bericht atomar und liefert Erfolgsexitcode. |
| `Invoke-JobAgentDailyRun.ps1` | `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -ProjectRoot <root> -MaxCompanies 1 -MaxResultsPerSource 2 -MaxDetailFetchesPerSource 2 -MaxPagesPerSource 2 -MaxRetries 0 -FetchClient curl -WslDistribution FixtureDistro` | Leerer Store im Livemodus wird ohne Netzwerkabruf kontrolliert als `SKIPPED` publiziert. |
| `Get-JobAgentDailyRunStatus.ps1` | `pwsh -NoProfile -File .\tools\Get-JobAgentDailyRunStatus.ps1 -ProjectRoot <root>` | Fehlender Lauf, aktiver Lock, toter Besitzer und letzter Status werden ueber den Operations-Funktionstest abgedeckt. |
| `Import-JobAgentCompanyDiscovery.ps1` | `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot <root> -FeedPath <root>\wave-feed.json -WaveId A` | Offiziell belegter Import schreibt Backup und Gatebericht; unverifizierter Hint wird fail-closed abgewiesen. |
| `Invoke-JobAgentDiscoveryRefill.ps1` | indirekt durch den fixturegestuetzten regulaeren Daily-Run | Quellennachfuellung verarbeitet nur lokale Snapshots, respektiert Budget und liefert `wake_at` ohne Busy-Wait. |
| `Discover-JobAgentCompanyCandidateWebsites.ps1` | indirekt durch den fixturegestuetzten regulaeren Daily-Run mit `-AcquisitionFixtureMapPath` | Kandidatenwebsite und Karrierequelle werden nur aus lokaler Response-Map verifiziert. |
| `Verify-JobAgentCompanyCandidates.ps1` | indirekt durch den fixturegestuetzten regulaeren Daily-Run mit `-AcquisitionFixtureMapPath` | Kandidatencheckpoint, offizielle Quelle und neue Firma werden atomar in den isolierten Store uebernommen. |

Die konkreten automatisierten Assertions liegen in `Test-JobAgentDailyRun.ps1`, `Test-JobAgentOperations.ps1` und `Test-JobAgentImportWaves.ps1`. Der Fehlerpfad nach dem Kandidatencheckpoint sowie vor der Store-/Reportpublikation wird durch die jeweiligen atomaren Store- und Managed-Run-Vertraege getestet; ein fehlgeschlagener Managed-Lauf behaelt den letzten publizierten Bericht als `is_stale` bei.
