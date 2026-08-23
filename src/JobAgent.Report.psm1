#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.Coverage.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentReportText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Fallback = 'UNKNOWN'
    )

    if ($null -eq $Value) {
        return $Fallback
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Fallback
    }
    return $text.Trim()
}

function ConvertTo-JobAgentReportMarkdownText {
    param([Parameter()][AllowNull()][object]$Value)

    $text = ConvertTo-JobAgentReportText -Value $Value
    return ($text -replace '\|', '\|' -replace "`r?`n", ' ')
}

function ConvertTo-JobAgentReportHtmlText {
    param([Parameter()][AllowNull()][object]$Value)

    return [Net.WebUtility]::HtmlEncode((ConvertTo-JobAgentReportText -Value $Value))
}

function ConvertTo-JobAgentReportDateText {
    param([Parameter()][AllowNull()][object]$Value)

    $text = ConvertTo-JobAgentReportText -Value $Value
    if ($text -eq 'UNKNOWN') {
        return $text
    }
    try {
        return ([datetime]::Parse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $text
    }
}

function ConvertTo-JobAgentReportListText {
    param(
        [Parameter()][AllowNull()][object[]]$Values = @(),
        [Parameter()][AllowEmptyString()][string]$Fallback = 'UNKNOWN',
        [Parameter()][ValidateRange(1, 20)][int]$MaxItems = 3
    )

    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    if ($items.Count -eq 0) {
        return $Fallback
    }
    return (($items | Select-Object -First $MaxItems) -join '; ')
}

function Get-JobAgentReportProperty {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }
    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-JobAgentReportCompanyName {
    param(
        [Parameter(Mandatory)][hashtable]$CompaniesById,
        [Parameter(Mandatory)][string]$CompanyId
    )

    if ($CompaniesById.ContainsKey($CompanyId)) {
        return ConvertTo-JobAgentReportText -Value $CompaniesById[$CompanyId].canonical_name
    }
    return $CompanyId
}

function Test-JobAgentReportMatch {
    param([Parameter(Mandatory)][object]$Job)

    $result = [string](Get-JobAgentReportProperty -Object $Job.classification -Name 'result' -Default 'UNKNOWN')
    return (@('MATCH', 'POSSIBLE') -contains $result) -and (@('A', 'B', 'C') -contains [string]$Job.priority)
}

function Get-JobAgentReportPriorityExplanation {
    param([Parameter(Mandatory)][object]$Job)

    $classification = Get-JobAgentReportProperty -Object $Job -Name 'classification'
    $score = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $classification -Name 'score' -Default 'UNKNOWN')
    $result = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $classification -Name 'result' -Default 'UNKNOWN')
    $reasons = @((Get-JobAgentReportProperty -Object $classification -Name 'reasons' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $location = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object (Get-JobAgentReportProperty -Object $Job -Name 'location') -Name 'label' -Default 'UNKNOWN')
    $workModel = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'work_model' -Default 'UNKNOWN')
    $employmentType = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'employment_type' -Default 'UNKNOWN')
    $requirements = @((Get-JobAgentReportProperty -Object $Job -Name 'requirements' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add("Prioritaet $($Job.priority), Ergebnis $result, Score $score.")
    $parts.Add("Standort $location, Arbeitsmodell $workModel, Beschaeftigung $employmentType.")
    if ($reasons.Count -gt 0) {
        $parts.Add('Gruende: ' + (($reasons | Select-Object -First 3) -join '; ') + '.')
    }
    else {
        $parts.Add('Gruende: UNKNOWN.')
    }
    if ($requirements.Count -gt 0) {
        $parts.Add('Anforderungen: ' + (($requirements | Select-Object -First 3) -join '; ') + '.')
    }
    else {
        $parts.Add('Anforderungen: UNKNOWN.')
    }
    return ($parts.ToArray() -join ' ')
}

function Get-JobAgentReportAgeInfo {
    param(
        [Parameter()][AllowNull()][object]$PublishedAt,
        [Parameter()][AllowNull()][object]$FirstSeen,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $publishedText = ConvertTo-JobAgentReportText -Value $PublishedAt
    $firstSeenText = ConvertTo-JobAgentReportText -Value $FirstSeen
    $basis = if ($publishedText -ne 'UNKNOWN') { 'published_at' } elseif ($firstSeenText -ne 'UNKNOWN') { 'first_seen' } else { 'UNKNOWN' }
    $value = if ($basis -eq 'published_at') { $publishedText } elseif ($basis -eq 'first_seen') { $firstSeenText } else { 'UNKNOWN' }
    $ageDays = 'UNKNOWN'
    if ($value -ne 'UNKNOWN') {
        try {
            $baseline = [datetime]::Parse($value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
            $delta = $ReferenceTime.ToUniversalTime() - $baseline
            $days = [math]::Floor([math]::Max(0, $delta.TotalDays))
            $ageDays = [string][int]$days
        }
        catch {
            $ageDays = 'UNKNOWN'
        }
    }

    [pscustomobject]@{
        age_basis = $basis
        age_days = $ageDays
    }
}

function New-JobAgentReportJobEntry {
    param(
        [Parameter(Mandatory)][object]$Job,
        [Parameter(Mandatory)][hashtable]$CompaniesById,
        [Parameter()][AllowNull()][object]$ChangeEvent = $null,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $publishedAt = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'published_at' -Default 'UNKNOWN')
    $firstSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'first_seen' -Default 'UNKNOWN')
    $lastSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'last_seen' -Default 'UNKNOWN')
    $requirements = @((Get-JobAgentReportProperty -Object $Job -Name 'requirements' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    $ageInfo = Get-JobAgentReportAgeInfo -PublishedAt $publishedAt -FirstSeen $firstSeen -ReferenceTime $ReferenceTime

    [pscustomobject]@{
        job_id = [string]$Job.job_id
        company_id = [string]$Job.company_id
        company = Get-JobAgentReportCompanyName -CompaniesById $CompaniesById -CompanyId ([string]$Job.company_id)
        title = ConvertTo-JobAgentReportText -Value $Job.title
        priority = ConvertTo-JobAgentReportText -Value $Job.priority
        status = ConvertTo-JobAgentReportText -Value $Job.status
        location = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job.location -Name 'label' -Default 'UNKNOWN')
        work_model = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'work_model' -Default 'UNKNOWN')
        employment_type = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'employment_type' -Default 'UNKNOWN')
        published_at = $publishedAt
        first_seen = $firstSeen
        last_seen = $lastSeen
        salary = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'salary' -Default 'UNKNOWN')
        requirements = @($requirements)
        requirements_text = ConvertTo-JobAgentReportListText -Values $requirements -Fallback 'UNKNOWN' -MaxItems 3
        age_basis = [string]$ageInfo.age_basis
        age_days = [string]$ageInfo.age_days
        official_url = ConvertTo-JobAgentReportText -Value $Job.official_url
        changed_fields = @((Get-JobAgentReportProperty -Object $ChangeEvent -Name 'changed_fields' -Default @()) | ForEach-Object { [string]$_ })
        change_reason = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $ChangeEvent -Name 'reason' -Default 'UNKNOWN')
        priority_explanation = Get-JobAgentReportPriorityExplanation -Job $Job
    }
}

function New-JobAgentReportStatistics {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter()][AllowEmptyCollection()][object[]]$ActiveEntries = @(),
        [Parameter()][AllowEmptyCollection()][object[]]$NewCompanies = @()
    )

    $scanRun = @($Document.scan_runs | Where-Object { [string]$_.scan_run_id -eq $ScanRunId } | Select-Object -First 1)[0]
    $attempts = @($Document.scan_attempts | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $snapshots = @($Document.job_snapshots | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $changes = @($Document.change_events | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $uncertainSourceErrors = @('UNCLEAR_SOURCE', 'BLOCKED', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')
    $unreachableSourceErrors = @('NOT_REACHABLE', 'TIMEOUT')

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $scanRun -Name 'status' -Default 'UNKNOWN')
        companies_scanned = @($attempts | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count
        adapter_attempts = $attempts.Count
        checked_jobs = $snapshots.Count
        snapshots = $snapshots.Count
        new_jobs = @($changes | Where-Object event_type -eq 'JOB_CREATED').Count
        active_matching_jobs = @($ActiveEntries).Count
        updated_jobs = @($changes | Where-Object event_type -eq 'JOB_UPDATED').Count
        removed_or_closed_jobs = @($changes | Where-Object { @('JOB_REMOVED', 'JOB_CLOSED') -contains [string]$_.event_type }).Count
        invalid_jobs = @($changes | Where-Object event_type -eq 'JOB_INVALIDATED').Count
        new_companies = @($NewCompanies).Count
        uncertain_sources = @($attempts | Where-Object { $uncertainSourceErrors -contains [string]$_.error_class }).Count
        unreachable_career_pages = @($attempts | Where-Object { $unreachableSourceErrors -contains [string]$_.error_class }).Count
        errors = @($attempts | Where-Object { [string]$_.error_class -ne 'NONE' }).Count
    }
}

function New-JobAgentReportSourceIssueEntry {
    param(
        [Parameter(Mandatory)][object]$Attempt,
        [Parameter(Mandatory)][hashtable]$CompaniesById,
        [Parameter(Mandatory)][hashtable]$SourcesById
    )

    $source = $null
    if ($SourcesById.ContainsKey([string]$Attempt.source_id)) {
        $source = $SourcesById[[string]$Attempt.source_id]
    }
    $errorClass = ConvertTo-JobAgentReportText -Value $Attempt.error_class
    $category = switch ($errorClass) {
        { @('UNCLEAR_SOURCE', 'BLOCKED', 'PARSING_ERROR', 'TECHNICAL_LIMITATION') -contains $_ } { 'UNSICHER' ; break }
        { @('NOT_REACHABLE', 'TIMEOUT') -contains $_ } { 'NICHT_ERREICHBAR' ; break }
        default { 'HINWEIS' }
    }

    [pscustomobject]@{
        company = Get-JobAgentReportCompanyName -CompaniesById $CompaniesById -CompanyId ([string]$Attempt.company_id)
        source_id = ConvertTo-JobAgentReportText -Value $Attempt.source_id
        source_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $source -Name 'canonical_url' -Default 'UNKNOWN')
        status = ConvertTo-JobAgentReportText -Value $Attempt.status
        error_class = $errorClass
        category = $category
        retry_recommendation = ConvertTo-JobAgentReportText -Value $Attempt.retry_recommendation
        http_status = ConvertTo-JobAgentReportText -Value $Attempt.http_status
    }
}

function New-JobAgentDailyReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId
    )

    $scanRun = @($Document.scan_runs | Where-Object { [string]$_.scan_run_id -eq $ScanRunId } | Select-Object -First 1)[0]
    if ($null -eq $scanRun) {
        throw "ScanRun nicht gefunden: $ScanRunId"
    }

    $companiesById = @{}
    foreach ($company in @($Document.companies)) {
        $companiesById[[string]$company.company_id] = $company
    }
    $jobsById = @{}
    foreach ($job in @($Document.jobs)) {
        $jobsById[[string]$job.job_id] = $job
    }
    $sourcesById = @{}
    foreach ($source in @($Document.job_sources)) {
        $sourcesById[[string]$source.source_id] = $source
    }
    $events = @($Document.change_events | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $attempts = @($Document.scan_attempts | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $started = [datetime]::Parse([string]$scanRun.started_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $finished = if ($null -eq $scanRun.finished_at) { $started } else { [datetime]::Parse([string]$scanRun.finished_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }

    $createdEntries = New-Object System.Collections.Generic.List[object]
    $changedEntries = New-Object System.Collections.Generic.List[object]
    $removedEntries = New-Object System.Collections.Generic.List[object]

    foreach ($event in $events) {
        if (-not $jobsById.ContainsKey([string]$event.job_id)) {
            continue
        }
        $job = $jobsById[[string]$event.job_id]
        switch ([string]$event.event_type) {
            'JOB_CREATED' {
                if (Test-JobAgentReportMatch -Job $job) {
                    $createdEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event -ReferenceTime $finished))
                }
            }
            'JOB_UPDATED' {
                if (Test-JobAgentReportMatch -Job $job) {
                    $changedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event -ReferenceTime $finished))
                }
            }
            { @('JOB_REMOVED', 'JOB_CLOSED') -contains $_ } {
                if (Test-JobAgentReportMatch -Job $job) {
                    $removedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event -ReferenceTime $finished))
                }
            }
        }
    }

    $changedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($createdEntries.ToArray() + $changedEntries.ToArray() + $removedEntries.ToArray())) {
        [void]$changedIds.Add([string]$entry.job_id)
    }
    $activeEntries = @($Document.jobs |
        Where-Object { (@('NEW', 'ACTIVE', 'UPDATED') -contains [string]$_.status) -and (Test-JobAgentReportMatch -Job $_) -and (-not $changedIds.Contains([string]$_.job_id)) } |
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById -ReferenceTime $finished } |
        Sort-Object priority, company, title)
    $newCompanies = @($Document.companies |
        Where-Object {
            $created = [datetime]::Parse([string]$_.created_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
            ($created -ge $started) -and ($created -le $finished)
        } |
        Sort-Object canonical_name |
        ForEach-Object {
            [pscustomobject]@{
                company_id = [string]$_.company_id
                company = ConvertTo-JobAgentReportText -Value $_.canonical_name
                official_website_url = ConvertTo-JobAgentReportText -Value $_.official_website_url
                career_url = ConvertTo-JobAgentReportText -Value $_.career_url
                verification_status = ConvertTo-JobAgentReportText -Value $_.verification_status
            }
        })
    $sourceIssues = @($attempts |
        Where-Object { [string]$_.error_class -ne 'NONE' } |
        Sort-Object company_id, source_id |
        ForEach-Object { New-JobAgentReportSourceIssueEntry -Attempt $_ -CompaniesById $companiesById -SourcesById $sourcesById })

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        generated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        sections = [pscustomobject]@{
            new_matching_jobs = @($createdEntries.ToArray() | Sort-Object priority, company, title)
            active_matching_jobs = @($activeEntries)
            changed_jobs = @($changedEntries.ToArray() | Sort-Object priority, company, title)
            closed_or_removed_jobs = @($removedEntries.ToArray() | Sort-Object priority, company, title)
            new_companies = @($newCompanies)
            source_issues = @($sourceIssues)
        }
        statistics = New-JobAgentReportStatistics -Document $Document -ScanRunId $ScanRunId -ActiveEntries $activeEntries -NewCompanies $newCompanies
        coverage = New-JobAgentCoverageReport -Document $Document -Now $finished -MaxPriorityItems 10
    }
}

function Add-JobAgentReportMarkdownTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @(),
        [Parameter(Mandatory)][string]$EmptyText,
        [Parameter()][switch]$IncludeChange
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add($EmptyText)
        return
    }
    $header = if ($IncludeChange) { '| Prioritaet | Firma | Titel | Status | Standort | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Aenderung | Offizielle URL | Begruendung |' } else { '| Prioritaet | Firma | Titel | Status | Standort | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Offizielle URL | Begruendung |' }
    $separator = if ($IncludeChange) { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' } else { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' }
    [void]$Lines.Add($header)
    [void]$Lines.Add($separator)
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) { $change = $item.change_reason }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'UNKNOWN' } else { ('{0} ({1})' -f $item.age_days, $item.age_basis) }
        if ($IncludeChange) {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportMarkdownText $item.status),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportMarkdownText $item.work_model),
                    (ConvertTo-JobAgentReportMarkdownText $item.employment_type),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownText $change),
                    (ConvertTo-JobAgentReportMarkdownText $item.official_url),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority_explanation)
            )
            [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
        else {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportMarkdownText $item.status),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportMarkdownText $item.work_model),
                    (ConvertTo-JobAgentReportMarkdownText $item.employment_type),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownText $item.official_url),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority_explanation)
            )
            [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
    }
}

function Add-JobAgentReportSourceIssueMarkdownTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @()
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add('Keine Fehler oder unsicheren Quellen im Lauf.')
        return
    }

    [void]$Lines.Add('| Kategorie | Firma | Quelle | Status | Fehlerklasse | Retry | HTTP |')
    [void]$Lines.Add('|---|---|---|---|---|---|---:|')
    foreach ($item in $Items) {
        $cells = @(
            (ConvertTo-JobAgentReportMarkdownText $item.category),
            (ConvertTo-JobAgentReportMarkdownText $item.company),
            (ConvertTo-JobAgentReportMarkdownText $item.source_url),
            (ConvertTo-JobAgentReportMarkdownText $item.status),
            (ConvertTo-JobAgentReportMarkdownText $item.error_class),
            (ConvertTo-JobAgentReportMarkdownText $item.retry_recommendation),
            (ConvertTo-JobAgentReportMarkdownText $item.http_status)
        )
        [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
}

function Add-JobAgentReportCompanyMarkdownTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @()
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add('Keine neuen Unternehmen im Lauf.')
        return
    }
    [void]$Lines.Add('| Firma | Website | Karriere-URL | Verifikation |')
    [void]$Lines.Add('|---|---|---|---|')
    foreach ($item in $Items) {
        $cells = @(
                (ConvertTo-JobAgentReportMarkdownText $item.company),
                (ConvertTo-JobAgentReportMarkdownText $item.official_website_url),
                (ConvertTo-JobAgentReportMarkdownText $item.career_url),
                (ConvertTo-JobAgentReportMarkdownText $item.verification_status)
        )
        [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
}

function Add-JobAgentReportHtmlTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @(),
        [Parameter(Mandatory)][string]$EmptyText,
        [Parameter()][switch]$IncludeChange
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add('<p>' + (ConvertTo-JobAgentReportHtmlText $EmptyText) + '</p>')
        return
    }

    [void]$Lines.Add('<div class="table-wrap">')
    [void]$Lines.Add('<table class="job-table">')
    [void]$Lines.Add('<thead>')
    if ($IncludeChange) {
        [void]$Lines.Add('<tr><th>Prioritaet</th><th>Firma</th><th>Titel</th><th>Status</th><th>Standort</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Aenderung</th><th>Offizielle URL</th><th>Begruendung</th></tr>')
    }
    else {
        [void]$Lines.Add('<tr><th>Prioritaet</th><th>Firma</th><th>Titel</th><th>Status</th><th>Standort</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Offizielle URL</th><th>Begruendung</th></tr>')
    }
    [void]$Lines.Add('</thead>')
    [void]$Lines.Add('<tbody>')
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) {
            $change = $item.change_reason
        }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'UNKNOWN' } else { ('{0} Tage ({1})' -f $item.age_days, $item.age_basis) }
        $url = ConvertTo-JobAgentReportText -Value $item.official_url
        $urlCell = if ($url -eq 'UNKNOWN') {
            '<span class="unknown">UNKNOWN</span>'
        }
        else {
            '<a href="' + ([Net.WebUtility]::HtmlEncode($url)) + '">' + ([Net.WebUtility]::HtmlEncode($url)) + '</a>'
        }

        if ($IncludeChange) {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.status) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.work_model) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.employment_type) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $change) +
                '</td><td>' + $urlCell +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_explanation) +
                '</td></tr>'
            )
        }
        else {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.status) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.work_model) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.employment_type) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + $urlCell +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_explanation) +
                '</td></tr>'
            )
        }
    }
    [void]$Lines.Add('</tbody>')
    [void]$Lines.Add('</table>')
    [void]$Lines.Add('</div>')
}

function Add-JobAgentReportSourceIssueHtmlTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @()
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add('<p>Keine Fehler oder unsicheren Quellen im Lauf.</p>')
        return
    }

    [void]$Lines.Add('<div class="table-wrap">')
    [void]$Lines.Add('<table>')
    [void]$Lines.Add('<thead><tr><th>Kategorie</th><th>Firma</th><th>Quelle</th><th>Status</th><th>Fehlerklasse</th><th>Retry</th><th>HTTP</th></tr></thead>')
    [void]$Lines.Add('<tbody>')
    foreach ($item in $Items) {
        $sourceUrl = ConvertTo-JobAgentReportText -Value $item.source_url
        $sourceCell = if ($sourceUrl -eq 'UNKNOWN') { '<span class="unknown">UNKNOWN</span>' } else { '<a href="' + ([Net.WebUtility]::HtmlEncode($sourceUrl)) + '">' + ([Net.WebUtility]::HtmlEncode($sourceUrl)) + '</a>' }
        [void]$Lines.Add(
            '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.category) +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
            '</td><td>' + $sourceCell +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.status) +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.error_class) +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.retry_recommendation) +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.http_status) +
            '</td></tr>'
        )
    }
    [void]$Lines.Add('</tbody>')
    [void]$Lines.Add('</table>')
    [void]$Lines.Add('</div>')
}

function Add-JobAgentReportCompanyHtmlTable {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter()][AllowEmptyCollection()][object[]]$Items = @()
    )

    if ($Items.Count -eq 0) {
        [void]$Lines.Add('<p>Keine neuen Unternehmen im Lauf.</p>')
        return
    }

    [void]$Lines.Add('<div class="table-wrap">')
    [void]$Lines.Add('<table>')
    [void]$Lines.Add('<thead><tr><th>Firma</th><th>Website</th><th>Karriere-URL</th><th>Verifikation</th></tr></thead>')
    [void]$Lines.Add('<tbody>')
    foreach ($item in $Items) {
        $website = ConvertTo-JobAgentReportText -Value $item.official_website_url
        $career = ConvertTo-JobAgentReportText -Value $item.career_url
        $websiteCell = if ($website -eq 'UNKNOWN') { '<span class="unknown">UNKNOWN</span>' } else { '<a href="' + ([Net.WebUtility]::HtmlEncode($website)) + '">' + ([Net.WebUtility]::HtmlEncode($website)) + '</a>' }
        $careerCell = if ($career -eq 'UNKNOWN') { '<span class="unknown">UNKNOWN</span>' } else { '<a href="' + ([Net.WebUtility]::HtmlEncode($career)) + '">' + ([Net.WebUtility]::HtmlEncode($career)) + '</a>' }
        [void]$Lines.Add(
            '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
            '</td><td>' + $websiteCell +
            '</td><td>' + $careerCell +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.verification_status) +
            '</td></tr>'
        )
    }
    [void]$Lines.Add('</tbody>')
    [void]$Lines.Add('</table>')
    [void]$Lines.Add('</div>')
}

function ConvertTo-JobAgentDailyReportMarkdown {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add("# JobAgent Daily-Run-Bericht")
    [void]$lines.Add('')
    [void]$lines.Add("- ScanRun: $($Report.scan_run_id)")
    [void]$lines.Add("- Status: $($Report.statistics.status)")
    [void]$lines.Add("- Firmen: $($Report.statistics.companies_scanned)")
    [void]$lines.Add("- Adapterversuche: $($Report.statistics.adapter_attempts)")
    [void]$lines.Add("- Snapshots: $($Report.statistics.snapshots)")
    [void]$lines.Add("- Fehler: $($Report.statistics.errors)")
    [void]$lines.Add('')
    [void]$lines.Add('## Neue passende Stellen')
    Add-JobAgentReportMarkdownTable -Lines $lines -Items @($Report.sections.new_matching_jobs) -EmptyText 'Keine neuen passenden Stellen im Lauf.'
    [void]$lines.Add('')
    [void]$lines.Add('## Aktive passende Stellen')
    Add-JobAgentReportMarkdownTable -Lines $lines -Items @($Report.sections.active_matching_jobs) -EmptyText 'Keine unveraenderten aktiven passenden Stellen im Lauf.'
    [void]$lines.Add('')
    [void]$lines.Add('## Aenderungen')
    Add-JobAgentReportMarkdownTable -Lines $lines -Items @($Report.sections.changed_jobs) -EmptyText 'Keine geaenderten passenden Stellen im Lauf.' -IncludeChange
    [void]$lines.Add('')
    [void]$lines.Add('## Geschlossene oder entfernte Stellen')
    Add-JobAgentReportMarkdownTable -Lines $lines -Items @($Report.sections.closed_or_removed_jobs) -EmptyText 'Keine geschlossenen oder entfernten passenden Stellen im Lauf.' -IncludeChange
    [void]$lines.Add('')
    [void]$lines.Add('## Neue Unternehmen')
    Add-JobAgentReportCompanyMarkdownTable -Lines $lines -Items @($Report.sections.new_companies)
    [void]$lines.Add('')
    [void]$lines.Add('## Fehler und unsichere Quellen')
    Add-JobAgentReportSourceIssueMarkdownTable -Lines $lines -Items @($Report.sections.source_issues)
    [void]$lines.Add('')
    [void]$lines.Add('## Recherche-Statistik')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('checked_jobs', 'new_jobs', 'active_matching_jobs', 'updated_jobs', 'removed_or_closed_jobs', 'invalid_jobs', 'new_companies', 'uncertain_sources', 'unreachable_career_pages', 'errors')) {
        [void]$lines.Add(('| {0} | {1} |' -f $metric, $Report.statistics.$metric))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Coverage und Adapter-Backlog')
    [void]$lines.Add($Report.coverage.approximation_notice)
    [void]$lines.Add('')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('companies_total', 'with_career_url', 'without_career_url', 'successfully_scanned', 'failed_scanned', 'never_scanned', 'without_matching_jobs', 'with_matching_jobs', 'stale_or_unscanned')) {
        [void]$lines.Add(('| {0} | {1} |' -f $metric, $Report.coverage.metrics.$metric))
    }
    [void]$lines.Add('')
    [void]$lines.Add('### Naechste Scanprioritaeten')
    if (@($Report.coverage.scan_priority).Count -eq 0) {
        [void]$lines.Add('Keine Scanprioritaeten vorhanden.')
    }
    else {
        [void]$lines.Add('| Score | Firma | Aktion | Gruende |')
        [void]$lines.Add('|---:|---|---|---|')
        foreach ($item in @($Report.coverage.scan_priority | Select-Object -First 10)) {
            $cells = @(
                (ConvertTo-JobAgentReportMarkdownText $item.priority_score),
                (ConvertTo-JobAgentReportMarkdownText $item.company),
                (ConvertTo-JobAgentReportMarkdownText $item.next_action),
                (ConvertTo-JobAgentReportMarkdownText ((@($item.reasons) -join ', ')))
            )
            [void]$lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
    }
    [void]$lines.Add('')
    [void]$lines.Add('### Adapter- und Coverage-Backlog')
    if (@($Report.coverage.backlog).Count -eq 0) {
        [void]$lines.Add('Kein Coverage-Backlog vorhanden.')
    }
    else {
        [void]$lines.Add('| Score | Typ | Firma | Begruendung | Naechster Schritt |')
        [void]$lines.Add('|---:|---|---|---|---|')
        foreach ($item in @($Report.coverage.backlog | Select-Object -First 10)) {
            $cells = @(
                (ConvertTo-JobAgentReportMarkdownText $item.priority_score),
                (ConvertTo-JobAgentReportMarkdownText $item.kind),
                (ConvertTo-JobAgentReportMarkdownText $item.company),
                (ConvertTo-JobAgentReportMarkdownText $item.reason),
                (ConvertTo-JobAgentReportMarkdownText $item.next_step)
            )
            [void]$lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
    }

    return ($lines.ToArray() -join "`n")
}

function ConvertTo-JobAgentDailyReportHtml {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('<!DOCTYPE html>')
    [void]$lines.Add('<html lang="de">')
    [void]$lines.Add('<head>')
    [void]$lines.Add('<meta charset="utf-8">')
    [void]$lines.Add('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$lines.Add('<title>JobAgent Daily-Run-Bericht</title>')
    [void]$lines.Add('<style>')
    [void]$lines.Add(':root { color-scheme: light; --bg: #f4f1ea; --surface: #fffdf8; --surface-alt: #f7efe2; --line: #d8c7a9; --text: #1f2933; --muted: #5d6b78; --accent: #7a4b20; --ok: #155e3b; --warn: #8a4b0f; }')
    [void]$lines.Add('* { box-sizing: border-box; }')
    [void]$lines.Add('body { margin: 0; font-family: "Segoe UI", Tahoma, sans-serif; background: linear-gradient(180deg, #f7f2e8 0%, #efe6d6 100%); color: var(--text); }')
    [void]$lines.Add('main { max-width: 1440px; margin: 0 auto; padding: 24px 16px 40px; }')
    [void]$lines.Add('section { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 16px; margin-bottom: 16px; box-shadow: 0 8px 24px rgba(31, 41, 51, 0.06); }')
    [void]$lines.Add('h1, h2, h3 { margin: 0 0 12px; line-height: 1.2; }')
    [void]$lines.Add('h1 { font-size: clamp(1.8rem, 3vw, 2.6rem); color: var(--accent); }')
    [void]$lines.Add('h2 { font-size: 1.25rem; }')
    [void]$lines.Add('p, li { line-height: 1.5; }')
    [void]$lines.Add('.summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }')
    [void]$lines.Add('.card { background: var(--surface-alt); border: 1px solid var(--line); border-radius: 12px; padding: 12px; min-width: 0; }')
    [void]$lines.Add('.label { display: block; font-size: 0.85rem; color: var(--muted); margin-bottom: 4px; }')
    [void]$lines.Add('.value { display: block; font-size: 1.05rem; font-weight: 600; overflow-wrap: anywhere; }')
    [void]$lines.Add('.table-wrap { overflow-x: auto; }')
    [void]$lines.Add('table { width: 100%; border-collapse: collapse; min-width: 720px; }')
    [void]$lines.Add('.job-table { min-width: 1320px; }')
    [void]$lines.Add('th, td { text-align: left; vertical-align: top; padding: 10px 12px; border-bottom: 1px solid var(--line); overflow-wrap: anywhere; }')
    [void]$lines.Add('th { background: #f2e7d4; font-size: 0.92rem; }')
    [void]$lines.Add('tbody tr:nth-child(even) { background: rgba(122, 75, 32, 0.04); }')
    [void]$lines.Add('a { color: var(--accent); }')
    [void]$lines.Add('.unknown { color: var(--muted); font-style: italic; }')
    [void]$lines.Add('@media (max-width: 800px) { main { padding: 16px 12px 28px; } section { padding: 12px; } table { min-width: 640px; } .job-table { min-width: 1200px; } th, td { padding: 9px 10px; } }')
    [void]$lines.Add('</style>')
    [void]$lines.Add('</head>')
    [void]$lines.Add('<body>')
    [void]$lines.Add('<main>')
    [void]$lines.Add('<section>')
    [void]$lines.Add('<h1>JobAgent Daily-Run-Bericht</h1>')
    [void]$lines.Add('<div class="summary">')
    foreach ($item in @(
            @{ Label = 'ScanRun'; Value = $Report.scan_run_id },
            @{ Label = 'Status'; Value = $Report.statistics.status },
            @{ Label = 'Firmen'; Value = $Report.statistics.companies_scanned },
            @{ Label = 'Adapterversuche'; Value = $Report.statistics.adapter_attempts },
            @{ Label = 'Snapshots'; Value = $Report.statistics.snapshots },
            @{ Label = 'Fehler'; Value = $Report.statistics.errors }
        )) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportHtmlText $item.Label) + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $item.Value) + '</span></div>')
    }
    [void]$lines.Add('</div>')
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Neue passende Stellen</h2>')
    Add-JobAgentReportHtmlTable -Lines $lines -Items @($Report.sections.new_matching_jobs) -EmptyText 'Keine neuen passenden Stellen im Lauf.'
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Aktive passende Stellen</h2>')
    Add-JobAgentReportHtmlTable -Lines $lines -Items @($Report.sections.active_matching_jobs) -EmptyText 'Keine unveraenderten aktiven passenden Stellen im Lauf.'
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Aenderungen</h2>')
    Add-JobAgentReportHtmlTable -Lines $lines -Items @($Report.sections.changed_jobs) -EmptyText 'Keine geaenderten passenden Stellen im Lauf.' -IncludeChange
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Geschlossene oder entfernte Stellen</h2>')
    Add-JobAgentReportHtmlTable -Lines $lines -Items @($Report.sections.closed_or_removed_jobs) -EmptyText 'Keine geschlossenen oder entfernten passenden Stellen im Lauf.' -IncludeChange
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Neue Unternehmen</h2>')
    Add-JobAgentReportCompanyHtmlTable -Lines $lines -Items @($Report.sections.new_companies)
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Fehler und unsichere Quellen</h2>')
    Add-JobAgentReportSourceIssueHtmlTable -Lines $lines -Items @($Report.sections.source_issues)
    [void]$lines.Add('</section>')

    [void]$lines.Add('<section><h2>Recherche-Statistik</h2><div class="summary">')
    foreach ($metric in @('checked_jobs', 'new_jobs', 'active_matching_jobs', 'updated_jobs', 'removed_or_closed_jobs', 'invalid_jobs', 'new_companies', 'uncertain_sources', 'unreachable_career_pages', 'errors')) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportHtmlText $metric) + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $Report.statistics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div></section>')

    [void]$lines.Add('<section><h2>Coverage und Adapter-Backlog</h2>')
    [void]$lines.Add('<p>' + (ConvertTo-JobAgentReportHtmlText $Report.coverage.approximation_notice) + '</p>')
    [void]$lines.Add('<div class="summary">')
    foreach ($metric in @('companies_total', 'with_career_url', 'without_career_url', 'successfully_scanned', 'failed_scanned', 'never_scanned', 'without_matching_jobs', 'with_matching_jobs', 'stale_or_unscanned')) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportHtmlText $metric) + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $Report.coverage.metrics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div>')

    [void]$lines.Add('<h3>Naechste Scanprioritaeten</h3>')
    if (@($Report.coverage.scan_priority).Count -eq 0) {
        [void]$lines.Add('<p>Keine Scanprioritaeten vorhanden.</p>')
    }
    else {
        [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Score</th><th>Firma</th><th>Aktion</th><th>Gruende</th></tr></thead><tbody>')
        foreach ($item in @($Report.coverage.scan_priority | Select-Object -First 10)) {
            [void]$lines.Add('<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.next_action) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText ((@($item.reasons) -join ', '))) + '</td></tr>')
        }
        [void]$lines.Add('</tbody></table></div>')
    }

    [void]$lines.Add('<h3>Adapter- und Coverage-Backlog</h3>')
    if (@($Report.coverage.backlog).Count -eq 0) {
        [void]$lines.Add('<p>Kein Coverage-Backlog vorhanden.</p>')
    }
    else {
        [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Score</th><th>Typ</th><th>Firma</th><th>Begruendung</th><th>Naechster Schritt</th></tr></thead><tbody>')
        foreach ($item in @($Report.coverage.backlog | Select-Object -First 10)) {
            [void]$lines.Add('<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.kind) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.reason) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.next_step) + '</td></tr>')
        }
        [void]$lines.Add('</tbody></table></div>')
    }
    [void]$lines.Add('</section>')
    [void]$lines.Add('</main>')
    [void]$lines.Add('</body>')
    [void]$lines.Add('</html>')

    return ($lines.ToArray() -join "`n")
}

Export-ModuleMember -Function @(
    'ConvertTo-JobAgentDailyReportHtml',
    'ConvertTo-JobAgentDailyReportMarkdown',
    'New-JobAgentDailyReport'
)
