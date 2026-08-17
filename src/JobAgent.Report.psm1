#requires -Version 7.4

Set-StrictMode -Version 3.0

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

function New-JobAgentReportJobEntry {
    param(
        [Parameter(Mandatory)][object]$Job,
        [Parameter(Mandatory)][hashtable]$CompaniesById,
        [Parameter()][AllowNull()][object]$ChangeEvent = $null
    )

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
        official_url = ConvertTo-JobAgentReportText -Value $Job.official_url
        changed_fields = @((Get-JobAgentReportProperty -Object $ChangeEvent -Name 'changed_fields' -Default @()) | ForEach-Object { [string]$_ })
        change_reason = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $ChangeEvent -Name 'reason' -Default 'UNKNOWN')
        priority_explanation = Get-JobAgentReportPriorityExplanation -Job $Job
    }
}

function New-JobAgentReportStatistics {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId
    )

    $scanRun = @($Document.scan_runs | Where-Object { [string]$_.scan_run_id -eq $ScanRunId } | Select-Object -First 1)[0]
    $attempts = @($Document.scan_attempts | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $snapshots = @($Document.job_snapshots | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })
    $changes = @($Document.change_events | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $scanRun -Name 'status' -Default 'UNKNOWN')
        companies_scanned = @($attempts | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count
        adapter_attempts = $attempts.Count
        snapshots = $snapshots.Count
        new_jobs = @($changes | Where-Object event_type -eq 'JOB_CREATED').Count
        updated_jobs = @($changes | Where-Object event_type -eq 'JOB_UPDATED').Count
        removed_or_closed_jobs = @($changes | Where-Object { @('JOB_REMOVED', 'JOB_CLOSED') -contains [string]$_.event_type }).Count
        invalid_jobs = @($changes | Where-Object event_type -eq 'JOB_INVALIDATED').Count
        errors = @($attempts | Where-Object { [string]$_.error_class -ne 'NONE' }).Count
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
    $events = @($Document.change_events | Where-Object { [string]$_.scan_run_id -eq $ScanRunId })

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
                    $createdEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event))
                }
            }
            'JOB_UPDATED' {
                if (Test-JobAgentReportMatch -Job $job) {
                    $changedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event))
                }
            }
            { @('JOB_REMOVED', 'JOB_CLOSED') -contains $_ } {
                if (Test-JobAgentReportMatch -Job $job) {
                    $removedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -ChangeEvent $event))
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
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById } |
        Sort-Object priority, company, title)

    $started = [datetime]::Parse([string]$scanRun.started_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $finished = if ($null -eq $scanRun.finished_at) { $started } else { [datetime]::Parse([string]$scanRun.finished_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
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

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        generated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        sections = [pscustomobject]@{
            new_matching_jobs = @($createdEntries.ToArray() | Sort-Object priority, company, title)
            active_matching_jobs = @($activeEntries)
            changed_jobs = @($changedEntries.ToArray() | Sort-Object priority, company, title)
            closed_or_removed_jobs = @($removedEntries.ToArray() | Sort-Object priority, company, title)
            new_companies = @($newCompanies)
        }
        statistics = New-JobAgentReportStatistics -Document $Document -ScanRunId $ScanRunId
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
    $header = if ($IncludeChange) { '| Prioritaet | Firma | Titel | Status | Standort | Aenderung | Offizielle URL | Begruendung |' } else { '| Prioritaet | Firma | Titel | Status | Standort | Offizielle URL | Begruendung |' }
    $separator = if ($IncludeChange) { '|---|---|---|---|---|---|---|---|' } else { '|---|---|---|---|---|---|---|' }
    [void]$Lines.Add($header)
    [void]$Lines.Add($separator)
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) { $change = $item.change_reason }
        if ($IncludeChange) {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportMarkdownText $item.status),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
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
                    (ConvertTo-JobAgentReportMarkdownText $item.official_url),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority_explanation)
            )
            [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
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
    [void]$lines.Add('## Recherche-Statistik')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('new_jobs', 'updated_jobs', 'removed_or_closed_jobs', 'invalid_jobs', 'errors')) {
        [void]$lines.Add(('| {0} | {1} |' -f $metric, $Report.statistics.$metric))
    }

    return ($lines.ToArray() -join "`n")
}

Export-ModuleMember -Function @(
    'ConvertTo-JobAgentDailyReportMarkdown',
    'New-JobAgentDailyReport'
)
