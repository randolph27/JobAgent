#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))),
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$FixturePath,
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
    [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 30,
    [Parameter()][ValidateRange(1, 1000)][int]$MaxResultsPerSource = 100,
    [Parameter()][string[]]$CompanyIds = @()
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repoRoot 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

if ([string]::IsNullOrWhiteSpace($FixturePath)) {
    throw 'Daily-Run-CLI ist aktuell nur mit -FixturePath aktiv. Live-Adapter werden in einer separaten Lane angebunden.'
}

$resolvedFixturePath = [IO.Path]::GetFullPath($FixturePath)
if (-not (Test-Path -LiteralPath $resolvedFixturePath -PathType Leaf)) {
    throw "FixturePath existiert nicht: $resolvedFixturePath"
}

$fixture = Get-Content -LiteralPath $resolvedFixturePath -Raw | ConvertFrom-Json -Depth 100
$adapter = {
    param([object]$AdapterInput)

    $companyId = [string]$AdapterInput.company.company_id
    if ($fixture.PSObject.Properties.Name -notcontains $companyId) {
        Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status 'SKIPPED' -ErrorClass 'TECHNICAL_LIMITATION' -RetryRecommendation 'MANUAL_REVIEW' -HttpStatus 204
        return
    }

    $entry = $fixture.$companyId
    $status = if ($entry.PSObject.Properties.Name -contains 'status') { [string]$entry.status } else { 'SUCCESS' }
    $errorClass = if ($entry.PSObject.Properties.Name -contains 'error_class') { [string]$entry.error_class } else { 'NONE' }
    $retry = if ($entry.PSObject.Properties.Name -contains 'retry_recommendation') { [string]$entry.retry_recommendation } else { 'NONE' }
    $httpStatus = if ($entry.PSObject.Properties.Name -contains 'http_status') { [int]$entry.http_status } else { 200 }
    $jobs = if ($entry.PSObject.Properties.Name -contains 'raw_jobs') { @($entry.raw_jobs) } else { @() }

    Invoke-JobAgentFixtureAdapter `
        -AdapterInput $AdapterInput `
        -FixtureJobs $jobs `
        -Status $status `
        -ErrorClass $errorClass `
        -RetryRecommendation $retry `
        -HttpStatus $httpStatus
}

$result = Invoke-JobAgentDailyRun `
    -ProjectRoot $ProjectRoot `
    -DataRoot $DataRoot `
    -AdapterResolver $adapter `
    -MaxCompanies $MaxCompanies `
    -TimeoutSeconds $TimeoutSeconds `
    -MaxResultsPerSource $MaxResultsPerSource `
    -CompanyIds $CompanyIds

[pscustomobject]@{
    status = $result.status
    scan_run_id = $result.scan_run_id
    store_path = $result.store_path
    report_path = $result.report_path
    markdown_report_path = $result.markdown_report_path
    statistics = $result.summary.statistics
} | ConvertTo-Json -Depth 20

if ($result.status -eq 'FAILED') {
    exit 1
}
