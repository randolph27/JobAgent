#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
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
    Assert-True -Condition (@($first.document.scan_runs).Count -eq 1) -Message 'ScanRun wurde nicht persistiert.'
    Assert-True -Condition (@($first.document.scan_attempts).Count -eq 3) -Message 'Nicht alle ScanAttempts wurden persistiert.'
    Assert-True -Condition (@($first.document.jobs).Count -eq 2) -Message 'Erfolgreiche Firmen haben keine Jobs erzeugt.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.status -eq 'NEW' }).Count -eq 2) -Message 'Erste Treffer sind nicht NEW.'
    Assert-True -Condition (@($first.document.jobs | Where-Object { $_.classification.result -eq 'MATCH' }).Count -eq 2) -Message 'Daily-Run klassifiziert Rohjobs nicht.'
    Assert-True -Condition (($first.document.companies | Where-Object company_id -eq 'company:gamma_ag').scan_status -eq 'FAILED') -Message 'Fehlerhafte Firma wurde nicht isoliert als FAILED markiert.'

    $second = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -StartedAt ([datetime]'2026-08-18T10:00:00Z') -CompanyIds @('company:alpha_ag', 'company:beta_ag', 'company:gamma_ag')
    Assert-True -Condition ($second.status -eq 'PARTIAL') -Message 'Zweiter Lauf mit einem Firmenfehler muss PARTIAL bleiben.'
    Assert-True -Condition (@($second.document.jobs).Count -eq 2) -Message 'Unveraenderter Folgelauf erzeugt Duplikate.'
    Assert-True -Condition (@($second.document.jobs | Where-Object { $_.status -eq 'ACTIVE' }).Count -eq 2) -Message 'Unveraenderter Folgelauf setzt bekannte Jobs nicht auf ACTIVE.'
    Assert-True -Condition (@($second.document.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Fehlerhafte Firma hat Stellen faelschlich entfernt.'
    Assert-True -Condition ($second.summary.statistics.errors -eq 1) -Message 'Report-Statistik zaehlt isolierten Fehler nicht.'

    $report = Get-Content -LiteralPath $second.report_path -Raw | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($report.statistics.companies_scanned -eq 3) -Message 'Report enthaelt falsche Firmenanzahl.'
    Assert-True -Condition ($report.statistics.snapshots -eq 2) -Message 'Report enthaelt falsche Snapshot-Anzahl.'

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

    [pscustomobject]@{
        status = 'ok'
        cases = @(
            'daily_run_partial_with_isolated_company_error',
            'daily_run_persists_scan_run_attempts_jobs_and_report',
            'daily_run_classifies_raw_jobs',
            'daily_run_second_pass_deduplicates_to_active',
            'daily_run_cli_fixture_mode'
        )
    } | ConvertTo-Json -Depth 4
}
finally {
    if ($null -ne (Get-Variable -Name cliProjectRoot -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $cliProjectRoot)) {
        Remove-Item -LiteralPath $cliProjectRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}
