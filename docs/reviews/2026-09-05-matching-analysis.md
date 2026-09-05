# Stellenmatching, Extraktion und Scanbelege — Review 2026-09-05

## Ergebnis und Nachweisgrenze

Der produktive Bestand belegt keine belastbare Suche über 1.000 Firmenwebseiten. Er enthält 479 Firmen, 439 Jobquellen, 476 Firmen mit `PENDING`, zwei mit `SUCCESS` und eine mit `FAILED`. Die zehn gespeicherten Scanversuche betreffen drei Firmen; sechs Versuche nennen `live-html-adapter`, vier den Fehlerwrapper. Alle sechs gespeicherten Scanläufe stammen vom 17.08.2026. Die drei gespeicherten Jobs sind `REJECTED`, ihre Orts-, Arbeitsmodell- und Beschäftigungsdaten sind unbekannt. `SUCCESS` belegt hier HTTP-/Adaptererfolg, keine vollständige Stellenprüfung.

Die drei gespeicherten Jobtitel sind `Job Search`, Siemens `FAQs & Support ...` und SWM `IT-Expert*in` mit URL `/karriere/it`. Sie sind Navigations-/Bereichsseiten, keine belegten einzelnen Zielstellen. Belege: `data/jobagent/store.json:19617`, `:19626`, `:19664`, `:19702`, `:28978`, `:29076`; `logs/jobagent/live-pilot-20260817.json`.

Ein separater Livepilot vom 24.08.2026 dokumentiert BMW, Allianz und Munich Re mit `PARTIAL` und null passenden Jobs. Auch dessen einziger extrahierter Job ist eine Bereichsseite (`READ MORE`, Allianz `/global/en/career-development`). Dieser Lauf ist im aktuellen produktiven Store nicht enthalten. Beleg: `logs/jobagent/live-pilot-20260824.json`. Das ist ein zusätzlicher historischer Scanbeleg, keine aktuelle Prüfung dieser Arbeitgeber.

`html/jobagent/ja-022-viewport-audit.html:57` und `:69` zeigen dagegen synthetische Stellen bei `Alpha AG` auf `example.invalid`. Diese Viewport-Fixture belegt Darstellung, keine realen Stellen. Die vorhandenen Tests verwenden überwiegend deterministische Fixture-Fetcher; im Rahmen dieses Teilreviews wurden keine produktiven Scans oder Importe ausgelöst und keine externe Stellenaktualität behauptet.

## Priorisierte Befunde

| Rang | Schwere | Beleg | Befund und notwendiger Akzeptanzvertrag |
|---|---|---|---|
| 1 | Kritisch | `src/JobAgent.LiveScan.psm1:637`, `:665`; `src/JobAgent.StatusMachine.psm1:378`, `:498` | Ein erfolgreicher Detailabruf genügt für `SUCCESS/NONE`, obwohl andere Details fehlschlagen oder das Abruflimit nicht alle Kandidaten zulässt. `SUCCESS/NONE` und sogar `PARTIAL/NO_JOBS_FOUND` berechtigen zur Entfernung nicht gesehener Jobs. Vollständigkeit muss explizit und unabhängig vom HTTP-Erfolg belegt werden; Abbruch, Pagination, Limit, Blockade und unsichere Leerextraktion dürfen keine Entfernung auslösen. |
| 2 | Kritisch | `src/JobAgent.LiveScan.psm1:559`; `src/JobAgent.Deduplication.psm1:114`, `:190` | Die heuristische Job-ID wird aus der gesamten URL extrahiert. Auf `jobs.example.com/job/123` und `/456` entsteht jeweils `s.example.com`; dieser als starke ID behandelte Wert kann verschiedene Stellen verschmelzen. Produktives Analogon: `s.siemens.com`. IDs nur aus dokumentierten ATS-Feldern oder exakt abgegrenzten Pfad-/Querysegmenten übernehmen, ansonsten kanonische URL verwenden. |
| 3 | Hoch | `src/JobAgent.StatusMachine.psm1:280`–`:303`; `src/JobAgent.DailyRun.psm1:239` | Bestehende Jobs übernehmen bei erneuter Sichtung die neue Klassifikation, Priorität, Arbeitsmodell und Beschäftigungsart nicht. Neue Titel/Orte/Beschreibungen können damit mit einer alten Ablehnung oder alten Bewertung kombiniert werden. Geänderte Daten und neue Klassifikation müssen atomar übernommen und fachlich relevante Änderungen als Event ausgewiesen werden. |
| 4 | Hoch | `src/JobAgent.Classification.psm1:110`, `:171`, `:249`; `tests/Test-JobAgentClassification.ps1:125` | Die Regeln sind auf IT-Gesamt-/Bereichsleitung zugeschnitten. `IT Manager` und `IT Lead` erhalten keinen Titelbonus; selbst mit `People management` und Zielort ergeben beide ohne zusätzliche optionale Angaben `REJECTED`, Score 40. Rollenfamilien IT-Leitung, IT Lead/Teamleitung und IT Management explizit abbilden; fehlende Vollzeit-/Hybridangaben dürfen keinen belegten Zieltitel verschwinden lassen. Spezialisten-/Projektrollen separat behandeln. |
| 5 | Hoch | `src/JobAgent.Classification.psm1:36`, `:48`, `:206`; `src/JobAgent.StatusMachine.psm1:127` | Ein Standortstring `Hamburg` wird `UNKNOWN`, nicht `OUT_OF_SCOPE`; eine starke IT-Leitung dort wird `MATCH`. Mehrfachstandorte werden auf einen einzigen Ort reduziert; `Garching bei Muenchen` wird Stadt München. Ortsnormalisierung muss Stadt, Umland, Mehrfachstandorte, Remote-Bedingung, außerhalb und unbekannt trennen. Unbekanntheit darf nicht als belegtes Zielgebiet gelten. |
| 6 | Hoch | `src/JobAgent.LiveScan.psm1:197`, `:204`, `:428`, `:456`, `:556` | Karriere-/Job-Navigation und FAQs passieren die Kandidatensuche; Suchbegriffe sind kein strikter Filter. Die ersten zehn Kandidaten und fünf Detailabrufe können durch irrelevante Links verbraucht werden. Der Detailabruf übernimmt den Ankertitel und die ersten 500 Zeichen der gesamten HTML-Seite; strukturierte Detaildaten und belegte Bewerbungsfunktion werden nicht erneut ausgewertet. Navigation ausschließen, JobPosting-/ATS-Daten bevorzugen, Details inhaltlich validieren und relevante Kandidaten vor dem Budget priorisieren. |
| 7 | Mittel | `src/JobAgent.LiveScan.psm1:377`, `:556`–`:576`; `src/JobAgent.Report.psm1:404`, `:504` | Für textbasierte Ankertreffer bleiben Ort/Arbeitsmodell/Beschäftigung überwiegend unbekannt; Arbeitsmodell wird im Liveadapter nicht extrahiert. Detail-JSON-LD wird nicht zur Anreicherung genutzt, ein vorhandener strukturierter Beschreibungstext wird von beliebigem nichtleerem Seitentext verdrängt. Filter benötigen zuerst stabile normalisierte Felder und eine sichtbare Kategorie „Unbekannt“. |

Zusätzlich markiert `Update-JobAgentDailyRunCompanyState` eine Firma bereits bei einer erfolgreichen Quelle als erfolgreich, selbst wenn andere Firmenquellen scheitern (`src/JobAgent.DailyRun.psm1:306`–`:315`). Für das 1.000-Firmen-Ziel sind deshalb mindestens getrennte Zähler nötig: eindeutige Firmen, offizielle Karrierequelle verifiziert, Scan versucht, Stellensuche vollständig, Ergebnis leer/mit Treffern, blockiert/teilweise und veraltet. Weder Inventargröße noch HTTP 200 darf als vollständig untersuchte Firma zählen.

## Reproduzierbare lokale Befunde

Alle Beispiele laufen unter PowerShell 7.4+ aus dem Projektroot, schreiben keinen Store und rufen kein Netzwerk auf. Private Modulfunktionen werden bewusst nur für die Diagnose im Modulkontext aufgerufen.

### 1. IT Manager und IT Lead werden trotz Personalführung abgelehnt; Hamburg wird passend

```powershell
Import-Module ./src/JobAgent.Classification.psm1 -Force -DisableNameChecking
$cases = @(
    @{ Title = 'IT Manager'; Summary = 'People management for the IT team.'; Location = 'Freising' },
    @{ Title = 'IT Lead'; Summary = 'People management for the IT team.'; Location = 'Muenchen' },
    @{ Title = 'Leiter IT'; Summary = 'Gesamtverantwortung und IT-Strategie.'; Location = 'Hamburg' },
    @{ Title = 'Leiter IT'; Summary = 'Gesamtverantwortung und IT-Strategie.'; Location = 'Freising' }
)
foreach ($case in $cases) {
    $result = Get-JobAgentLeadershipClassification @case
    [pscustomobject]@{
        title = $case.Title; location = $case.Location
        result = $result.result; score = $result.score
    } | ConvertTo-Json -Compress
}
```

Ist-Ausgabe:

```json
{"title":"IT Manager","location":"Freising","result":"REJECTED","score":40}
{"title":"IT Lead","location":"Muenchen","result":"REJECTED","score":40}
{"title":"Leiter IT","location":"Hamburg","result":"MATCH","score":84}
{"title":"Leiter IT","location":"Freising","result":"MATCH","score":92}
```

### 2. Zwei unterschiedliche Stellen erhalten dieselbe starke Job-ID

```powershell
Import-Module ./src/JobAgent.LiveScan.psm1 -Force -DisableNameChecking
& (Get-Module JobAgent.LiveScan) {
    foreach ($url in @('https://jobs.example.com/job/123', 'https://jobs.example.com/job/456')) {
        $candidate = [pscustomobject]@{
            title = 'IT Manager'; detail_url = $url; location_label = 'Muenchen'
            verification_basis = 'COMPANY_DOMAIN'
            summary = 'People management for the IT team.'
        }
        $fetch = [pscustomobject]@{
            content = '<nav>Navigation and privacy</nav><main><h1>IT Manager</h1></main>'
            status_code = 200; final_url = $url
        }
        New-JobAgentLiveRawJob -Candidate $candidate -DetailFetch $fetch |
            Select-Object title, external_job_id, detail_url, summary |
            ConvertTo-Json -Compress
    }
}
```

Ist-Ausgabe:

```json
{"title":"IT Manager","external_job_id":"s.example.com","detail_url":"https://jobs.example.com/job/123","summary":"Navigation and privacy IT Manager"}
{"title":"IT Manager","external_job_id":"s.example.com","detail_url":"https://jobs.example.com/job/456","summary":"Navigation and privacy IT Manager"}
```

### 3. Ein fehlgeschlagener Detailabruf ergibt trotzdem SUCCESS

```powershell
Import-Module ./src/JobAgent.LiveScan.psm1 -Force -DisableNameChecking
Import-Module ./src/JobAgent.SourceAdapters.psm1 -Force -DisableNameChecking
$store = Get-Content ./data/jobagent/store.json -Raw | ConvertFrom-Json
$company = $store.companies | Where-Object company_id -eq 'company:siemens_ag'
$source = $store.job_sources | Where-Object source_id -eq 'source:siemens_ag_career'
$context = New-JobAgentScanContext -ScanRunId 'scanrun:review20260905' -TimeoutSeconds 1 -MaxResults 10
$input = New-JobAgentAdapterInput -Company $company -JobSource $source -ScanContext $context
$policy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 10 -MaxDetailFetchesPerSource 5
$sourceUrl = [string]$source.canonical_url
$fetcher = {
    param($Url, $Policy, $Attempt)
    $isSource = $Url -eq $sourceUrl
    $failed = $Url -like '*222'
    [pscustomobject]@{
        ok = (-not $failed); url = $Url; final_url = $Url
        status_code = $(if ($failed) { 503 } else { 200 })
        content = $(if ($isSource) {
            '<a href="https://siemens.com/jobs/111">Head of IT</a><a href="https://siemens.com/jobs/222">IT Manager</a>'
        } else { '<h1>Head of IT</h1><p>People management and technology strategy.</p>' })
        error = $(if ($failed) { 'unavailable' } else { $null })
    }
}
Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $fetcher |
    Select-Object status, error_class, @{ n = 'raw_job_count'; e = { @($_.raw_jobs).Count } }, artifact_paths |
    ConvertTo-Json -Depth 5
```

Ist-Ausgabe:

```json
{
  "status": "SUCCESS",
  "error_class": "NONE",
  "raw_job_count": 1,
  "artifact_paths": [
    "detail_fetch_failed[NOT_REACHABLE]: https://siemens.com/jobs/222: unavailable"
  ]
}
```

Die Entfernungseignung lässt sich separat ohne Persistenz prüfen:

```powershell
Import-Module ./src/JobAgent.StatusMachine.psm1 -Force -DisableNameChecking
& (Get-Module JobAgent.StatusMachine) {
    foreach ($result in @(
        [pscustomobject]@{ status = 'SUCCESS'; error_class = 'NONE' },
        [pscustomobject]@{ status = 'PARTIAL'; error_class = 'NO_JOBS_FOUND' }
    )) {
        Test-JobAgentRemovalEligibleAdapterResult -AdapterResult $result
    }
}
```

Ist-Ausgabe: zweimal `True`. Dies belegt die unsichere Freigabebedingung; eine produktive Entfernung wurde nicht ausgeführt.

### 4. Aktualisierter Job behält seine alte Ablehnung und unbekannte Filterfelder

```powershell
Import-Module ./src/JobAgent.StatusMachine.psm1 -Force -DisableNameChecking
$store = Get-Content ./data/jobagent/store.json -Raw | ConvertFrom-Json
$existing = $store.jobs[0]
$raw = [pscustomobject]@{
    title = 'IT Manager'; detail_url = $existing.official_url
    external_job_id = $existing.external_job_id; ats_job_id = $existing.ats_job_id
    location_label = 'Freising'; summary = 'Gesamtverantwortung fuer IT-Strategie und IT-Betrieb.'
    classification = [pscustomobject]@{ result = 'MATCH'; priority = 'A'; score = 95 }
    priority = 'A'; work_model = 'HYBRID'; employment_type = 'FULL_TIME'
}
$decision = [pscustomobject]@{
    decision = 'UPDATED'; changed_fields = @('title', 'location'); identity_basis = 'OFFICIAL_JOB_ID'
}
& (Get-Module JobAgent.StatusMachine) {
    param($existing, $raw, $decision)
    $updated = Update-JobAgentExistingJobFromRawJob -ExistingJob $existing -RawJob $raw `
        -Decision $decision -ObservedAt '2026-09-05T12:00:00Z'
    $updated.job | Select-Object title, @{ n = 'result'; e = { $_.classification.result } },
        priority, work_model, employment_type | ConvertTo-Json -Compress
} $existing $raw $decision
```

Ist-Ausgabe:

```json
{"title":"IT Manager","result":"REJECTED","priority":"UNRATED","work_model":"UNKNOWN","employment_type":"UNKNOWN"}
```

## Funktionstests und verbleibende Prüflücken

Am 05.09.2026 ausgeführt, jeweils Exitcode 0:

```powershell
pwsh -NoProfile -File tests/Test-JobAgentClassification.ps1
pwsh -NoProfile -File tests/Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File tests/Test-JobAgentStatusMachine.ps1
pwsh -NoProfile -File tests/Test-JobAgentSourceAdapters.ps1
pwsh -NoProfile -File tests/Test-JobAgentReport.ps1
```

Die Suites melden 9, 16, 9, 11 und 10 Fälle. Sie sichern vorhandenes Verhalten ab; die reproduzierten Produktfehler zeigen zusätzliche Akzeptanzlücken. Noch erforderlich sind zielbezogene Tests für gemischten Detailerfolg, abgeschnittene/paginierte Listen, ungeklärte Leerextraktion, gleiche ATS-Domain mit verschiedenen Job-IDs, erneute Klassifikation bestehender Stellen, IT Lead/IT Manager mit fehlenden optionalen Feldern, bekannte Fremdorte und Mehrfachstandorte. Navigationsseiten, FAQ, Karriereentwicklung und HTTP-200-Blockadeseiten müssen Negativfälle werden.

Für den späteren Filtervertrag sind Rollenfamilie, Freising/München/Umland, optionaler Radius, Remote/Hybrid/Präsenz, Arbeitszeit, Firma, Status, Aktualität und Datenvollständigkeit sinnvoll. Radiusfilter setzen belegte Geodaten voraus; Ortstext und Firmensitz allein reichen nicht. Die aktuelle Berichtsauswahl schließt `REJECTED` vollständig aus (`src/JobAgent.Report.psm1:404`), weshalb falsch abgelehnte IT-Lead-/Manager-Stellen durch zusätzliche UI-Filter nicht zurückkehren können.

Die Roadmap sollte Datenkorrektheit einschließlich Vollständigkeit, Identität und Aktualisierung vor dem Massenscan abschließen; die Akquise neuer Firmen kann davon unabhängig mit begrenzter Parallelität weiter verbessert werden. Anschließend folgen belegte ATS-/Detailadapter und der Nachweis von 1.000 tatsächlich untersuchten Firmen, getrennt von 1.000 importierten Firmen. Diese Datei ist Review-Evidence; Status, Aufwand, Dauer, Score und Meilensteine werden zentral in der bereinigten Roadmap geführt.
