#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))),
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$FixturePath,
    [Parameter()][ValidateSet('auto', 'fixture', 'live')][string]$AdapterMode = 'auto',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 1000,
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
    [Parameter()][string[]]$SearchTerms = @(),
    [Parameter()][string[]]$CompanyIds = @(),
    [Parameter()][switch]$FullScan,
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$RetainLogs = 30
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repoRoot 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.LiveScan.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Operations.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
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

function Get-JobAgentDailyEarliestWakeAt {
    param([Parameter()][AllowEmptyCollection()][object[]]$Values = @())

    $dates = @($Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object {
                try {
                    [datetime]::Parse([string]$_, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                }
                catch {
                    $null
                }
            } |
            Where-Object { $null -ne $_ } |
            Sort-Object)
    if ($dates.Count -eq 0) {
        return $null
    }
    return $dates[0].ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Invoke-JobAgentDailyAcquisitionTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][object[]]$Arguments
    )

    $output = @(& pwsh -NoProfile -File $ScriptPath @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{
            status = 'PARTIAL'
            reason = "$Phase fehlgeschlagen: " + ($output -join "`n")
            result = $null
        }
    }
    try {
        return [pscustomobject]@{
            status = 'COMPLETED'
            reason = $null
            result = ($output -join "`n") | ConvertFrom-Json -Depth 100
        }
    }
    catch {
        return [pscustomobject]@{
            status = 'PARTIAL'
            reason = "$Phase lieferte kein lesbares JSON: " + $_.Exception.Message
            result = $null
        }
    }
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

    $refillScript = Join-Path $repoRoot 'tools\Invoke-JobAgentDiscoveryRefill.ps1'
    $refillPhase = Invoke-JobAgentDailyAcquisitionTool -Phase 'Akquise-Quellennachfuellung' -ScriptPath $refillScript -Arguments @('-ProjectRoot', $root, '-DataRoot', $DataRoot, '-LogRoot', $LogRoot, '-MaxSources', '1')
    $refillResult = $refillPhase.result

    $websiteScript = Join-Path $repoRoot 'tools\Discover-JobAgentCompanyCandidateWebsites.ps1'
    $websitePhase = Invoke-JobAgentDailyAcquisitionTool -Phase 'Akquise-Website-Ermittlung' -ScriptPath $websiteScript -Arguments $commonArgs
    $websiteResult = $websitePhase.result

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
    $verifyPhase = Invoke-JobAgentDailyAcquisitionTool -Phase 'Akquise-Kandidatenverifikation' -ScriptPath $verifyScript -Arguments $verifyArgs
    $verifyResult = $verifyPhase.result

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

    $partialPhases = @(@($refillPhase, $websitePhase, $verifyPhase) | Where-Object { $_.status -eq 'PARTIAL' })
    [pscustomobject]@{
        schema_version = 'jobagent/daily-acquisition/v1'
        status = if ($partialPhases.Count -gt 0) { 'PARTIAL' } else { 'COMPLETED' }
        started_at = $startedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        finished_at = ([datetime]::UtcNow).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        budget = $MaxCandidates
        reason = if ($partialPhases.Count -gt 0) { @($partialPhases | ForEach-Object { [string]$_.reason } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' | ' } else { $null }
        source_refill = [pscustomobject]@{
            status = if ($null -ne $refillResult) { [string]$refillResult.status } else { [string]$refillPhase.status }
            reason = if ($null -ne $refillResult) { [string]$refillResult.reason } else { [string]$refillPhase.reason }
            imported_sources_total = if ($null -ne $refillResult) { [int]$refillResult.imported_sources_total } else { 0 }
            log_path = if ($null -ne $refillResult -and $refillResult.PSObject.Properties.Name -contains 'log_path') { [string]$refillResult.log_path } else { $null }
            wake_at = if ($null -ne $refillResult -and $refillResult.PSObject.Properties.Name -contains 'wake_at') { $refillResult.wake_at } else { $null }
        }
        website_discovery = [pscustomobject]@{
            status = if ($null -ne $websiteResult) { 'COMPLETED' } else { [string]$websitePhase.status }
            reason = if ($null -ne $websiteResult) { $null } else { [string]$websitePhase.reason }
            processed_total = if ($null -ne $websiteResult) { [int]$websiteResult.processed_total } else { 0 }
            verified_total = if ($null -ne $websiteResult) { [int]$websiteResult.verified_total } else { 0 }
            log_path = if ($null -ne $websiteResult) { [string]$websiteResult.log_path } else { $null }
        }
        candidate_verification = [pscustomobject]@{
            status = if ($null -ne $verifyResult) { 'COMPLETED' } else { [string]$verifyPhase.status }
            reason = if ($null -ne $verifyResult) { $null } else { [string]$verifyPhase.reason }
            processed_total = if ($null -ne $verifyResult) { [int]$verifyResult.verification_queue.processed_total } else { 0 }
            verified_total = if ($null -ne $verifyResult) { @($verifyResult.verified_candidate_ids).Count } else { 0 }
            log_path = if ($null -ne $verifyResult) { [string]$verifyResult.log_path } else { $null }
            checkpoint_path = if ($null -ne $verifyResult) { [string]$verifyResult.checkpoint_path } else { $null }
            wake_at = if ($null -ne $verifyResult -and $verifyResult.PSObject.Properties.Name -contains 'wake_at') { $verifyResult.wake_at } else { $null }
        }
        new_official_career_companies = @($newOfficialCareerCompanyIds).Count
        new_official_career_company_ids = @($newOfficialCareerCompanyIds)
        wake_at = Get-JobAgentDailyEarliestWakeAt -Values @(
            if ($null -ne $refillResult -and $refillResult.PSObject.Properties.Name -contains 'wake_at') { $refillResult.wake_at }
            if ($null -ne $verifyResult -and $verifyResult.PSObject.Properties.Name -contains 'wake_at') { $verifyResult.wake_at }
        )
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
        param([string]$RunId)
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
        $acquisition | Add-Member -NotePropertyName run_id -NotePropertyValue $RunId -Force
        $acquiredCompanyIds = @(
            if ($null -ne $acquisition -and $acquisition.PSObject.Properties.Name -contains 'new_official_career_company_ids') {
                $acquisition.new_official_career_company_ids | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
        )
        $effectiveCompanyIds = @($CompanyIds)
        if ($FullScan) {
            $fullScanDocument = Read-JobAgentStore -ProjectRoot $ProjectRoot -DataRoot $DataRoot
            $effectiveCompanyIds = @(
                $fullScanDocument.companies |
                    ForEach-Object { [string]$_.company_id } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Sort-Object -Unique
            )
            if ($effectiveCompanyIds.Count -gt $MaxCompanies) {
                throw "FullScan verlangt mindestens MaxCompanies=$($effectiveCompanyIds.Count); konfiguriert sind $MaxCompanies."
            }
        }
        $dailyResult = Invoke-JobAgentDailyRun `
            -ProjectRoot $ProjectRoot `
            -DataRoot $DataRoot `
            -AdapterResolver $adapter `
            -MaxCompanies $MaxCompanies `
            -TimeoutSeconds $TimeoutSeconds `
            -MaxResultsPerSource $MaxResultsPerSource `
            -SearchTerms $SearchTerms `
            -CompanyIds $effectiveCompanyIds `
            -AlwaysIncludeCompanyIds $acquiredCompanyIds `
            -StartedAt $runStartedAt
        $dailyResult | Add-Member -NotePropertyName acquisition -NotePropertyValue $acquisition -Force
        $dailyResult | Add-Member -NotePropertyName run_id -NotePropertyValue $RunId -Force
        $dailyResult | Add-Member -NotePropertyName wake_at -NotePropertyValue $(if ($null -ne $acquisition -and $acquisition.PSObject.Properties.Name -contains 'wake_at') { $acquisition.wake_at } else { $null }) -Force
        if ([string]$acquisition.status -eq 'PARTIAL' -and [string]$dailyResult.status -ne 'FAILED') {
            $dailyResult.status = 'PARTIAL'
        }
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
    full_scan = [bool]$FullScan
    scan_run_id = if ($result) { $result.scan_run_id } else { $null }
    run_id = if ($result) { $result.run_id } else { $null }
    store_path = if ($result) { $result.store_path } else { $null }
    report_path = if ($result) { $result.report_path } else { $null }
    markdown_report_path = if ($result) { $result.markdown_report_path } else { $null }
    html_report_path = if ($result) { $result.html_report_path } else { $null }
    jobboard_path = if ($result) { $result.jobboard_path } else { $null }
    publication_manifest_path = if ($result) { $result.publication_manifest_path } else { $null }
    acquisition = if ($result) { $result.acquisition } else { $null }
    wake_at = if ($result) { $result.wake_at } else { $null }
    run_log_path = $managed.run_log_path
    status_path = $managed.status_path
    statistics = if ($result) { $result.summary.statistics } else { $null }
    error = $managed.error
} | ConvertTo-Json -Depth 20

if ($managed.exit_code -ne 0) {
    exit $managed.exit_code
}
