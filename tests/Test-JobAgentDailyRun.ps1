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
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:gamma_ag').scan_status -eq 'FAILED') -Message 'Fehlerhafte Firma wurde nicht isoliert als FAILED markiert.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:alpha_ag').staleness_status -eq 'FRESH') -Message 'Erfolgreicher Daily-Run persistiert Freshness-Status nicht.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string](($first.document.companies | Where-Object company_id -eq 'company:alpha_ag').last_verified_at))) -Message 'Erfolgreicher Daily-Run persistiert last_verified_at nicht.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:gamma_ag').refresh_reason -eq 'last_scan_failed') -Message 'Fehlerhafter Daily-Run persistiert Refresh-Grund nicht.'

    $second = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -StartedAt ([datetime]'2026-08-18T10:00:00Z') -CompanyIds @('company:alpha_ag', 'company:beta_ag', 'company:gamma_ag')
    Assert-True -Condition ($second.status -eq 'PARTIAL') -Message 'Zweiter Lauf mit einem Firmenfehler muss PARTIAL bleiben.'
    Assert-True -Condition (@($second.document.jobs).Count -eq 2) -Message 'Unveraenderter Folgelauf erzeugt Duplikate.'
    Assert-True -Condition (@($second.document.jobs | Where-Object { $_.status -eq 'ACTIVE' }).Count -eq 2) -Message 'Unveraenderter Folgelauf setzt bekannte Jobs nicht auf ACTIVE.'
    Assert-True -Condition (@($second.document.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Fehlerhafte Firma hat Stellen faelschlich entfernt.'
    Assert-True -Condition ($second.summary.statistics.errors -eq 1) -Message 'Report-Statistik zaehlt isolierten Fehler nicht.'

    $report = Get-Content -LiteralPath $second.report_path -Raw | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($report.statistics.companies_scanned -eq 3) -Message 'Report enthaelt falsche Firmenanzahl.'
    Assert-True -Condition ($report.statistics.checked_jobs -eq 2) -Message 'Report enthaelt falsche Anzahl gepruefter Stellen.'
    Assert-True -Condition ($report.statistics.snapshots -eq 2) -Message 'Report enthaelt falsche Snapshot-Anzahl.'
    Assert-True -Condition ($report.statistics.unreachable_career_pages -eq 1) -Message 'Report enthaelt falsche Anzahl nicht erreichbarer Karriereportale.'
    Assert-True -Condition ($report.html_report_path -eq $second.html_report_path) -Message 'Summary-JSON verliert den HTML-Report-Pfad.'
    $markdownReport = Get-Content -LiteralPath $second.markdown_report_path -Raw
    Assert-True -Condition ($markdownReport.Contains('## Aktive passende Stellen')) -Message 'Markdown-Report enthaelt keine aktiven passenden Stellen.'
    Assert-True -Condition ($markdownReport.Contains('## Fehler und unsichere Quellen')) -Message 'Markdown-Report enthaelt keine Fehler-/Quellen-Sektion.'
    Assert-True -Condition ($markdownReport.Contains('https://gamma.example.invalid/careers')) -Message 'Markdown-Report enthaelt keine fehlerhafte Karriere-Quelle.'
    Assert-True -Condition ($markdownReport.Contains('https://alpha.example.invalid/careers/head-it-100')) -Message 'Markdown-Report enthaelt keine offizielle URL.'
    $htmlReport = Get-Content -LiteralPath $second.html_report_path -Raw
    Assert-True -Condition ($htmlReport.Contains('<h2>Aktive passende Stellen</h2>')) -Message 'HTML-Report enthaelt keine aktiven passenden Stellen.'
    Assert-True -Condition ($htmlReport.Contains('<h2>Fehler und unsichere Quellen</h2>')) -Message 'HTML-Report enthaelt keine Fehler-/Quellen-Sektion.'
    Assert-True -Condition ($htmlReport.Contains('https://gamma.example.invalid/careers')) -Message 'HTML-Report enthaelt keine fehlerhafte Karriere-Quelle.'
    Assert-True -Condition ($htmlReport.Contains('https://alpha.example.invalid/careers/head-it-100')) -Message 'HTML-Report enthaelt keine offizielle URL.'
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
                Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @()
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

    [pscustomobject]@{
        status = 'ok'
        cases = @(
            'daily_run_partial_with_isolated_company_error',
            'daily_run_persists_scan_run_attempts_jobs_and_report',
            'daily_run_writes_markdown_and_html_report',
            'daily_run_classifies_raw_jobs',
            'daily_run_second_pass_deduplicates_to_active',
            'daily_run_cli_fixture_mode',
        'daily_run_multi_source_partial_removal',
            'daily_run_prioritizes_refresh_due_companies',
            'daily_run_persists_company_freshness_fields',
            'daily_run_live_jsonld_ats_source'
        )
    } | ConvertTo-Json -Depth 4
}
finally {
    if ($null -ne (Get-Variable -Name liveProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $liveProjectRoot)) {
        Remove-Item -LiteralPath $liveProjectRoot -Recurse -Force
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
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}
