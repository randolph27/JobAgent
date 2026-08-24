#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.Classification.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Report.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.StatusMachine.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentDailyIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-JobAgentDailyStamp {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-JobAgentDailyRunId {
    [CmdletBinding()]
    param(
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow
    )

    return 'scanrun:' + (ConvertTo-JobAgentDailyStamp -Value $StartedAt)
}

function Get-JobAgentDailyRunSources {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$CompanyId
    )

    @($Document.job_sources) |
        Where-Object { ([string]$_.company_id -eq $CompanyId) -and ($_.is_official -eq $true) } |
        Sort-Object -Property source_id
}

function ConvertTo-JobAgentDailyDateOrNull {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    try {
        return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    }
    catch {
        return $null
    }
}

function Get-JobAgentDailyRunRefreshDue {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][datetime]$Now
    )

    $nextRefreshValue = if ($Company.PSObject.Properties.Name -contains 'next_refresh_at') { $Company.next_refresh_at } else { $null }
    $nextRefreshAt = ConvertTo-JobAgentDailyDateOrNull -Value $nextRefreshValue
    if ($null -ne $nextRefreshAt) {
        return $nextRefreshAt -le $Now.ToUniversalTime()
    }
    $lastVerifiedValue = if ($Company.PSObject.Properties.Name -contains 'last_verified_at') { $Company.last_verified_at } else { $null }
    $lastVerifiedAt = ConvertTo-JobAgentDailyDateOrNull -Value $lastVerifiedValue
    $verificationStatus = if ($Company.PSObject.Properties.Name -contains 'verification_status') { [string]$Company.verification_status } else { 'UNVERIFIED' }
    if ($verificationStatus -eq 'UNVERIFIED') {
        return $true
    }
    if ($null -eq $lastVerifiedAt) {
        return $true
    }
    $maxAgeDays = if ($verificationStatus -eq 'COMPANY_DOMAIN_VERIFIED') { 90 } else { 30 }
    return $lastVerifiedAt.AddDays($maxAgeDays) -le $Now.ToUniversalTime()
}

function Get-JobAgentDailyRunSortKey {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][datetime]$Now
    )

    $refreshRank = if (Get-JobAgentDailyRunRefreshDue -Company $Company -Now $Now) { 0 } else { 1 }
    $scanRank = if ($null -eq $Company.last_successful_scan_at) { 0 } else { 1 }
    $priorityRank = 1000 - [int]$Company.scan_priority
    $nextRefresh = if ($Company.PSObject.Properties.Name -contains 'next_refresh_at') { [string]$Company.next_refresh_at } else { '' }
    return ('{0:D2}|{1:D2}|{2:D4}|{3}|{4}|{5}' -f $refreshRank, $scanRank, $priorityRank, $nextRefresh, [string]$Company.next_scan_at, [string]$Company.canonical_name)
}

function Get-JobAgentDailyRunCandidateCompanies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
        [Parameter()][string[]]$CompanyIds = @()
    )

    $allowedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($companyId in @($CompanyIds)) {
        if (-not [string]::IsNullOrWhiteSpace($companyId)) {
            [void]$allowedIds.Add($companyId)
        }
    }

    $nowUtc = $Now.ToUniversalTime()
    @($Document.companies) |
        Where-Object {
            if ($allowedIds.Count -gt 0 -and -not $allowedIds.Contains([string]$_.company_id)) {
                return $false
            }
            if (@(Get-JobAgentDailyRunSources -Document $Document -CompanyId ([string]$_.company_id)).Count -eq 0) {
                return $false
            }
            if ($allowedIds.Count -gt 0) {
                return $true
            }
            if ($_.PSObject.Properties.Name -notcontains 'next_scan_at' -or [string]::IsNullOrWhiteSpace([string]$_.next_scan_at)) {
                return $true
            }
            try {
                return ([datetime]::Parse([string]$_.next_scan_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() -le $nowUtc)
            }
            catch {
                return $true
            }
        } |
        Sort-Object -Property { Get-JobAgentDailyRunSortKey -Company $_ -Now $nowUtc } |
        Select-Object -First $MaxCompanies
}

function New-JobAgentDailyRunSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
        [Parameter()][string[]]$CompanyIds = @()
    )

    $allowedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($companyId in @($CompanyIds)) {
        if (-not [string]::IsNullOrWhiteSpace($companyId)) {
            [void]$allowedIds.Add($companyId)
        }
    }

    $nowUtc = $Now.ToUniversalTime()
    $eligible = New-Object System.Collections.Generic.List[object]
    $excluded = New-Object System.Collections.Generic.List[object]
    foreach ($company in @($Document.companies)) {
        $companyId = [string]$company.company_id
        $sources = @(Get-JobAgentDailyRunSources -Document $Document -CompanyId $companyId)
        if ($allowedIds.Count -gt 0 -and -not $allowedIds.Contains($companyId)) {
            $excluded.Add([pscustomobject]@{ company_id = $companyId; reason = 'not_requested' })
            continue
        }
        if ($sources.Count -eq 0) {
            $excluded.Add([pscustomobject]@{ company_id = $companyId; reason = 'no_official_source' })
            continue
        }
        if ($allowedIds.Count -gt 0) {
            $eligible.Add($company)
            continue
        }
        if ($company.PSObject.Properties.Name -notcontains 'next_scan_at' -or [string]::IsNullOrWhiteSpace([string]$company.next_scan_at)) {
            $eligible.Add($company)
            continue
        }
        try {
            if ([datetime]::Parse([string]$company.next_scan_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() -le $nowUtc) {
                $eligible.Add($company)
            }
            else {
                $excluded.Add([pscustomobject]@{ company_id = $companyId; reason = 'not_due' })
            }
        }
        catch {
            $eligible.Add($company)
        }
    }

    $sortedEligible = @($eligible.ToArray() | Sort-Object -Property { Get-JobAgentDailyRunSortKey -Company $_ -Now $nowUtc })
    $selected = @($sortedEligible | Select-Object -First $MaxCompanies)
    $selectedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($company in $selected) {
        [void]$selectedIds.Add([string]$company.company_id)
    }

    $skipped = New-Object System.Collections.Generic.List[object]
    foreach ($company in $sortedEligible) {
        if (-not $selectedIds.Contains([string]$company.company_id)) {
            $skipped.Add([pscustomobject]@{ company_id = [string]$company.company_id; reason = 'limit_reached' })
        }
    }
    foreach ($item in @($excluded.ToArray())) {
        if ([string]$item.reason -ne 'not_requested') {
            $skipped.Add($item)
        }
    }

    [pscustomobject]@{
        companies = @($selected)
        summary = [pscustomobject]@{
            companies_total = @($Document.companies).Count
            companies_eligible = $sortedEligible.Count
            companies_due = $sortedEligible.Count
            companies_selected = $selected.Count
            companies_skipped = @($skipped.ToArray()).Count
            limit = $MaxCompanies
            selection_reason = if ($allowedIds.Count -gt 0) { 'explicit_company_ids' } else { 'due_by_next_scan_at_then_priority' }
            explicit_company_ids = $allowedIds.Count -gt 0
            skipped = @($skipped.ToArray() | Sort-Object reason, company_id | Select-Object -First 25)
        }
    }
}

function Copy-JobAgentRawJobWithClassification {
    param(
        [Parameter(Mandatory)][object]$RawJob,
        [Parameter()][datetime]$EvaluatedAt = [datetime]::UtcNow
    )

    $copy = [ordered]@{}
    foreach ($property in $RawJob.PSObject.Properties) {
        $copy[$property.Name] = $property.Value
    }

    $location = if ($copy.Contains('location')) { $copy['location'] } elseif ($copy.Contains('location_label')) { $copy['location_label'] } else { 'UNKNOWN' }
    $summary = if ($copy.Contains('summary')) { [string]$copy['summary'] } else { '' }
    $description = if ($copy.Contains('description')) { [string]$copy['description'] } else { '' }
    $workModel = if ($copy.Contains('work_model') -and -not [string]::IsNullOrWhiteSpace([string]$copy['work_model'])) { [string]$copy['work_model'] } else { 'UNKNOWN' }
    $employmentType = if ($copy.Contains('employment_type') -and -not [string]::IsNullOrWhiteSpace([string]$copy['employment_type'])) { [string]$copy['employment_type'] } else { 'UNKNOWN' }

    $classification = Get-JobAgentLeadershipClassification `
        -Title ([string]$copy['title']) `
        -Summary $summary `
        -Description $description `
        -Location $location `
        -WorkModel $workModel `
        -EmploymentType $employmentType `
        -EvaluatedAt $EvaluatedAt

    $copy['classification'] = $classification
    $copy['priority'] = [string]$classification.priority
    return [pscustomobject]$copy
}

function Add-JobAgentDailyRunClassification {
    param(
        [Parameter(Mandatory)][object]$AdapterResult,
        [Parameter()][datetime]$EvaluatedAt = [datetime]::UtcNow
    )

    $rawJobs = New-Object System.Collections.Generic.List[object]
    foreach ($rawJob in @($AdapterResult.raw_jobs)) {
        try {
            if (Test-JobAgentRawJobValidForStatus -RawJob $rawJob) {
                $rawJobs.Add((Copy-JobAgentRawJobWithClassification -RawJob $rawJob -EvaluatedAt $EvaluatedAt))
            }
            else {
                $rawJobs.Add($rawJob)
            }
        }
        catch {
            $rawJobs.Add($rawJob)
        }
    }
    $AdapterResult.raw_jobs = @($rawJobs.ToArray())
    return $AdapterResult
}

function New-JobAgentDailyRunErrorResult {
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter(Mandatory)][datetime]$FinishedAt
    )

    New-JobAgentAdapterResult `
        -AdapterInput $AdapterInput `
        -AdapterName 'daily-run-adapter-wrapper' `
        -Status 'FAILED' `
        -ErrorClass 'TECHNICAL_LIMITATION' `
        -RetryRecommendation 'MANUAL_REVIEW' `
        -RawJobs @() `
        -HttpStatus 599 `
        -ArtifactPaths @($Message) `
        -StartedAt $StartedAt `
        -FinishedAt $FinishedAt
}

function Update-JobAgentDailyRunCompanyState {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][object[]]$CompanyResults,
        [Parameter(Mandatory)][datetime]$Now
    )

    $company = $Company.PSObject.Copy()
    $hasFailure = @($CompanyResults | Where-Object { [string]$_.status -eq 'FAILED' }).Count -gt 0
    $hasSuccess = @($CompanyResults | Where-Object { ([string]$_.status -eq 'SUCCESS') -and ([string]$_.error_class -eq 'NONE') }).Count -gt 0
    $nowText = ConvertTo-JobAgentDailyIso -Value $Now
    $company.updated_at = $nowText
    if ($company.PSObject.Properties.Name -notcontains 'last_imported_at' -or [string]::IsNullOrWhiteSpace([string]$company.last_imported_at)) {
        $company | Add-Member -NotePropertyName last_imported_at -NotePropertyValue $nowText -Force
    }
    if ($hasSuccess) {
        $company.scan_status = 'SUCCESS'
        $company.last_successful_scan_at = $nowText
        $company | Add-Member -NotePropertyName last_verified_at -NotePropertyValue $nowText -Force
        $company | Add-Member -NotePropertyName expires_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(30)) -Force
        $company | Add-Member -NotePropertyName next_refresh_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)) -Force
        $company | Add-Member -NotePropertyName refresh_reason -NotePropertyValue 'scheduled_company_rotation' -Force
        $company | Add-Member -NotePropertyName staleness_status -NotePropertyValue 'FRESH' -Force
        $company.next_scan_at = ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)
    }
    elseif ($hasFailure) {
        $company.scan_status = 'FAILED'
        $company | Add-Member -NotePropertyName expires_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddHours(6)) -Force
        $company | Add-Member -NotePropertyName next_refresh_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddHours(6)) -Force
        $company | Add-Member -NotePropertyName refresh_reason -NotePropertyValue 'last_scan_failed' -Force
        $company | Add-Member -NotePropertyName staleness_status -NotePropertyValue 'REFRESH_DUE' -Force
        $company.next_scan_at = ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddHours(6)
    }
    else {
        $company.scan_status = 'PARTIAL'
        $company | Add-Member -NotePropertyName expires_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)) -Force
        $company | Add-Member -NotePropertyName next_refresh_at -NotePropertyValue (ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)) -Force
        $company | Add-Member -NotePropertyName refresh_reason -NotePropertyValue 'partial_scan_recheck' -Force
        $company | Add-Member -NotePropertyName staleness_status -NotePropertyValue 'REFRESH_DUE' -Force
        $company.next_scan_at = ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)
    }
    return $company
}

function Get-JobAgentDailyRunStatus {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$AdapterResults)

    if ($AdapterResults.Count -eq 0) {
        return 'SKIPPED'
    }
    if (@($AdapterResults | Where-Object { [string]$_.status -eq 'FAILED' }).Count -eq $AdapterResults.Count) {
        return 'FAILED'
    }
    if (@($AdapterResults | Where-Object { [string]$_.status -ne 'SUCCESS' }).Count -gt 0) {
        return 'PARTIAL'
    }
    return 'SUCCESS'
}

function New-JobAgentDailyRunSummary {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$AdapterResults,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter(Mandatory)][datetime]$FinishedAt,
        [Parameter()][AllowNull()][object]$Report = $null
    )

    $jobsForRun = @($Document.job_snapshots | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $changesForRun = @($Document.change_events | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $errors = @($AdapterResults | Where-Object { [string]$_.status -eq 'FAILED' } | ForEach-Object {
            [pscustomobject]@{
                company_id = $_.company_id
                source_id = $_.source_id
                error_class = $_.error_class
                retry_recommendation = $_.retry_recommendation
                messages = @($_.artifact_paths)
            }
        })
    $reportStatistics = if ($null -ne $Report) { $Report.statistics } else { $null }
    [pscustomobject]@{
        scan_run_id = $ScanRunId
        started_at = ConvertTo-JobAgentDailyIso -Value $StartedAt
        finished_at = ConvertTo-JobAgentDailyIso -Value $FinishedAt
        status = Get-JobAgentDailyRunStatus -AdapterResults $AdapterResults
        report_path = $ReportPath
        statistics = [pscustomobject]@{
            companies_total = if ($null -ne $reportStatistics) { [int]$reportStatistics.companies_total } else { @($Document.companies).Count }
            companies_scanned = @($AdapterResults | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count
            companies_selected = if ($null -ne $reportStatistics) { [int]$reportStatistics.companies_selected } else { @($AdapterResults | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count }
            companies_due = if ($null -ne $reportStatistics) { [int]$reportStatistics.companies_due } else { 0 }
            companies_skipped = if ($null -ne $reportStatistics) { [int]$reportStatistics.companies_skipped } else { 0 }
            run_limit = if ($null -ne $reportStatistics) { [int]$reportStatistics.run_limit } else { @($AdapterResults | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count }
            selection_reason = if ($null -ne $reportStatistics) { [string]$reportStatistics.selection_reason } else { 'UNKNOWN' }
            adapter_attempts = $AdapterResults.Count
            raw_jobs = @($AdapterResults | ForEach-Object { @($_.raw_jobs).Count } | Measure-Object -Sum).Sum
            checked_jobs = if ($null -ne $reportStatistics) { [int]$reportStatistics.checked_jobs } else { $jobsForRun.Count }
            snapshots = $jobsForRun.Count
            created = @($changesForRun | Where-Object event_type -eq 'JOB_CREATED').Count
            active_matching_jobs = if ($null -ne $reportStatistics) { [int]$reportStatistics.active_matching_jobs } else { 0 }
            updated = @($changesForRun | Where-Object event_type -eq 'JOB_UPDATED').Count
            removed = @($changesForRun | Where-Object event_type -eq 'JOB_REMOVED').Count
            invalid = @($changesForRun | Where-Object event_type -eq 'JOB_INVALIDATED').Count
            new_companies = if ($null -ne $reportStatistics) { [int]$reportStatistics.new_companies } else { 0 }
            uncertain_sources = if ($null -ne $reportStatistics) { [int]$reportStatistics.uncertain_sources } else { 0 }
            unreachable_career_pages = if ($null -ne $reportStatistics) { [int]$reportStatistics.unreachable_career_pages } else { 0 }
            errors = $errors.Count
        }
        errors = $errors
    }
}

function Write-JobAgentDailyRunReport {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$Summary
    )

    $path = if ([IO.Path]::IsPathRooted([string]$Summary.report_path)) {
        [string]$Summary.report_path
    }
    else {
        Join-Path $ProjectRoot ([string]$Summary.report_path)
    }
    Write-JobAgentDailyAtomicFile -Path $path -Content ($Summary | ConvertTo-Json -Depth 100)
    return $path
}

function Write-JobAgentDailyRunMarkdownReport {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter()][AllowNull()][object]$Report = $null
    )

    $path = if ([IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    }
    else {
        Join-Path $ProjectRoot $ReportPath
    }
    if ($null -eq $Report) {
        $Report = New-JobAgentDailyReport -Document $Document -ScanRunId $ScanRunId
    }
    Write-JobAgentDailyAtomicFile -Path $path -Content (ConvertTo-JobAgentDailyReportMarkdown -Report $Report)
    return $path
}

function Write-JobAgentDailyRunHtmlReport {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter()][AllowNull()][object]$Report = $null
    )

    $path = if ([IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    }
    else {
        Join-Path $ProjectRoot $ReportPath
    }
    if ($null -eq $Report) {
        $Report = New-JobAgentDailyReport -Document $Document -ScanRunId $ScanRunId
    }
    Write-JobAgentDailyAtomicFile -Path $path -Content (ConvertTo-JobAgentDailyReportHtml -Report $Report)
    return $path
}

function Write-JobAgentDailyAtomicFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content + "`n")
    $stream = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function Invoke-JobAgentDailyRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][scriptblock]$AdapterResolver,
        [Parameter()][string]$DataRoot = 'data/jobagent',
        [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
        [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 30,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxResultsPerSource = 100,
        [Parameter()][string[]]$CompanyIds = @(),
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow
    )

    $projectRootFull = Resolve-JobAgentStoreRoot -RootPath $ProjectRoot
    $scanRunId = New-JobAgentDailyRunId -StartedAt $StartedAt
    $reportRelativePath = 'logs/jobagent/daily-run-' + (ConvertTo-JobAgentDailyStamp -Value $StartedAt) + '.json'
    $markdownReportRelativePath = 'logs/jobagent/daily-run-' + (ConvertTo-JobAgentDailyStamp -Value $StartedAt) + '.md'
    $htmlReportRelativePath = 'html/jobagent/daily-run-' + (ConvertTo-JobAgentDailyStamp -Value $StartedAt) + '.html'
    $lock = Enter-JobAgentStoreLock -ProjectRoot $projectRootFull -DataRoot $DataRoot
    try {
        $document = Read-JobAgentStore -ProjectRoot $projectRootFull -DataRoot $DataRoot
        $selection = New-JobAgentDailyRunSelection -Document $document -Now $StartedAt -MaxCompanies $MaxCompanies -CompanyIds $CompanyIds
        $companies = @($selection.companies)
        $adapterResults = New-Object System.Collections.Generic.List[object]

        foreach ($company in $companies) {
            foreach ($source in @(Get-JobAgentDailyRunSources -Document $document -CompanyId ([string]$company.company_id))) {
                $attemptStartedAt = [datetime]::UtcNow
                $context = New-JobAgentScanContext -ScanRunId $scanRunId -StartedAt $StartedAt -TimeoutSeconds $TimeoutSeconds -MaxResults $MaxResultsPerSource
                $input = New-JobAgentAdapterInput -Company $company -JobSource $source -ScanContext $context
                try {
                    $resolved = & $AdapterResolver $input
                    foreach ($result in @($resolved)) {
                        $adapterResults.Add((Add-JobAgentDailyRunClassification -AdapterResult $result -EvaluatedAt $StartedAt))
                    }
                }
                catch {
                    $adapterResults.Add((New-JobAgentDailyRunErrorResult -AdapterInput $input -Message $_.Exception.Message -StartedAt $attemptStartedAt -FinishedAt ([datetime]::UtcNow)))
                }
            }
        }

        $resultsArray = $adapterResults.ToArray()
        $document = Invoke-JobAgentStatusMachine -Document $document -ScanRunId $scanRunId -AdapterResults $resultsArray -ObservedAt $StartedAt

        foreach ($company in $companies) {
            $companyResults = @($resultsArray | Where-Object { [string]$_.company_id -eq [string]$company.company_id })
            $updatedCompany = Update-JobAgentDailyRunCompanyState -Company $company -CompanyResults $companyResults -Now $StartedAt
            $document = Upsert-JobAgentCompany -Document $document -Company $updatedCompany
        }

        $finishedAt = [datetime]::UtcNow
        $scanRun = [pscustomobject]@{
            scan_run_id = $scanRunId
            started_at = ConvertTo-JobAgentDailyIso -Value $StartedAt
            finished_at = ConvertTo-JobAgentDailyIso -Value $finishedAt
            status = Get-JobAgentDailyRunStatus -AdapterResults $resultsArray
            company_ids = @($companies | ForEach-Object { [string]$_.company_id })
            selection_summary = $selection.summary
            artifact_paths = @($reportRelativePath, $markdownReportRelativePath, $htmlReportRelativePath)
            errors = @($resultsArray | Where-Object { [string]$_.status -eq 'FAILED' } | ForEach-Object { $_.error_class })
        }
        $document = Upsert-JobAgentScanRun -Document $document -ScanRun $scanRun
        $storePath = Write-JobAgentStore -ProjectRoot $projectRootFull -DataRoot $DataRoot -Document $document -CreateBackup

        $report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
        $summary = New-JobAgentDailyRunSummary -Document $document -ScanRunId $scanRunId -AdapterResults $resultsArray -ReportPath $reportRelativePath -StartedAt $StartedAt -FinishedAt $finishedAt -Report $report
        $markdownReportPath = Write-JobAgentDailyRunMarkdownReport -ProjectRoot $projectRootFull -Document $document -ScanRunId $scanRunId -ReportPath $markdownReportRelativePath -Report $report
        $htmlReportPath = Write-JobAgentDailyRunHtmlReport -ProjectRoot $projectRootFull -Document $document -ScanRunId $scanRunId -ReportPath $htmlReportRelativePath -Report $report
        $summary.report_path = Join-Path $projectRootFull $reportRelativePath
        $summary | Add-Member -NotePropertyName markdown_report_path -NotePropertyValue $markdownReportPath -Force
        $summary | Add-Member -NotePropertyName html_report_path -NotePropertyValue $htmlReportPath -Force
        $reportPath = Write-JobAgentDailyRunReport -ProjectRoot $projectRootFull -Summary $summary

        [pscustomobject]@{
            scan_run_id = $scanRunId
            status = $summary.status
            store_path = $storePath
            report_path = $reportPath
            markdown_report_path = $markdownReportPath
            html_report_path = $htmlReportPath
            summary = $summary
            document = $document
        }
    }
    finally {
        Exit-JobAgentStoreLock -Lock $lock
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentDailyRunCandidateCompanies',
    'Invoke-JobAgentDailyRun',
    'New-JobAgentDailyRunSelection',
    'New-JobAgentDailyRunId'
)
