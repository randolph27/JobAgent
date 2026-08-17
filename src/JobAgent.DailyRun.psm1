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
        Sort-Object `
            @{ Expression = { if ($null -eq $_.last_successful_scan_at) { 0 } else { 1 } }; Ascending = $true },
            @{ Expression = { -[int]$_.scan_priority }; Ascending = $true },
            @{ Expression = { [string]$_.next_scan_at }; Ascending = $true },
            @{ Expression = { [string]$_.canonical_name }; Ascending = $true } |
        Select-Object -First $MaxCompanies
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
    if ($hasSuccess) {
        $company.scan_status = 'SUCCESS'
        $company.last_successful_scan_at = $nowText
        $company.next_scan_at = ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddDays(1)
    }
    elseif ($hasFailure) {
        $company.scan_status = 'FAILED'
        $company.next_scan_at = ConvertTo-JobAgentDailyIso -Value $Now.ToUniversalTime().AddHours(6)
    }
    else {
        $company.scan_status = 'PARTIAL'
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
            companies_scanned = @($AdapterResults | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count
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
        $companies = @(Get-JobAgentDailyRunCandidateCompanies -Document $document -Now $StartedAt -MaxCompanies $MaxCompanies -CompanyIds $CompanyIds)
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
    'New-JobAgentDailyRunId'
)
