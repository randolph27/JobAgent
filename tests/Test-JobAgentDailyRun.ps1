#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.LiveScan.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestProjectRoot {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-dailyrun-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function New-TestCompany {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][int]$Priority
    )

    New-JobAgentCompanySeed `
        -CanonicalName $Name `
        -OfficialWebsiteUrl ('https://' + $Domain + '/') `
        -CareerUrl ('https://' + $Domain + '/careers') `
        -Aliases @() `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'UNKNOWN' `
        -ScanPriority $Priority `
        -DiscoverySourceUrl ('https://' + $Domain + '/careers') `
        -CreatedAt ([datetime]'2026-08-17T09:00:00Z') `
        -NextScanAt ([datetime]'2026-08-17T09:00:00Z')
}

function New-TestStore {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
    $seed = @(
        New-TestCompany -Name 'Alpha AG' -Domain 'alpha.example.invalid' -Priority 90
        New-TestCompany -Name 'Beta AG' -Domain 'beta.example.invalid' -Priority 80
        New-TestCompany -Name 'Gamma AG' -Domain 'gamma.example.invalid' -Priority 70
    )
    $result = Add-JobAgentCompanySeedInventory -Document $document -Seeds $seed -SeededAt ([datetime]'2026-08-17T09:00:00Z')
    Write-JobAgentStore -ProjectRoot $ProjectRoot -Document $result.document | Out-Null
}

function Add-TestSource {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$Url
    )

    $document = Read-JobAgentStore -ProjectRoot $ProjectRoot
    $source = [pscustomobject]@{
        source_id = $SourceId
        company_id = $CompanyId
        source_type = 'CAREER_PAGE'
        url = $Url
        canonical_url = $Url
        is_official = $true
        verified_at = '2026-08-17T09:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @(
            [pscustomobject]@{
                status = 'VERIFIED'
                evidence_type = 'CAREER_URL'
                url = $Url
                basis_url = ('https://' + ([Uri]$Url).Host + '/')
                redirect_chain = @()
                observed_at = '2026-08-17T09:00:00.000Z'
                reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.'
            }
        )
    }
    $document = Upsert-JobAgentJobSource -Document $document -JobSource $source
    Write-JobAgentStore -ProjectRoot $ProjectRoot -Document $document | Out-Null
}

$projectRoot = New-TestProjectRoot
try {
    New-TestStore -ProjectRoot $projectRoot

    $adapter = {
        param([object]$AdapterInput)

        switch ([string]$AdapterInput.company.company_id) {
            'company:alpha_ag' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @(
                    [pscustomobject]@{
                        title = 'Head of IT'
                        detail_url = 'https://alpha.example.invalid/careers/head-it-100'
                        external_job_id = '100'
                        ats_job_id = 'UNKNOWN'
                        location_label = 'Muenchen'
                        summary = 'IT-Gesamtverantwortung mit Strategie, Budget und Fuehrung.'
                        extraction_confidence = 95
                    }
                )
                break
            }
            'company:beta_ag' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @(
                    [pscustomobject]@{
                        title = 'Head of IT'
                        detail_url = 'https://beta.example.invalid/careers/head-it-200'
                        external_job_id = '200'
                        ats_job_id = 'UNKNOWN'
                        location_label = 'Muenchen'
                        summary = 'IT-Gesamtverantwortung mit Strategie und Personalverantwortung.'
                        extraction_confidence = 95
                    }
                )
                break
            }
            'company:gamma_ag' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status 'FAILED' -ErrorClass 'NOT_REACHABLE' -RetryRecommendation 'RETRY_NEXT_RUN' -HttpStatus 503
                break
            }
            default {
                throw "Unerwartete Firma im Test: $($AdapterInput.company.company_id)"
            }
        }
    }

    $first = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -StartedAt ([datetime]'2026-08-17T10:00:00Z') -MaxCompanies 3
    Assert-True -Condition ($first.status -eq 'PARTIAL') -Message 'Daily-Run mit isoliertem Firmenfehler muss PARTIAL sein.'
    Assert-True -Condition (Test-Path -LiteralPath $first.report_path) -Message 'Daily-Run-Report wurde nicht geschrieben.'
    Assert-True -Condition (Test-Path -LiteralPath $first.markdown_report_path) -Message 'Daily-Run-Markdown-Report wurde nicht geschrieben.'
    Assert-True -Condition (Test-Path -LiteralPath $first.html_report_path) -Message 'Daily-Run-HTML-Report wurde nicht geschrieben.'
    Assert-True -Condition (@($first.document.scan_runs).Count -eq 1) -Message 'ScanRun wurde nicht persistiert.'
    Assert-True -Condition (@($first.document.scan_attempts).Count -eq 3) -Message 'Nicht alle ScanAttempts wurden persistiert.'
    Assert-True -Condition (@($first.document.jobs).Count -eq 2) -Message 'Erfolgreiche Firmen haben keine Jobs erzeugt.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.status -eq 'NEW' }).Count -eq 2) -Message 'Erste Treffer sind nicht NEW.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.classification.result -eq 'MATCH' }).Count -eq 2) -Message 'Daily-Run klassifiziert Rohjobs nicht.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.job_validity.result -eq 'VALID' }).Count -eq 2) -Message 'Daily-Run speichert die offizielle Stellengueltigkeit nicht getrennt.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.regional_scope.result -eq 'IN_SCOPE' }).Count -eq 2) -Message 'Daily-Run speichert die Gebietsbewertung nicht getrennt.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.companies_total -eq 3) -Message 'ScanRun persistiert Firmen gesamt nicht.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.companies_selected -eq 3) -Message 'ScanRun persistiert Firmen im Lauf nicht.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.companies_due -eq 3) -Message 'ScanRun persistiert faellige Firmen nicht.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.companies_skipped -eq 0) -Message 'ScanRun persistiert uebersprungene Firmen falsch.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.limit -eq 3) -Message 'ScanRun persistiert Scanlimit nicht.'
    Assert-True -Condition ($first.document.scan_runs[0].selection_summary.selection_reason -eq 'due_by_next_scan_at_then_priority') -Message 'ScanRun persistiert Auswahlgrund nicht.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:gamma_ag').scan_status -eq 'FAILED') -Message 'Fehlerhafte Firma wurde nicht isoliert als FAILED markiert.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:alpha_ag').staleness_status -eq 'FRESH') -Message 'Erfolgreicher Daily-Run persistiert Freshness-Status nicht.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string](($first.document.companies | Where-Object company_id -eq 'company:alpha_ag').last_verified_at))) -Message 'Erfolgreicher Daily-Run persistiert last_verified_at nicht.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:gamma_ag').refresh_reason -eq 'last_scan_failed') -Message 'Fehlerhafter Daily-Run persistiert Refresh-Grund nicht.'
    Assert-True -Condition (($first.document.jobs | Where-Object company_id -eq 'company:alpha_ag').description -match 'IT-Gesamtverantwortung') -Message 'Daily-Run persistiert Stellenbeschreibung nicht am Job.'

    $second = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -StartedAt ([datetime]'2026-08-18T10:00:00Z') -CompanyIds @('company:alpha_ag', 'company:beta_ag', 'company:gamma_ag')
    Assert-True -Condition ($second.status -eq 'PARTIAL') -Message 'Zweiter Lauf mit einem Firmenfehler muss PARTIAL bleiben.'
    Assert-True -Condition (@($second.document.jobs).Count -eq 2) -Message 'Unveraenderter Folgelauf erzeugt Duplikate.'
    Assert-True -Condition (@($second.document.jobs | Where-Object { $_.status -eq 'ACTIVE' }).Count -eq 2) -Message 'Unveraenderter Folgelauf setzt bekannte Jobs nicht auf ACTIVE.'
    Assert-True -Condition (@($second.document.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Fehlerhafte Firma hat Stellen faelschlich entfernt.'
    Assert-True -Condition ($second.summary.statistics.errors -eq 1) -Message 'Report-Statistik zaehlt isolierten Fehler nicht.'

    $report = Get-Content -LiteralPath $second.report_path -Raw | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($report.statistics.companies_scanned -eq 3) -Message 'Report enthaelt falsche Firmenanzahl.'
    Assert-True -Condition ($report.statistics.companies_total -eq 3) -Message 'Report enthaelt Firmen gesamt nicht.'
    Assert-True -Condition ($report.statistics.companies_selected -eq 3) -Message 'Report enthaelt Firmen im Lauf nicht.'
    Assert-True -Condition ($report.statistics.companies_due -eq 3) -Message 'Report enthaelt faellige Firmen nicht.'
    Assert-True -Condition ($report.statistics.companies_skipped -eq 0) -Message 'Report enthaelt uebersprungene Firmen falsch.'
    Assert-True -Condition ($report.statistics.run_limit -eq 25) -Message 'Report enthaelt Limit nicht.'
    Assert-True -Condition ($report.statistics.selection_reason -eq 'explicit_company_ids') -Message 'Report enthaelt Auswahlgrund fuer CompanyIds nicht.'
    Assert-True -Condition ($report.statistics.checked_jobs -eq 2) -Message 'Report enthaelt falsche Anzahl gepruefter Stellen.'
    Assert-True -Condition ($report.statistics.snapshots -eq 2) -Message 'Report enthaelt falsche Snapshot-Anzahl.'
    Assert-True -Condition ($report.statistics.unreachable_career_pages -eq 1) -Message 'Report enthaelt falsche Anzahl nicht erreichbarer Karriereportale.'
    Assert-True -Condition ($report.html_report_path -eq $second.html_report_path) -Message 'Summary-JSON verliert den HTML-Report-Pfad.'
    $markdownReport = Get-Content -LiteralPath $second.markdown_report_path -Raw
    foreach ($expected in @('Firmen gesamt: 3', 'Firmen im Lauf: 3', 'Faellige Firmen: 3', 'Uebersprungene Firmen: 0', 'Limit: 25', 'Auswahlgrund: Explizite Firmenauswahl')) {
        Assert-True -Condition ($markdownReport.Contains($expected)) -Message "Markdown-Report enthaelt Auswahlmetrik nicht: $expected"
    }
    Assert-True -Condition ($markdownReport.Contains('## Aktive passende Stellen')) -Message 'Markdown-Report enthaelt keine aktiven passenden Stellen.'
    Assert-True -Condition ($markdownReport.Contains('IT-Gesamtverantwortung mit Strategie, Budget und Fuehrung.')) -Message 'Markdown-Report enthaelt keine Stellenbeschreibung.'
    Assert-True -Condition ($markdownReport.Contains('## Fehler und unsichere Quellen')) -Message 'Markdown-Report enthaelt keine Fehler-/Quellen-Sektion.'
    Assert-True -Condition ($markdownReport.Contains('[Quelle](https://gamma.example.invalid/careers)')) -Message 'Markdown-Report enthaelt keine klickbare offizielle Fehlerquelle.'
    Assert-True -Condition ($markdownReport.Contains('[Offizielle Stellen-URL](https://alpha.example.invalid/careers/head-it-100)')) -Message 'Markdown-Report enthaelt keinen klickbaren offiziellen Stellenlink.'
    Assert-True -Condition ($markdownReport.Contains('[Karriere-URL](https://alpha.example.invalid/careers)')) -Message 'Markdown-Report enthaelt keine klickbare Karriere-URL-Spalte.'
    Assert-True -Condition ($markdownReport.Contains('[Karriere](https://alpha.example.invalid/careers)')) -Message 'Markdown-Report enthaelt keinen klickbaren Anbieterlink.'
    $htmlReport = Get-Content -LiteralPath $second.html_report_path -Raw
    foreach ($expected in @('Firmen gesamt', 'Firmen im Lauf', 'Faellige Firmen', 'Uebersprungene Firmen', 'Limit', 'Auswahlgrund', 'Explizite Firmenauswahl')) {
        Assert-True -Condition ($htmlReport.Contains($expected)) -Message "HTML-Report enthaelt Auswahlmetrik nicht: $expected"
    }
    Assert-True -Condition ($htmlReport.Contains('<h2>Aktive passende Stellen</h2>')) -Message 'HTML-Report enthaelt keine aktiven passenden Stellen.'
    Assert-True -Condition ($htmlReport.Contains('IT-Gesamtverantwortung mit Strategie, Budget und Fuehrung.')) -Message 'HTML-Report enthaelt keine Stellenbeschreibung.'
    Assert-True -Condition ($htmlReport.Contains('<h2>Fehler und unsichere Quellen</h2>')) -Message 'HTML-Report enthaelt keine Fehler-/Quellen-Sektion.'
    Assert-True -Condition ($htmlReport.Contains('href="https://gamma.example.invalid/careers" target="_blank" rel="noopener noreferrer">Quelle</a>')) -Message 'HTML-Report enthaelt keine sichere klickbare Fehlerquelle.'
    Assert-True -Condition ($htmlReport.Contains('href="https://alpha.example.invalid/careers/head-it-100" target="_blank" rel="noopener noreferrer">Offizielle Stellen-URL</a>')) -Message 'HTML-Report enthaelt keinen sicheren offiziellen Stellenlink.'
    Assert-True -Condition ($htmlReport.Contains('href="https://alpha.example.invalid/careers" target="_blank" rel="noopener noreferrer">Karriere-URL</a>')) -Message 'HTML-Report enthaelt keine sichere Karriere-URL-Spalte.'
    Assert-True -Condition ($htmlReport.Contains('href="https://alpha.example.invalid/careers" target="_blank" rel="noopener noreferrer">Karriere</a>')) -Message 'HTML-Report enthaelt keinen sicheren Anbieterlink.'
    Assert-True -Condition (@($second.document.scan_runs[0].artifact_paths).Count -eq 3) -Message 'ScanRun-Artefakte muessen JSON, Markdown und HTML enthalten.'

    $cliProjectRoot = New-TestProjectRoot
    New-TestStore -ProjectRoot $cliProjectRoot
    $fixturePath = Join-Path $cliProjectRoot 'daily-fixture.json'
    [pscustomobject]@{
        'company:alpha_ag' = [pscustomobject]@{
            status = 'SUCCESS'
            error_class = 'NONE'
            retry_recommendation = 'NONE'
            http_status = 200
            raw_jobs = @([pscustomobject]@{
                    title = 'Head of IT'
                    detail_url = 'https://alpha.example.invalid/careers/head-it-cli'
                    external_job_id = 'cli-100'
                    ats_job_id = 'UNKNOWN'
                    location_label = 'Muenchen'
                    summary = 'IT-Gesamtverantwortung mit Strategie und Budget.'
                    extraction_confidence = 95
                })
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixturePath -Encoding UTF8
    $cliOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -ProjectRoot $cliProjectRoot -FixturePath $fixturePath -CompanyIds 'company:alpha_ag' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Daily-Run-CLI ist fehlgeschlagen: " + ($cliOutput -join "`n"))
    $cliResult = ($cliOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($cliResult.status -eq 'SUCCESS') -Message 'Daily-Run-CLI liefert keinen SUCCESS-Status.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$cliResult.report_path)) -Message 'Daily-Run-CLI schreibt kein Reportartefakt.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$cliResult.html_report_path)) -Message 'Daily-Run-CLI schreibt kein HTML-Artefakt.'

    $cliLiveProjectRoot = New-TestProjectRoot
    $cliLiveOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -ProjectRoot $cliLiveProjectRoot -MaxCompanies 1 -MaxResultsPerSource 2 -MaxDetailFetchesPerSource 2 -MaxPagesPerSource 2 -MaxRetries 0 -FetchClient curl -WslDistribution FixtureDistro 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Daily-Run-CLI-Live-Modus ohne Fixture ist fehlgeschlagen: " + ($cliLiveOutput -join "`n"))
    $cliLiveResult = ($cliLiveOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($cliLiveResult.adapter_mode -eq 'live') -Message 'Daily-Run-CLI waehlt ohne Fixture nicht den Live-Modus.'
    Assert-True -Condition ($cliLiveResult.fetch_client -eq 'curl' -and $cliLiveResult.wsl_distribution -eq 'FixtureDistro') -Message 'Daily-Run-CLI dokumentiert Fetch-Client-/WSL-Policy nicht.'
    Assert-True -Condition ($cliLiveResult.status -eq 'SKIPPED') -Message 'Daily-Run-CLI-Live-Modus mit leerem Store liefert keinen kontrollierten SKIPPED-Status.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$cliLiveResult.report_path)) -Message 'Daily-Run-CLI-Live-Modus schreibt kein Reportartefakt.'

    $acquisitionProjectRoot = New-TestProjectRoot
    New-Item -ItemType Directory -Path (Join-Path $acquisitionProjectRoot 'data\jobagent') -Force | Out-Null
    $emptyAcquisitionDocument = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
    Write-JobAgentStore -ProjectRoot $acquisitionProjectRoot -Document $emptyAcquisitionDocument | Out-Null
    $acquisitionObservedAt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = $acquisitionObservedAt
        hints_total = 1
        unverified_hints = 1
        hints = @(
            [pscustomobject]@{
                hint_id = 'hint:daily-acquisition-example'
                employer_name = 'Example AG'
                normalized_name = 'example ag'
                location = 'Muenchen'
                target_area = 'MUNICH'
                source_id = 'source-registry:daily-acquisition-fixture'
                observed_url = 'https://jobs.example.invalid/search'
                observed_at = $acquisitionObservedAt
                verification_status = 'UNVERIFIED'
                candidate_status = 'DISCOVERY_HINT'
                known_company_id = 'company:example_ag'
                known_company_domain = 'example.invalid'
                confidence_score = 90
                is_staffing_agency = $false
                official_verification_required = $true
                next_action = 'verify_official_company_website_or_career_url'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $acquisitionProjectRoot 'data\jobagent\company-discovery.hints.json') -Encoding UTF8
    $acquisitionFixtureMap = [pscustomobject]@{
        responses = @(
            [pscustomobject]@{ url = 'https://example.invalid/'; ok = $true; status_code = 200; final_url = 'https://example.invalid/'; content = '<html><a href="/karriere">Karriere</a></html>' },
            [pscustomobject]@{ url = 'https://example.invalid/sitemap.xml'; ok = $true; status_code = 200; final_url = 'https://example.invalid/sitemap.xml'; content = '<urlset></urlset>' },
            [pscustomobject]@{ url = 'https://example.invalid/sitemap_index.xml'; ok = $true; status_code = 200; final_url = 'https://example.invalid/sitemap_index.xml'; content = '<sitemapindex></sitemapindex>' },
            [pscustomobject]@{ url = 'https://example.invalid/karriere'; ok = $true; status_code = 200; final_url = 'https://example.invalid/karriere'; content = '<main>Offene Stellen bei Example</main>' }
        )
    }
    $acquisitionFixtureMap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $acquisitionProjectRoot 'acquisition-fixture-map.json') -Encoding UTF8
    [pscustomobject]@{
        'company:example_ag' = [pscustomobject]@{
            status = 'SUCCESS'
            error_class = 'NONE'
            retry_recommendation = 'NONE'
            http_status = 200
            raw_jobs = @(
                [pscustomobject]@{
                    title = 'Head of IT'
                    detail_url = 'https://example.invalid/karriere/head-it-acquired'
                    external_job_id = 'acquired-100'
                    ats_job_id = 'UNKNOWN'
                    location_label = 'Muenchen'
                    summary = 'IT-Gesamtverantwortung nach automatischer Akquise.'
                    extraction_confidence = 95
                }
                [pscustomobject]@{
                    title = 'Finanzbuchhalter (m/w/d)'
                    detail_url = 'https://example.invalid/karriere/finanzbuchhaltung-acquired'
                    external_job_id = 'acquired-200'
                    ats_job_id = 'UNKNOWN'
                    location_label = 'Freising'
                    summary = 'Berufsneutrale Erfassung einer Finanzbuchhaltungsstelle.'
                    extraction_confidence = 95
                }
            )
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $acquisitionProjectRoot 'daily-scan-fixture.json') -Encoding UTF8

    $acquisitionOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -ProjectRoot $acquisitionProjectRoot -FixturePath (Join-Path $acquisitionProjectRoot 'daily-scan-fixture.json') -AcquisitionFixtureMapPath 'acquisition-fixture-map.json' -AcquisitionCandidateBudget 1 -MaxCompanies 1 -FetchClient curl -WslDistribution FixtureDistro 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Daily-Run-CLI mit automatischer Akquise ist fehlgeschlagen: " + ($acquisitionOutput -join "`n"))
    $acquisitionResult = ($acquisitionOutput -join "`n") | ConvertFrom-Json -Depth 100
    $acquisitionStore = Read-JobAgentStore -ProjectRoot $acquisitionProjectRoot
    Assert-True -Condition ($acquisitionResult.acquisition.status -eq 'COMPLETED') -Message 'Daily-Run-CLI fuehrt Akquisephase nicht automatisch aus.'
    Assert-True -Condition ($acquisitionResult.acquisition.new_official_career_companies -eq 1) -Message ('Daily-Run-CLI zaehlt neuen offiziellen Karrierearbeitgeber nicht: ' + ($acquisitionResult.acquisition | ConvertTo-Json -Depth 20 -Compress))
    Assert-True -Condition (@($acquisitionStore.companies | Where-Object { $_.company_id -eq 'company:example_ag' -and $_.verification_status -eq 'CAREER_URL_VERIFIED' }).Count -eq 1) -Message 'Automatische Akquise schreibt verifizierte Firma nicht in den Store.'
    Assert-True -Condition (@($acquisitionStore.job_sources | Where-Object { $_.company_id -eq 'company:example_ag' -and $_.is_official -eq $true }).Count -eq 1) -Message 'Automatische Akquise schreibt offizielle Karrierequelle nicht in den Store.'
    Assert-True -Condition (@($acquisitionStore.jobs | Where-Object { $_.company_id -eq 'company:example_ag' }).Count -eq 2) -Message 'Daily-Run scannt automatisch akquirierte Firma nicht berufsneutral im selben Lauf.'
    $acquisitionHtml = Get-Content -LiteralPath ([string]$acquisitionResult.html_report_path) -Raw
    Assert-True -Condition ($acquisitionHtml.Contains('<section><h2>Neue Unternehmen</h2>') -and $acquisitionHtml.Contains('<td>Example AG</td>') -and $acquisitionHtml.Contains('href="https://example.invalid/karriere" target="_blank" rel="noopener noreferrer">Karriere</a>')) -Message 'WebIF zeigt automatisch akquirierte Firma nicht mit Karrierequelle an.'

    $partialAcquisitionOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -ProjectRoot $acquisitionProjectRoot -FixturePath (Join-Path $acquisitionProjectRoot 'daily-scan-fixture.json') -AcquisitionFixtureMapPath 'missing-fixture-map.json' -AcquisitionCandidateBudget 1 -MaxCompanies 1 -CompanyIds 'company:example_ag' -FetchClient curl -WslDistribution FixtureDistro 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Daily-Run-CLI muss bei isoliertem Akquisefehler weiter scannen: " + ($partialAcquisitionOutput -join "`n"))
    $partialAcquisitionResult = ($partialAcquisitionOutput -join "`n") | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($partialAcquisitionResult.status -eq 'PARTIAL') -Message 'Isolierter Akquisefehler wird nicht als PARTIAL sichtbar.'
    Assert-True -Condition ($partialAcquisitionResult.run_id -match '^dailyrun:') -Message 'Daily-Run-CLI gibt keine gemeinsame Run-ID aus.'
    Assert-True -Condition ($partialAcquisitionResult.acquisition.status -eq 'PARTIAL') -Message 'Akquisefehler wird nicht im Akquisestatus ausgewiesen.'
    Assert-True -Condition (@((Read-JobAgentStore -ProjectRoot $acquisitionProjectRoot).jobs | Where-Object { $_.company_id -eq 'company:example_ag' }).Count -eq 2) -Message 'Isolierter Akquisefehler darf vorhandene Stellen nicht entfernen.'

    $secondHintStorePath = Join-Path $acquisitionProjectRoot 'data\jobagent\company-discovery.hints.json'
    $secondHintStore = Get-Content -LiteralPath $secondHintStorePath -Raw | ConvertFrom-Json -Depth 20
    $secondHintStore.hints += [pscustomobject]@{
        hint_id = 'hint:daily-acquisition-second-example'
        employer_name = 'Second Example GmbH'
        normalized_name = 'second example gmbh'
        location = 'Freising'
        target_area = 'FREISING'
        source_id = 'source-registry:daily-acquisition-fixture'
        observed_url = 'https://jobs.second-example.invalid/search'
        observed_at = $acquisitionObservedAt
        verification_status = 'UNVERIFIED'
        candidate_status = 'DISCOVERY_HINT'
        known_company_id = 'company:second_example_gmbh'
        known_company_domain = 'second-example.invalid'
        confidence_score = 90
        is_staffing_agency = $false
        official_verification_required = $true
        next_action = 'verify_official_company_website_or_career_url'
    }
    $secondHintStore.hints_total = @($secondHintStore.hints).Count
    $secondHintStore.unverified_hints = @($secondHintStore.hints | Where-Object { $_.verification_status -eq 'UNVERIFIED' }).Count
    $secondHintStore | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $secondHintStorePath -Encoding UTF8
    $acquisitionFixtureMap.responses += @(
        [pscustomobject]@{ url = 'https://second-example.invalid/'; ok = $true; status_code = 200; final_url = 'https://second-example.invalid/'; content = '<html><a href="/jobs">Jobs</a></html>' }
        [pscustomobject]@{ url = 'https://second-example.invalid/sitemap.xml'; ok = $true; status_code = 200; final_url = 'https://second-example.invalid/sitemap.xml'; content = '<urlset></urlset>' }
        [pscustomobject]@{ url = 'https://second-example.invalid/sitemap_index.xml'; ok = $true; status_code = 200; final_url = 'https://second-example.invalid/sitemap_index.xml'; content = '<sitemapindex></sitemapindex>' }
        [pscustomobject]@{ url = 'https://second-example.invalid/jobs'; ok = $true; status_code = 200; final_url = 'https://second-example.invalid/jobs'; content = '<main>Offene Stellen bei Second Example</main>' }
    )
    $acquisitionFixtureMap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $acquisitionProjectRoot 'acquisition-fixture-map.json') -Encoding UTF8
    $secondDailyFixturePath = Join-Path $acquisitionProjectRoot 'daily-scan-second-fixture.json'
    [pscustomobject]@{
        'company:example_ag' = [pscustomobject]@{
            status = 'SUCCESS'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200
            raw_jobs = @(
                [pscustomobject]@{ title = 'Head of IT'; detail_url = 'https://example.invalid/karriere/head-it-acquired'; external_job_id = 'acquired-100'; ats_job_id = 'UNKNOWN'; location_label = 'Muenchen'; summary = 'IT-Gesamtverantwortung nach automatischer Akquise.'; extraction_confidence = 95 }
                [pscustomobject]@{ title = 'Finanzbuchhalter (m/w/d)'; detail_url = 'https://example.invalid/karriere/finanzbuchhaltung-acquired'; external_job_id = 'acquired-200'; ats_job_id = 'UNKNOWN'; location_label = 'Freising'; summary = 'Berufsneutrale Erfassung einer Finanzbuchhaltungsstelle.'; extraction_confidence = 95 }
            )
        }
        'company:second_example_gmbh' = [pscustomobject]@{
            status = 'SUCCESS'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200
            raw_jobs = @([pscustomobject]@{ title = 'Pflegefachkraft (m/w/d)'; detail_url = 'https://second-example.invalid/jobs/pflege-300'; external_job_id = 'second-300'; ats_job_id = 'UNKNOWN'; location_label = 'Freising'; summary = 'Berufsneutrale neue Stelle der zweiten Firma.'; extraction_confidence = 95 })
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $secondDailyFixturePath -Encoding UTF8
    $secondAcquisitionOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -ProjectRoot $acquisitionProjectRoot -FixturePath $secondDailyFixturePath -AcquisitionFixtureMapPath 'acquisition-fixture-map.json' -AcquisitionCandidateBudget 2 -MaxCompanies 1 -CompanyIds 'company:example_ag' -FetchClient curl -WslDistribution FixtureDistro 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Zweiter regulaerer Akquise-Start ist fehlgeschlagen: " + ($secondAcquisitionOutput -join "`n"))
    $secondAcquisitionResult = ($secondAcquisitionOutput -join "`n") | ConvertFrom-Json -Depth 100
    $secondAcquisitionStore = Read-JobAgentStore -ProjectRoot $acquisitionProjectRoot
    Assert-True -Condition ($secondAcquisitionResult.status -eq 'SUCCESS') -Message 'Zweiter regulaerer Akquise-Start ist nicht erfolgreich.'
    Assert-True -Condition ($secondAcquisitionResult.acquisition.new_official_career_companies -eq 1) -Message 'Zweiter Start darf genau eine neue offizielle Karrierefirma zaehlen.'
    Assert-True -Condition (@($secondAcquisitionStore.companies | Where-Object { $_.company_id -eq 'company:example_ag' }).Count -eq 1) -Message 'Bekannte Firma wurde beim zweiten Start dupliziert.'
    Assert-True -Condition (@($secondAcquisitionStore.companies | Where-Object { $_.company_id -eq 'company:second_example_gmbh' -and $_.verification_status -eq 'CAREER_URL_VERIFIED' }).Count -eq 1) -Message 'Zweiter Start uebernimmt die neue offizielle Karrierefirma nicht.'
    Assert-True -Condition (@($secondAcquisitionStore.jobs | Where-Object { $_.company_id -eq 'company:example_ag' }).Count -eq 2) -Message 'Bekannte Firma erzeugt beim zweiten Start Stellenduplikate.'
    Assert-True -Condition (@($secondAcquisitionStore.jobs | Where-Object { $_.company_id -eq 'company:second_example_gmbh' }).Count -eq 1) -Message ('Zweiter Start erfasst die neue Firma nicht im selben Lauf. Vorhandene Jobs: ' + (@($secondAcquisitionStore.jobs | ForEach-Object { $_.company_id + '/' + $_.external_job_id }) -join ', '))
    $secondAcquisitionHtml = Get-Content -LiteralPath ([string]$secondAcquisitionResult.html_report_path) -Raw
    Assert-True -Condition ($secondAcquisitionHtml.Contains('Second Example GmbH') -and $secondAcquisitionHtml.Contains('Pflegefachkraft (m/w/d)')) -Message 'WebIF zeigt die neue Firma und ihre berufsneutrale Stelle nicht.'

    $multiSourceProjectRoot = New-TestProjectRoot
    New-TestStore -ProjectRoot $multiSourceProjectRoot
    Add-TestSource -ProjectRoot $multiSourceProjectRoot -CompanyId 'company:alpha_ag' -SourceId 'source:alpha_ag_ats' -Url 'https://jobs.alpha.example.invalid/search'
    $multiSourceAdapter = {
        param([object]$AdapterInput)

        if ([string]$AdapterInput.company.company_id -ne 'company:alpha_ag') {
            return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status 'SKIPPED' -ErrorClass 'TECHNICAL_LIMITATION' -RetryRecommendation 'MANUAL_REVIEW' -HttpStatus $null
        }

        switch ([string]$AdapterInput.source.source_id) {
            'source:alpha_ag_career' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @(
                    [pscustomobject]@{
                        title = 'Head of IT'
                        detail_url = 'https://alpha.example.invalid/careers/head-it-300'
                        external_job_id = '300'
                        ats_job_id = 'UNKNOWN'
                        location_label = 'Muenchen'
                        summary = 'Karriereseiten-Treffer.'
                        extraction_confidence = 95
                    }
                )
                break
            }
            'source:alpha_ag_ats' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @(
                    [pscustomobject]@{
                        title = 'Head of IT'
                        detail_url = 'https://jobs.alpha.example.invalid/posting/ats-301'
                        external_job_id = 'ats-301'
                        ats_job_id = 'ats-301'
                        location_label = 'Muenchen'
                        summary = 'ATS-Treffer.'
                        extraction_confidence = 95
                    }
                )
                break
            }
            default {
                throw "Unerwartete Quelle im Multi-Source-Test: $($AdapterInput.source.source_id)"
            }
        }
    }
    $multiSourceFirst = Invoke-JobAgentDailyRun -ProjectRoot $multiSourceProjectRoot -AdapterResolver $multiSourceAdapter -StartedAt ([datetime]'2026-08-19T10:00:00Z') -CompanyIds @('company:alpha_ag')
    Assert-True -Condition (@($multiSourceFirst.document.jobs).Count -eq 2) -Message 'Multi-Source-Initiallauf legt nicht beide Quelljobs an.'

    $multiSourceFollowUpAdapter = {
        param([object]$AdapterInput)

        if ([string]$AdapterInput.company.company_id -ne 'company:alpha_ag') {
            return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status 'SKIPPED' -ErrorClass 'TECHNICAL_LIMITATION' -RetryRecommendation 'MANUAL_REVIEW' -HttpStatus $null
        }

        switch ([string]$AdapterInput.source.source_id) {
            'source:alpha_ag_career' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status 'FAILED' -ErrorClass 'TIMEOUT' -RetryRecommendation 'RETRY_NEXT_RUN' -HttpStatus 504
                break
            }
            'source:alpha_ag_ats' {
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -CompleteEmptyResult
                break
            }
            default {
                throw "Unerwartete Quelle im Multi-Source-Follow-up-Test: $($AdapterInput.source.source_id)"
            }
        }
    }
    $multiSourceSecond = Invoke-JobAgentDailyRun -ProjectRoot $multiSourceProjectRoot -AdapterResolver $multiSourceFollowUpAdapter -StartedAt ([datetime]'2026-08-20T10:00:00Z') -CompanyIds @('company:alpha_ag')
    $careerJob = @($multiSourceSecond.document.jobs | Where-Object { [string]$_.source_id -eq 'source:alpha_ag_career' })[0]
    $atsJob = @($multiSourceSecond.document.jobs | Where-Object { [string]$_.source_id -eq 'source:alpha_ag_ats' })[0]
    Assert-True -Condition ($careerJob.status -ne 'REMOVED') -Message 'Fehlgeschlagene Parallelquelle hat den Karriere-Job faelschlich entfernt.'
    Assert-True -Condition ($atsJob.status -eq 'REMOVED') -Message 'Erfolgreich leere Parallelquelle hat den eigenen ATS-Job nicht entfernt.'

    $refreshProjectRoot = New-TestProjectRoot
    New-TestStore -ProjectRoot $refreshProjectRoot
    $refreshDocument = Read-JobAgentStore -ProjectRoot $refreshProjectRoot
    foreach ($company in @($refreshDocument.companies)) {
        if ([string]$company.company_id -eq 'company:gamma_ag') {
            $company | Add-Member -NotePropertyName next_refresh_at -NotePropertyValue '2026-08-17T08:00:00.000Z' -Force
            $company | Add-Member -NotePropertyName last_verified_at -NotePropertyValue '2026-07-01T08:00:00.000Z' -Force
        }
        else {
            $company | Add-Member -NotePropertyName next_refresh_at -NotePropertyValue '2026-08-20T08:00:00.000Z' -Force
            $company | Add-Member -NotePropertyName last_verified_at -NotePropertyValue '2026-08-17T08:00:00.000Z' -Force
        }
    }
    Write-JobAgentStore -ProjectRoot $refreshProjectRoot -Document $refreshDocument | Out-Null
    $refreshCandidates = @(Get-JobAgentDailyRunCandidateCompanies -Document (Read-JobAgentStore -ProjectRoot $refreshProjectRoot) -Now ([datetime]'2026-08-17T10:00:00Z') -MaxCompanies 1)
    Assert-True -Condition ($refreshCandidates[0].company_id -eq 'company:gamma_ag') -Message 'Daily-Run priorisiert faellige next_refresh_at-Firmen nicht.'
    $refreshSelection = New-JobAgentDailyRunSelection -Document (Read-JobAgentStore -ProjectRoot $refreshProjectRoot) -Now ([datetime]'2026-08-17T10:00:00Z') -MaxCompanies 1
    Assert-True -Condition ($refreshSelection.summary.companies_total -eq 3) -Message 'Selection-Summary zaehlt Firmen gesamt falsch.'
    Assert-True -Condition ($refreshSelection.summary.companies_selected -eq 1) -Message 'Selection-Summary zaehlt ausgewaehlte Firmen falsch.'
    Assert-True -Condition ($refreshSelection.summary.companies_skipped -eq 2) -Message 'Selection-Summary zaehlt uebersprungene Firmen falsch.'
    Assert-True -Condition (@($refreshSelection.summary.skipped | Where-Object reason -eq 'limit_reached').Count -eq 2) -Message 'Selection-Summary dokumentiert Limit-Uebersprungene nicht.'

    $liveProjectRoot = New-TestProjectRoot
    $liveDocument = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
    $liveCompany = New-TestCompany -Name 'Example AG' -Domain 'example.invalid' -Priority 95
    $liveCompany.ats = @(
        [pscustomobject]@{
            system = 'Workday'
            official_domain = 'myworkdayjobs.invalid'
            verified_by_url = 'https://example.invalid/careers'
        }
    )
    $liveDocument = Upsert-JobAgentCompany -Document $liveDocument -Company $liveCompany
    $liveDocument = Upsert-JobAgentJobSource -Document $liveDocument -JobSource ([pscustomobject]@{
            source_id = 'source:example_ag_ats'
            company_id = 'company:example_ag'
            source_type = 'OFFICIAL_ATS'
            url = 'https://example.myworkdayjobs.invalid/en-US/search'
            canonical_url = 'https://example.myworkdayjobs.invalid/en-US/search'
            is_official = $true
            verified_at = '2026-08-17T09:00:00.000Z'
            verification_basis = 'COMPANY_LINKED_ATS'
            verification_evidence = @(
                [pscustomobject]@{
                    status = 'VERIFIED'
                    evidence_type = 'COMPANY_LINKED_ATS'
                    url = 'https://example.myworkdayjobs.invalid/en-US/search'
                    basis_url = 'https://example.invalid/careers'
                    redirect_chain = @()
                    observed_at = '2026-08-17T09:00:00.000Z'
                    reason = 'ATS-Domain ist ueber die offizielle Karriere-URL belegt.'
                },
                [pscustomobject]@{
                    status = 'VERIFIED'
                    evidence_type = 'ATS_VERIFIED_BY_URL'
                    url = 'https://example.invalid/careers'
                    basis_url = 'https://example.invalid/careers'
                    redirect_chain = @()
                    observed_at = '2026-08-17T09:00:00.000Z'
                    reason = 'Die ATS-Domain ist ueber die offizielle Firmen- oder Karriere-URL belegt.'
                }
            )
        })
    Write-JobAgentStore -ProjectRoot $liveProjectRoot -Document $liveDocument | Out-Null
    $livePolicy = New-JobAgentLiveScanPolicy -TimeoutSeconds 10 -MaxRetries 0 -MaxResultsPerSource 5 -MaxDetailFetchesPerSource 2 -SearchTerms @('Director IT')
    $liveJsonLd = @'
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "JobPosting",
        "title": "Director IT",
        "url": "https://example.myworkdayjobs.invalid/job/director-it-001?source=linkedin",
        "identifier": { "@type": "PropertyValue", "value": "WD-001" },
        "employmentType": "FULL_TIME",
        "description": "<p>Strategische IT-Leitung mit Standort Muenchen.</p>",
        "jobLocation": {
          "@type": "Place",
          "address": { "@type": "PostalAddress", "addressLocality": "Muenchen" }
        }
      }
    </script>
  </head>
</html>
'@
    $liveAdapter = {
        param([object]$AdapterInput)

        $fetcher = {
            param([string]$Url, [object]$Policy, [int]$Attempt)

            switch ($Url) {
                'https://example.myworkdayjobs.invalid/en-US/search' {
                    [pscustomobject]@{
                        ok = $true
                        url = $Url
                        final_url = $Url
                        status_code = 200
                        content = $liveJsonLd
                        content_type = 'text/html'
                        started_at = '2026-08-17T10:00:00.000Z'
                        finished_at = '2026-08-17T10:00:01.000Z'
                        error = $null
                    }
                    break
                }
                'https://example.myworkdayjobs.invalid/job/director-it-001' {
                    [pscustomobject]@{
                        ok = $true
                        url = $Url
                        final_url = $Url
                        status_code = 200
                        content = '<main><h1>Director IT</h1><p>Strategische IT-Leitung mit Standort Muenchen.</p></main>'
                        content_type = 'text/html'
                        started_at = '2026-08-17T10:00:01.000Z'
                        finished_at = '2026-08-17T10:00:02.000Z'
                        error = $null
                    }
                    break
                }
                default {
                    [pscustomobject]@{
                        ok = $false
                        url = $Url
                        final_url = $Url
                        status_code = 404
                        content = ''
                        content_type = 'text/html'
                        started_at = '2026-08-17T10:00:00.000Z'
                        finished_at = '2026-08-17T10:00:01.000Z'
                        error = 'not found'
                    }
                    break
                }
            }
        }

        Invoke-JobAgentLiveHtmlAdapter -AdapterInput $AdapterInput -Policy $livePolicy -Fetcher $fetcher
    }
    $liveRun = Invoke-JobAgentDailyRun -ProjectRoot $liveProjectRoot -AdapterResolver $liveAdapter -StartedAt ([datetime]'2026-08-21T10:00:00Z') -CompanyIds @('company:example_ag')
    $liveJob = @($liveRun.document.jobs | Where-Object { [string]$_.company_id -eq 'company:example_ag' })[0]
    Assert-True -Condition ($liveRun.status -eq 'SUCCESS') -Message 'Live-Daily-Run mit JSON-LD/ATS sollte erfolgreich sein.'
    Assert-True -Condition ($liveJob.ats_job_id -eq 'WD-001') -Message 'Live-Daily-Run uebernimmt ATS-ID aus JSON-LD nicht.'
    Assert-True -Condition ($liveJob.location.target_area -eq 'MUNICH') -Message 'Live-Daily-Run uebernimmt JSON-LD-Standort nicht.'
    Assert-True -Condition ($liveJob.employment_type -eq 'FULL_TIME') -Message 'Live-Daily-Run uebernimmt employmentType aus JSON-LD nicht.'
    Assert-True -Condition ($liveJob.description -match 'Strategische IT-Leitung') -Message 'Live-Daily-Run uebernimmt offizielle Beschreibung nicht.'

    $neutralProjectRoot = New-TestProjectRoot
    New-TestStore -ProjectRoot $neutralProjectRoot
    Add-TestSource -ProjectRoot $neutralProjectRoot -CompanyId 'company:alpha_ag' -SourceId 'source:alpha_ag_neutral' -Url 'https://alpha.example.invalid/careers/neutral'
    $neutralRawJobs = [System.Collections.Generic.List[object]]::new()
    $neutralRoles = @(
        [pscustomobject]@{ slug = 'it-leitung'; title = 'Head of IT'; summary = 'IT-Gesamtverantwortung mit Strategie, Budget und Personalverantwortung.'; profile = 'MATCH' }
        [pscustomobject]@{ slug = 'buchhaltung'; title = 'Finanzbuchhalter (m/w/d)'; summary = 'Bearbeitung der laufenden Buchhaltung.'; profile = 'REJECTED' }
        [pscustomobject]@{ slug = 'pflege'; title = 'Pflegefachkraft (m/w/d)'; summary = 'Stationaere Pflege und Betreuung.'; profile = 'REJECTED' }
        [pscustomobject]@{ slug = 'ausbildung'; title = 'Ausbildung Kaufmann (m/w/d)'; summary = 'Ausbildung im kaufmaennischen Bereich.'; profile = 'REJECTED' }
    )
    $neutralLocations = @(
        [pscustomobject]@{ slug = 'muenchen'; label = 'Muenchen'; target_area = 'MUNICH'; scope = 'IN_SCOPE' }
        [pscustomobject]@{ slug = 'freising'; label = 'Freising'; target_area = 'FREISING'; scope = 'IN_SCOPE' }
        [pscustomobject]@{ slug = 'outside'; label = 'Hamburg'; target_area = 'OUT_OF_SCOPE'; scope = 'OUT_OF_SCOPE' }
        [pscustomobject]@{ slug = 'unknown'; label = 'UNKNOWN'; target_area = 'UNKNOWN'; scope = 'UNKNOWN' }
    )
    foreach ($role in $neutralRoles) {
        foreach ($location in $neutralLocations) {
            $id = "$($role.slug)-$($location.slug)"
            $neutralRawJobs.Add([pscustomobject]@{
                    title = $role.title
                    detail_url = "https://alpha.example.invalid/careers/$id"
                    external_job_id = $id
                    ats_job_id = 'UNKNOWN'
                    location_label = $location.label
                    location = [pscustomobject]@{ label = $location.label; city = $location.label; region = 'UNKNOWN'; country = 'DE'; target_area = $location.target_area }
                    summary = $role.summary
                    extraction_confidence = 95
                })
        }
    }
    $neutralRawJobs.Add([pscustomobject]@{
            title = 'Karriere'
            detail_url = 'https://alpha.example.invalid/careers'
            external_job_id = 'navigation'
            ats_job_id = 'UNKNOWN'
            location_label = 'Muenchen'
            entry_kind = 'NAVIGATION'
            summary = 'Navigation zur Karriereseite.'
            extraction_confidence = 95
        })
    $neutralMode = 'complete'
    $neutralAdapter = {
        param([object]$AdapterInput)

        $status = if ($neutralMode -eq 'partial') { 'PARTIAL' } else { 'SUCCESS' }
        $errorClass = if ($neutralMode -eq 'partial') { 'TECHNICAL_LIMITATION' } else { 'NONE' }
        Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs $neutralRawJobs.ToArray() -Status $status -ErrorClass $errorClass -RetryRecommendation $(if ($neutralMode -eq 'partial') { 'RETRY_NEXT_RUN' } else { 'NONE' }) -HttpStatus 200
    }
    $neutralFirst = Invoke-JobAgentDailyRun -ProjectRoot $neutralProjectRoot -AdapterResolver $neutralAdapter -StartedAt ([datetime]'2026-08-22T10:00:00Z') -CompanyIds @('company:alpha_ag')
    Assert-True -Condition ($neutralFirst.status -eq 'SUCCESS') -Message 'Berufsneutraler Fixture-Lauf muss bei vollstaendiger Quelle SUCCESS sein.'
    Assert-True -Condition (@($neutralFirst.document.jobs).Count -eq 16) -Message 'Berufsneutrale Erfassung muss alle 16 Rollen-/Gebietsfixturen persistieren.'
    Assert-True -Condition (@($neutralFirst.document.jobs | Where-Object { $_.external_job_id -eq 'navigation' }).Count -eq 0) -Message 'Explizite Nicht-Stelle darf nicht persistiert werden.'
    foreach ($role in $neutralRoles) {
        foreach ($location in $neutralLocations) {
            $job = @($neutralFirst.document.jobs | Where-Object { $_.external_job_id -eq "$($role.slug)-$($location.slug)" })[0]
            Assert-True -Condition ($null -ne $job) -Message "Berufsneutrale Fixture fehlt: $($role.slug)/$($location.slug)"
            Assert-True -Condition ($job.job_validity.result -eq 'VALID') -Message "Gueltige Stelle wurde verworfen: $($role.slug)/$($location.slug)"
            Assert-True -Condition ($job.regional_scope.result -eq $location.scope) -Message "Gebietsbewertung ist falsch: $($role.slug)/$($location.slug)"
            Assert-True -Condition ($job.classification.result -eq $role.profile) -Message "Profilbewertung ist falsch: $($role.slug)/$($location.slug)"
        }
    }
    Assert-True -Condition ($neutralFirst.summary.statistics.captured_jobs_total -eq 16) -Message 'Erfasste Stellen und Profiltreffer werden nicht getrennt gezaehlt.'
    Assert-True -Condition ($neutralFirst.summary.statistics.profile_matching_jobs_total -eq 4) -Message 'Profiltrefferzahl des neutralen Bestands ist falsch.'
    $neutralMarkdown = Get-Content -LiteralPath $neutralFirst.markdown_report_path -Raw
    Assert-True -Condition ($neutralMarkdown.Contains('Scope: ALL_ROLES')) -Message 'Runmanifest dokumentiert den berufsneutralen Erfassungsscope nicht.'
    Assert-True -Condition ($neutralMarkdown.Contains('Erfasste Stellen gesamt | 16')) -Message 'Runmanifest weist die vollstaendige Erfassungsmenge nicht aus.'
    Assert-True -Condition ($neutralMarkdown.Contains('Profiltreffer gesamt | 4')) -Message 'Runmanifest weist die Profiltrefferzahl nicht getrennt aus.'

    $neutralEventCount = @($neutralFirst.document.change_events).Count
    $neutralSecond = Invoke-JobAgentDailyRun -ProjectRoot $neutralProjectRoot -AdapterResolver $neutralAdapter -StartedAt ([datetime]'2026-08-23T10:00:00Z') -CompanyIds @('company:alpha_ag') -SearchTerms @('Head of IT')
    Assert-True -Condition (@($neutralSecond.document.jobs).Count -eq 16) -Message 'Profilwechsel darf keine berufsneutral erfassten Stellen entfernen.'
    Assert-True -Condition (@($neutralSecond.document.change_events | Where-Object { @('JOB_CREATED', 'JOB_CLOSED', 'JOB_REMOVED') -contains $_.event_type }).Count -eq 16) -Message 'Profilwechsel darf keine NEW-, CLOSED- oder REMOVED-Ereignisse erzeugen.'
    Assert-True -Condition (@($neutralSecond.document.change_events).Count -ge $neutralEventCount) -Message 'Profilwechsel darf die bestehende Historie nicht verlieren.'
    $neutralSecondRun = @($neutralSecond.document.scan_runs | Where-Object { $_.scan_run_id -eq $neutralSecond.scan_run_id })[0]
    Assert-True -Condition ($neutralSecondRun.collection_scope -eq 'EXPLICIT_TERMS') -Message 'Runmanifest speichert den expliziten Suchscope nicht.'
    Assert-True -Condition (@($neutralSecondRun.search_terms).Count -eq 1) -Message 'Runmanifest speichert Suchbegriffe nicht.'

    $neutralMode = 'partial'
    $neutralThird = Invoke-JobAgentDailyRun -ProjectRoot $neutralProjectRoot -AdapterResolver $neutralAdapter -StartedAt ([datetime]'2026-08-24T10:00:00Z') -CompanyIds @('company:alpha_ag')
    Assert-True -Condition ($neutralThird.status -eq 'PARTIAL') -Message 'Teilscan muss als PARTIAL protokolliert werden.'
    Assert-True -Condition (@($neutralThird.document.jobs).Count -eq 16) -Message 'Teilscan darf bestehende berufsneutrale Jobs nicht entfernen.'
    Assert-True -Condition (@($neutralThird.document.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Teilscan darf keine Abwesenheit behaupten.'

    [pscustomobject]@{
        status = 'ok'
        cases = @(
            'daily_run_partial_with_isolated_company_error',
            'daily_run_persists_scan_run_attempts_jobs_and_report',
            'daily_run_writes_markdown_and_html_report',
            'daily_run_reports_secure_job_provider_and_source_links',
            'daily_run_classifies_raw_jobs',
            'daily_run_second_pass_deduplicates_to_active',
            'daily_run_cli_fixture_mode',
            'daily_run_cli_live_mode_without_fixture',
            'daily_run_cli_acquires_and_scans_new_company',
            'daily_run_two_regular_starts_keep_known_company_and_add_exactly_one',
            'daily_run_continues_scan_after_isolated_acquisition_failure',
            'daily_run_multi_source_partial_removal',
            'daily_run_prioritizes_refresh_due_companies',
            'daily_run_persists_selection_summary',
            'daily_run_report_renders_selection_metrics',
            'daily_run_persists_company_freshness_fields',
            'daily_run_live_jsonld_ats_source',
            'daily_run_preserves_neutral_role_and_region_matrix',
            'daily_run_separates_capture_scope_profile_counts_and_completeness',
            'daily_run_keeps_jobs_stable_on_profile_change_and_partial_scan'
        )
    } | ConvertTo-Json -Depth 4
}
finally {
    if ($null -ne (Get-Variable -Name liveProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $liveProjectRoot)) {
        Remove-Item -LiteralPath $liveProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name neutralProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $neutralProjectRoot)) {
        Remove-Item -LiteralPath $neutralProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name multiSourceProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $multiSourceProjectRoot)) {
        Remove-Item -LiteralPath $multiSourceProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name refreshProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $refreshProjectRoot)) {
        Remove-Item -LiteralPath $refreshProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name cliProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $cliProjectRoot)) {
        Remove-Item -LiteralPath $cliProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name cliLiveProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $cliLiveProjectRoot)) {
        Remove-Item -LiteralPath $cliLiveProjectRoot -Recurse -Force
    }
    if ($null -ne (Get-Variable -Name acquisitionProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $acquisitionProjectRoot)) {
        Remove-Item -LiteralPath $acquisitionProjectRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}
