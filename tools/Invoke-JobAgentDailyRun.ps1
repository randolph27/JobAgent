#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))),
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$FixturePath,
    [Parameter()][ValidateSet('auto', 'fixture', 'live')][string]$AdapterMode = 'auto',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
    [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 30,
    [Parameter()][ValidateRange(0, 5)][int]$MaxRetries = 1,
    [Parameter()][ValidateRange(1, 100)][int]$MaxResultsPerSource = 100,
    [Parameter()][ValidateRange(1, 100)][int]$MaxDetailFetchesPerSource = 100,
    [Parameter()][ValidateRange(1, 100)][int]$MaxPagesPerSource = 10,
    [Parameter()][ValidateRange(1, 8)][int]$HostConcurrency = 1,
    [Parameter()][ValidateRange(0, 1000)][int]$AcquisitionCandidateBudget = 5,
    [Parameter()][switch]$DisableAcquisition,
    [Parameter()][string]$AcquisitionFixtureMapPath,
    [Parameter()][ValidateSet('auto', 'dotnet', 'curl', 'wsl-curl')][string]$FetchClient = 'auto',
    [Parameter()][string]$WslDistribution = 'Ubuntu-22.04',
    [Parameter()][string[]]$SearchTerms = @('Head of IT', 'Director IT', 'IT Leitung', 'IT-Leitung', 'Leiter IT', 'CIO'),
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
Import-Module (Join-Path $repoRoot 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Read-ToolJsonFileIfPresent {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100
}

function Invoke-JobAgentDailyAcquisitionPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$DataRoot = 'data/jobagent',
        [Parameter()][string]$LogRoot = 'logs/jobagent',
        [Parameter()][ValidateRange(0, 1000)][int]$MaxCandidates = 5,
        [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
        [Parameter()][ValidateRange(0, 20)][int]$MaxRetries = 3,
        [Parameter()][ValidateRange(1, 8)][int]$HostConcurrency = 1,
        [Parameter()][ValidateSet('auto', 'dotnet', 'curl', 'wsl-curl')][string]$FetchClient = 'auto',
        [Parameter()][string]$WslDistribution = 'Ubuntu-22.04',
        [Parameter()][string]$FixtureMapPath
    )

    $root = [IO.Path]::GetFullPath($ProjectRoot)
    $hintStorePath = Resolve-ToolPath -Root $root -Path 'data/jobagent/company-discovery.hints.json'
    $startedAt = [datetime]::UtcNow
    if ($MaxCandidates -le 0 -or -not (Test-Path -LiteralPath $hintStorePath -PathType Leaf)) {
        return [pscustomobject]@{
            schema_version = 'jobagent/daily-acquisition/v1'
            status = 'SKIPPED'
            started_at = $startedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            finished_at = ([datetime]::UtcNow).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            reason = if ($MaxCandidates -le 0) { 'budget_zero' } else { 'hint_store_missing' }
            website_discovery = $null
            candidate_verification = $null
            new_official_career_companies = 0
        }
    }

    $beforeDocument = Read-ToolJsonFileIfPresent -Path (Resolve-ToolPath -Root $root -Path (Join-Path $DataRoot 'store.json'))
    $beforeOfficialCareerCompanyIds = @(
        if ($null -ne $beforeDocument) {
            @($beforeDocument.job_sources |
                Where-Object { [bool]$_.is_official -and @('CAREER_PAGE', 'OFFICIAL_ATS') -contains [string]$_.source_type } |
                ForEach-Object { [string]$_.company_id } |
                Sort-Object -Unique)
        }
    )

    $commonArgs = @(
        '-ProjectRoot', $root,
        '-LogRoot', $LogRoot,
        '-MaxCandidates', ([string]$MaxCandidates),
        '-TimeoutSeconds', ([string][Math]::Min(60, [Math]::Max(1, $TimeoutSeconds))),
        '-FetchClient', $FetchClient,
        '-WslDistribution', $WslDistribution
    )
    if (-not [string]::IsNullOrWhiteSpace($FixtureMapPath)) {
        $commonArgs += @('-FixtureMapPath', $FixtureMapPath)
    }

    $websiteScript = Join-Path $repoRoot 'tools\Discover-JobAgentCompanyCandidateWebsites.ps1'
    $websiteOutput = @(& pwsh -NoProfile -File $websiteScript @commonArgs 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ('Akquise-Website-Ermittlung fehlgeschlagen: ' + ($websiteOutput -join "`n"))
    }
    $websiteResult = ($websiteOutput -join "`n") | ConvertFrom-Json -Depth 100

    $verifyArgs = @(
        '-ProjectRoot', $root,
        '-DataRoot', $DataRoot,
        '-LogRoot', $LogRoot,
        '-MaxCandidates', ([string]$MaxCandidates),
        '-TimeoutSeconds', ([string][Math]::Min(60, [Math]::Max(1, $TimeoutSeconds))),
        '-MaxRetries', ([string][Math]::Max(1, $MaxRetries)),
        '-WorkerCount', '1',
        '-HostConcurrency', ([string]$HostConcurrency),
        '-FetchClient', $FetchClient,
        '-WslDistribution', $WslDistribution
    )
    if (-not [string]::IsNullOrWhiteSpace($FixtureMapPath)) {
        $verifyArgs += @('-FixtureMapPath', $FixtureMapPath)
    }

    $verifyScript = Join-Path $repoRoot 'tools\Verify-JobAgentCompanyCandidates.ps1'
    $verifyOutput = @(& pwsh -NoProfile -File $verifyScript @verifyArgs 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ('Akquise-Kandidatenverifikation fehlgeschlagen: ' + ($verifyOutput -join "`n"))
    }
    $verifyResult = ($verifyOutput -join "`n") | ConvertFrom-Json -Depth 100

    $afterDocument = Read-ToolJsonFileIfPresent -Path (Resolve-ToolPath -Root $root -Path (Join-Path $DataRoot 'store.json'))
    $afterOfficialCareerCompanyIds = @(
        if ($null -ne $afterDocument) {
            @($afterDocument.job_sources |
                Where-Object { [bool]$_.is_official -and @('CAREER_PAGE', 'OFFICIAL_ATS') -contains [string]$_.source_type } |
                ForEach-Object { [string]$_.company_id } |
                Sort-Object -Unique)
        }
    )
    $beforeSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($companyId in $beforeOfficialCareerCompanyIds) { [void]$beforeSet.Add($companyId) }
    $newOfficialCareerCompanyIds = @($afterOfficialCareerCompanyIds | Where-Object { -not $beforeSet.Contains([string]$_) })

    [pscustomobject]@{
        schema_version = 'jobagent/daily-acquisition/v1'
        status = 'COMPLETED'
        started_at = $startedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        finished_at = ([datetime]::UtcNow).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        budget = $MaxCandidates
        website_discovery = [pscustomobject]@{
            processed_total = [int]$websiteResult.processed_total
            verified_total = [int]$websiteResult.verified_total
            log_path = [string]$websiteResult.log_path
        }
        candidate_verification = [pscustomobject]@{
            processed_total = [int]$verifyResult.verification_queue.processed_total
            verified_total = @($verifyResult.verified_candidate_ids).Count
            log_path = [string]$verifyResult.log_path
            checkpoint_path = [string]$verifyResult.checkpoint_path
        }
        new_official_career_companies = @($newOfficialCareerCompanyIds).Count
        new_official_career_company_ids = @($newOfficialCareerCompanyIds)
    }
}

$resolvedMode = if ($AdapterMode -eq 'auto') {
    if ([string]::IsNullOrWhiteSpace($FixturePath)) { 'live' } else { 'fixture' }
}
else {
    $AdapterMode
}

if ($resolvedMode -eq 'fixture' -and [string]::IsNullOrWhiteSpace($FixturePath)) {
    throw 'Fixture-Modus verlangt -FixturePath.'
}

$fixture = $null
if ($resolvedMode -eq 'fixture') {
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
}
else {
    $policy = New-JobAgentLiveScanPolicy `
        -TimeoutSeconds $TimeoutSeconds `
        -MaxRetries $MaxRetries `
        -MaxCompanies $MaxCompanies `
        -MaxResultsPerSource $MaxResultsPerSource `
        -MaxDetailFetchesPerSource $MaxDetailFetchesPerSource `
        -MaxPagesPerSource $MaxPagesPerSource `
        -HostConcurrency $HostConcurrency `
        -FetchClient $FetchClient `
        -WslDistribution $WslDistribution `
        -SearchTerms $SearchTerms

    $adapter = {
        param([object]$AdapterInput)

        Invoke-JobAgentLiveHtmlAdapter -AdapterInput $AdapterInput -Policy $policy
    }
}

$runStartedAt = [datetime]::UtcNow
$managed = Invoke-JobAgentManagedDailyRun `
    -ProjectRoot $ProjectRoot `
    -LogRoot $LogRoot `
    -RetainLogs $RetainLogs `
    -StartedAt $runStartedAt `
    -ScriptBlock {
        $acquisition = if ($DisableAcquisition) {
            [pscustomobject]@{
                schema_version = 'jobagent/daily-acquisition/v1'
                status = 'SKIPPED'
                reason = 'disabled'
                new_official_career_companies = 0
            }
        }
        else {
            Invoke-JobAgentDailyAcquisitionPhase `
                -ProjectRoot $ProjectRoot `
                -DataRoot $DataRoot `
                -LogRoot $LogRoot `
                -MaxCandidates $AcquisitionCandidateBudget `
                -TimeoutSeconds ([Math]::Min(60, $TimeoutSeconds)) `
                -MaxRetries $MaxRetries `
                -HostConcurrency $HostConcurrency `
                -FetchClient $FetchClient `
                -WslDistribution $WslDistribution `
                -FixtureMapPath $AcquisitionFixtureMapPath
        }
        $acquiredCompanyIds = @(
            if ($null -ne $acquisition -and $acquisition.PSObject.Properties.Name -contains 'new_official_career_company_ids') {
                $acquisition.new_official_career_company_ids | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
        )
        $dailyResult = Invoke-JobAgentDailyRun `
            -ProjectRoot $ProjectRoot `
            -DataRoot $DataRoot `
            -AdapterResolver $adapter `
            -MaxCompanies $MaxCompanies `
            -TimeoutSeconds $TimeoutSeconds `
            -MaxResultsPerSource $MaxResultsPerSource `
            -CompanyIds $CompanyIds `
            -AlwaysIncludeCompanyIds $acquiredCompanyIds `
            -StartedAt $runStartedAt
        $dailyResult | Add-Member -NotePropertyName acquisition -NotePropertyValue $acquisition -Force
        return $dailyResult
    }

$result = $managed.result

[pscustomobject]@{
    status = if ($result) { $result.status } else { $managed.status }
    run_state = $managed.status
    exit_code = $managed.exit_code
    adapter_mode = $resolvedMode
    fetch_client = if ($resolvedMode -eq 'live') { $FetchClient } else { $null }
    wsl_distribution = if ($resolvedMode -eq 'live') { $WslDistribution } else { $null }
    scan_run_id = if ($result) { $result.scan_run_id } else { $null }
    store_path = if ($result) { $result.store_path } else { $null }
    report_path = if ($result) { $result.report_path } else { $null }
    markdown_report_path = if ($result) { $result.markdown_report_path } else { $null }
    html_report_path = if ($result) { $result.html_report_path } else { $null }
    acquisition = if ($result) { $result.acquisition } else { $null }
    run_log_path = $managed.run_log_path
    status_path = $managed.status_path
    statistics = if ($result) { $result.summary.statistics } else { $null }
    error = $managed.error
} | ConvertTo-Json -Depth 20

if ($managed.exit_code -ne 0) {
    exit $managed.exit_code
}
