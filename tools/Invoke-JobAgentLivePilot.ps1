#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))),
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][ValidateRange(1, 10)][int]$MaxCompanies = 3,
    [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 20,
    [Parameter()][ValidateRange(0, 5)][int]$MaxRetries = 1,
    [Parameter()][ValidateRange(1, 100)][int]$MaxResultsPerSource = 10,
    [Parameter()][ValidateRange(1, 100)][int]$MaxDetailFetchesPerSource = 5,
    [Parameter()][string[]]$CompanyIds = @(),
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$RetainLogs = 30
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repoRoot 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.LiveScan.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Operations.psm1') -Force -DisableNameChecking

$startedAt = [datetime]::UtcNow
$policy = New-JobAgentLiveScanPolicy `
    -TimeoutSeconds $TimeoutSeconds `
    -MaxRetries $MaxRetries `
    -MaxCompanies $MaxCompanies `
    -MaxResultsPerSource $MaxResultsPerSource `
    -MaxDetailFetchesPerSource $MaxDetailFetchesPerSource

$adapter = {
    param([object]$AdapterInput)

    Invoke-JobAgentLiveHtmlAdapter -AdapterInput $AdapterInput -Policy $policy
}

$managed = Invoke-JobAgentManagedDailyRun `
    -ProjectRoot $ProjectRoot `
    -LogRoot $LogRoot `
    -RetainLogs $RetainLogs `
    -StartedAt $startedAt `
    -ScriptBlock {
        Invoke-JobAgentDailyRun `
            -ProjectRoot $ProjectRoot `
            -DataRoot $DataRoot `
            -AdapterResolver $adapter `
            -MaxCompanies $MaxCompanies `
            -TimeoutSeconds $TimeoutSeconds `
            -MaxResultsPerSource $MaxResultsPerSource `
            -CompanyIds $CompanyIds `
            -StartedAt $startedAt
    }

$result = $managed.result
$pilotPath = $null
if ($result) {
    $pilotSummary = New-JobAgentLivePilotSummary -DailyRunResult $result -Policy $policy -StartedAt $startedAt
    $stamp = $startedAt.ToUniversalTime().ToString('yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
    $logRootFull = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) $LogRoot }
    if (-not (Test-Path -LiteralPath $logRootFull)) {
        New-Item -ItemType Directory -Path $logRootFull -Force | Out-Null
    }
    $pilotPath = Join-Path $logRootFull ("live-pilot-$stamp.json")
    $encoding = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($pilotPath, ($pilotSummary | ConvertTo-Json -Depth 100) + "`n", $encoding)
}

[pscustomobject]@{
    status = if ($result) { $result.status } else { $managed.status }
    run_state = $managed.status
    exit_code = $managed.exit_code
    scan_run_id = if ($result) { $result.scan_run_id } else { $null }
    pilot_path = $pilotPath
    store_path = if ($result) { $result.store_path } else { $null }
    report_path = if ($result) { $result.report_path } else { $null }
    markdown_report_path = if ($result) { $result.markdown_report_path } else { $null }
    run_log_path = $managed.run_log_path
    status_path = $managed.status_path
    statistics = if ($result) { $result.summary.statistics } else { $null }
    error = $managed.error
} | ConvertTo-Json -Depth 20

if ($managed.exit_code -ne 0) {
    exit $managed.exit_code
}
