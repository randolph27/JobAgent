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

function ConvertTo-JobAgentReportDisplayLabel {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    $text = ConvertTo-JobAgentReportText -Value $Value
    if ($text -eq 'UNKNOWN') {
        return 'Unbekannt'
    }

    $key = $text.Trim().ToUpperInvariant()
    switch ($Domain) {
        'job_status' {
            switch ($key) {
                'NEW' { return 'Neu' }
                'ACTIVE' { return 'Aktiv' }
                'UPDATED' { return 'Aktualisiert' }
                'REMOVED' { return 'Entfernt' }
                'CLOSED' { return 'Geschlossen' }
            }
        }
        'scan_status' {
            switch ($key) {
                'SUCCESS' { return 'Erfolgreich' }
                'PARTIAL' { return 'Teilweise erfolgreich' }
                'FAILED' { return 'Fehlgeschlagen' }
                'RUNNING' { return 'Laeuft' }
            }
        }
        'work_model' {
            switch ($key) {
                'REMOTE' { return 'Remote' }
                'HYBRID' { return 'Hybrid' }
                'ONSITE' { return 'Vor Ort' }
            }
        }
        'employment_type' {
            switch ($key) {
                'FULL_TIME' { return 'Vollzeit' }
                'PART_TIME' { return 'Teilzeit' }
                'CONTRACT' { return 'Befristet/Vertrag' }
                'PERMANENT' { return 'Unbefristet' }
                'INTERNSHIP' { return 'Praktikum' }
            }
        }
        'error_class' {
            switch ($key) {
                'NONE' { return 'Keine' }
                'NOT_REACHABLE' { return 'Nicht erreichbar' }
                'TIMEOUT' { return 'Zeitueberschreitung' }
                'UNCLEAR_SOURCE' { return 'Quelle unklar' }
                'BLOCKED' { return 'Blockiert' }
                'PARSING_ERROR' { return 'Parsing-Fehler' }
                'TECHNICAL_LIMITATION' { return 'Technische Grenze' }
            }
        }
        'retry' {
            switch ($key) {
                'NONE' { return 'Nicht noetig' }
                'RETRY_NEXT_RUN' { return 'Im naechsten Lauf erneut pruefen' }
                'MANUAL_REVIEW' { return 'Manuell pruefen' }
            }
        }
        'age_basis' {
            switch ($key) {
                'PUBLISHED_AT' { return 'Veroeffentlicht' }
                'FIRST_SEEN' { return 'Erstmals erkannt' }
            }
        }
        'verification_status' {
            switch ($key) {
                'CAREER_URL_VERIFIED' { return 'Karriere-URL verifiziert' }
                'COMPANY_DOMAIN_VERIFIED' { return 'Firmendomain verifiziert' }
                'OFFICIAL_ATS_VERIFIED' { return 'Offizielles ATS verifiziert' }
                'VERIFIED' { return 'Verifiziert' }
                'UNVERIFIED' { return 'Nicht verifiziert' }
                'MISSING' { return 'Fehlt' }
            }
        }
        'action' {
            switch ($key) {
                'VERIFY_DISCOVERY_HINT' { return 'Discovery-Hinweis pruefen' }
                'FIND_CAREER_URL' { return 'Karriere-URL suchen' }
                'RETRY_SOURCE_SCAN' { return 'Quelle erneut scannen' }
                'SCAN_OFFICIAL_SOURCE' { return 'Offizielle Quelle scannen' }
                'ROTATION_RECHECK' { return 'Regulaer erneut pruefen' }
                'SCAN_ROTATION' { return 'Scan-Rotation' }
            }
        }
        'reason' {
            switch ($key) {
                'manual_review_discovery_hint' { return 'Discovery-Hinweis braucht manuelle Pruefung' }
                'missing_career_url' { return 'Karriere-URL fehlt' }
                'latest_scan_failed' { return 'Letzter Scan ist fehlgeschlagen' }
                'never_scanned' { return 'Noch nie gescannt' }
                'stale_scan' { return 'Scan ist faellig' }
                'recent_success_rotation_penalty' { return 'Kuerzlich erfolgreich gescannt' }
            }
        }
        'backlog_kind' {
            switch ($key) {
                'MANUAL_REVIEW_DISCOVERY' { return 'Discovery-Hinweis pruefen' }
                'CAREER_URL_DISCOVERY' { return 'Karriere-URL finden' }
                'ATS_OR_PORTAL_ADAPTER_REVIEW' { return 'ATS/Portal-Adapter pruefen' }
                'RETRY_LANE_REVIEW' { return 'Retry-Lane pruefen' }
                'STALE_SCAN_ROTATION' { return 'Faelligen Scan wiederholen' }
                'NO_MATCH_RECHECK' { return 'Ohne Treffer erneut pruefen' }
            }
        }
        'metric' {
            switch ($text) {
                'checked_jobs' { return 'Gepruefte Stellen' }
                'new_jobs' { return 'Neue Stellen' }
                'active_matching_jobs' { return 'Aktive passende Stellen' }
                'updated_jobs' { return 'Aktualisierte Stellen' }
                'removed_or_closed_jobs' { return 'Entfernte oder geschlossene Stellen' }
                'invalid_jobs' { return 'Ungueltige Stellen' }
                'new_companies' { return 'Neue Unternehmen' }
                'uncertain_sources' { return 'Unsichere Quellen' }
                'unreachable_career_pages' { return 'Nicht erreichbare Karriereportale' }
                'errors' { return 'Fehler' }
                'companies_total' { return 'Unternehmen gesamt' }
                'with_career_url' { return 'Mit Karriere-URL' }
                'without_career_url' { return 'Ohne Karriere-URL' }
                'successfully_scanned' { return 'Erfolgreich gescannt' }
                'failed_scanned' { return 'Scan fehlgeschlagen' }
                'never_scanned' { return 'Noch nie gescannt' }
                'without_matching_jobs' { return 'Ohne passende Stellen' }
                'with_matching_jobs' { return 'Mit passenden Stellen' }
                'stale_or_unscanned' { return 'Faellig oder ungescannt' }
            }
        }
    }

    return ('Unbekannt ({0})' -f $text)
}

function ConvertTo-JobAgentReportDisplayMarkdownText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    return ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDisplayLabel -Value $Value -Domain $Domain)
}

function ConvertTo-JobAgentReportDisplayHtmlText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    return ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDisplayLabel -Value $Value -Domain $Domain)
}

function Test-JobAgentReportHttpUrl {
    param([Parameter()][AllowNull()][object]$Url)

    if ($null -eq $Url -or [string]::IsNullOrWhiteSpace([string]$Url)) {
        return $false
    }
    $uri = $null
    if (-not [Uri]::TryCreate(([string]$Url).Trim(), [UriKind]::Absolute, [ref]$uri)) {
        return $false
    }
    return @('http', 'https') -contains $uri.Scheme
}

function New-JobAgentReportMissingLink {
    param([Parameter()][AllowEmptyString()][string]$Reason = 'Kein offizieller Link vorhanden.')

    [pscustomobject]@{
        link_type = 'missing'
        label = 'Kein Link'
        url = $null
        source_id = $null
        source_field = 'report.fail_closed'
        verification_status = 'MISSING'
        is_primary = $true
        is_clickable = $false
        review_only = $false
        reason = $Reason
    }
}

function Get-JobAgentReportProviderLink {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowEmptyCollection()][object[]]$JobSources = @(),
        [Parameter()][AllowEmptyString()][string]$PreferredSourceId = ''
    )

    $links = @(Get-JobAgentCoverageCompanyLinks -Company $Company -JobSources $JobSources)
    if ($links.Count -eq 0) {
        return New-JobAgentReportMissingLink
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredSourceId)) {
        $matchingSourceLink = @($links | Where-Object {
                [bool]$_.is_clickable -and [string]$_.source_id -eq $PreferredSourceId
            } | Select-Object -First 1)
        if ($matchingSourceLink.Count -eq 1) {
            return $matchingSourceLink[0]
        }
    }

    $primaryLink = @($links | Where-Object { [bool]$_.is_clickable -and [bool]$_.is_primary } | Select-Object -First 1)
    if ($primaryLink.Count -eq 1) {
        return $primaryLink[0]
    }

    $clickableLink = @($links | Where-Object { [bool]$_.is_clickable } | Select-Object -First 1)
    if ($clickableLink.Count -eq 1) {
        return $clickableLink[0]
    }

    return $links[0]
}

function ConvertTo-JobAgentReportMarkdownLink {
    param(
        [Parameter()][AllowNull()][object]$Url,
        [Parameter()][AllowEmptyString()][string]$Label = 'Link',
        [Parameter()][AllowEmptyString()][string]$Fallback = 'UNKNOWN'
    )

    if (-not (Test-JobAgentReportHttpUrl -Url $Url)) {
        return ConvertTo-JobAgentReportMarkdownText $Fallback
    }

    $safeLabel = ConvertTo-JobAgentReportMarkdownText $Label
    $safeUrl = ConvertTo-JobAgentReportMarkdownText ([string]$Url)
    return "[$safeLabel]($safeUrl)"
}

function ConvertTo-JobAgentReportProviderMarkdownLink {
    param([Parameter()][AllowNull()][object]$Link)

    if ($null -eq $Link) {
        return 'Kein offizieller Link'
    }
    $url = Get-JobAgentReportProperty -Object $Link -Name 'url'
    $label = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Link -Name 'label' -Default 'Link')
    if ([bool](Get-JobAgentReportProperty -Object $Link -Name 'is_clickable' -Default $false) -and (Test-JobAgentReportHttpUrl -Url $url)) {
        return ConvertTo-JobAgentReportMarkdownLink -Url $url -Label $label
    }
    $reason = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Link -Name 'reason' -Default 'Kein offizieller Link')
    return ConvertTo-JobAgentReportMarkdownText $reason
}

function ConvertTo-JobAgentReportHtmlLink {
    param(
        [Parameter()][AllowNull()][object]$Url,
        [Parameter()][AllowEmptyString()][string]$Label = 'Link',
        [Parameter()][AllowEmptyString()][string]$Fallback = 'UNKNOWN'
    )

    if (-not (Test-JobAgentReportHttpUrl -Url $Url)) {
        return '<span class="unknown">' + (ConvertTo-JobAgentReportHtmlText $Fallback) + '</span>'
    }
    return '<a href="' + ([Net.WebUtility]::HtmlEncode(([string]$Url).Trim())) + '" target="_blank" rel="noopener noreferrer">' + (ConvertTo-JobAgentReportHtmlText $Label) + '</a>'
}

function ConvertTo-JobAgentReportProviderHtmlLink {
    param([Parameter()][AllowNull()][object]$Link)

    if ($null -eq $Link) {
        return '<span class="unknown">Kein offizieller Link</span>'
    }
    $url = Get-JobAgentReportProperty -Object $Link -Name 'url'
    $label = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Link -Name 'label' -Default 'Link')
    if ([bool](Get-JobAgentReportProperty -Object $Link -Name 'is_clickable' -Default $false) -and (Test-JobAgentReportHttpUrl -Url $url)) {
        return ConvertTo-JobAgentReportHtmlLink -Url $url -Label $label
    }
    return '<span class="unknown">' + (ConvertTo-JobAgentReportHtmlText (Get-JobAgentReportProperty -Object $Link -Name 'reason' -Default 'Kein offizieller Link')) + '</span>'
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
    $resultRaw = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $classification -Name 'result' -Default 'UNKNOWN')
    $result = switch ($resultRaw) {
        'MATCH' { 'Passend' }
        'POSSIBLE' { 'Moeglich passend' }
        'REJECTED' { 'Abgelehnt' }
        default { ConvertTo-JobAgentReportDisplayLabel -Value $resultRaw -Domain 'classification_result' }
    }
    $reasons = @((Get-JobAgentReportProperty -Object $classification -Name 'reasons' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $location = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object (Get-JobAgentReportProperty -Object $Job -Name 'location') -Name 'label' -Default 'UNKNOWN')
    $workModel = ConvertTo-JobAgentReportDisplayLabel -Value (Get-JobAgentReportProperty -Object $Job -Name 'work_model' -Default 'UNKNOWN') -Domain 'work_model'
    $employmentType = ConvertTo-JobAgentReportDisplayLabel -Value (Get-JobAgentReportProperty -Object $Job -Name 'employment_type' -Default 'UNKNOWN') -Domain 'employment_type'
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
        [Parameter()][hashtable]$SourcesByCompanyId = @{},
        [Parameter()][AllowNull()][object]$ChangeEvent = $null,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $publishedAt = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'published_at' -Default 'UNKNOWN')
    $firstSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'first_seen' -Default 'UNKNOWN')
    $lastSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'last_seen' -Default 'UNKNOWN')
    $requirements = @((Get-JobAgentReportProperty -Object $Job -Name 'requirements' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    $ageInfo = Get-JobAgentReportAgeInfo -PublishedAt $publishedAt -FirstSeen $firstSeen -ReferenceTime $ReferenceTime
    $companyId = [string]$Job.company_id
    $company = if ($CompaniesById.ContainsKey($companyId)) { $CompaniesById[$companyId] } else { [pscustomobject]@{ company_id = $companyId; canonical_name = $companyId; verification_status = 'UNVERIFIED' } }
    $companySources = if ($SourcesByCompanyId.ContainsKey($companyId)) { @($SourcesByCompanyId[$companyId].ToArray()) } else { @() }
    $providerLink = Get-JobAgentReportProviderLink -Company $company -JobSources $companySources -PreferredSourceId ([string](Get-JobAgentReportProperty -Object $Job -Name 'source_id' -Default ''))

    [pscustomobject]@{
        job_id = [string]$Job.job_id
        company_id = $companyId
        company = Get-JobAgentReportCompanyName -CompaniesById $CompaniesById -CompanyId $companyId
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
        provider_link = $providerLink
        provider_label = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $providerLink -Name 'label' -Default 'Kein Link')
        provider_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $providerLink -Name 'url' -Default 'UNKNOWN')
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
    $isOfficialSource = [bool](Get-JobAgentReportProperty -Object $source -Name 'is_official' -Default $false)
    $sourceUrl = Get-JobAgentReportProperty -Object $source -Name 'canonical_url'
    $sourceLink = if ($isOfficialSource -and (Test-JobAgentReportHttpUrl -Url $sourceUrl)) {
        [pscustomobject]@{
            link_type = 'source'
            label = 'Quelle'
            url = ([string]$sourceUrl).Trim()
            source_id = [string]$Attempt.source_id
            source_field = 'job_sources.canonical_url'
            verification_status = 'VERIFIED'
            is_primary = $true
            is_clickable = $true
            review_only = $false
            reason = 'Offizielle JobSource im Store.'
        }
    }
    else {
        New-JobAgentReportMissingLink -Reason 'Quelle ist nicht als offizielle JobSource im Store verifiziert.'
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
        source_url = ConvertTo-JobAgentReportText -Value $sourceUrl
        source_link = $sourceLink
        source_review_reason = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $sourceLink -Name 'reason' -Default 'UNKNOWN')
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
    $sourcesByCompanyId = @{}
    foreach ($source in @($Document.job_sources)) {
        $sourcesById[[string]$source.source_id] = $source
        $companyId = [string]$source.company_id
        if (-not $sourcesByCompanyId.ContainsKey($companyId)) {
            $sourcesByCompanyId[$companyId] = [System.Collections.Generic.List[object]]::new()
        }
        $sourcesByCompanyId[$companyId].Add($source)
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
                    $createdEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ReferenceTime $finished))
                }
            }
            'JOB_UPDATED' {
                if (Test-JobAgentReportMatch -Job $job) {
                    $changedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ReferenceTime $finished))
                }
            }
            { @('JOB_REMOVED', 'JOB_CLOSED') -contains $_ } {
                if (Test-JobAgentReportMatch -Job $job) {
                    $removedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ReferenceTime $finished))
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
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ReferenceTime $finished } |
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
    $header = if ($IncludeChange) { '| Prioritaet | Firma | Titel | Status | Standort | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Aenderung | Stelle | Anbieter | Begruendung |' } else { '| Prioritaet | Firma | Titel | Status | Standort | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Stelle | Anbieter | Begruendung |' }
    $separator = if ($IncludeChange) { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' } else { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' }
    [void]$Lines.Add($header)
    [void]$Lines.Add($separator)
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) { $change = $item.change_reason }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'Unbekannt' } else { ('{0} Tage ({1})' -f $item.age_days, (ConvertTo-JobAgentReportDisplayLabel -Value $item.age_basis -Domain 'age_basis')) }
        if ($IncludeChange) {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.status -Domain 'job_status'),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.work_model -Domain 'work_model'),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.employment_type -Domain 'employment_type'),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownText $change),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.official_url -Label 'Stelle'),
                    (ConvertTo-JobAgentReportProviderMarkdownLink -Link $item.provider_link),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority_explanation)
            )
            [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
        else {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.status -Domain 'job_status'),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.work_model -Domain 'work_model'),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.employment_type -Domain 'employment_type'),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.official_url -Label 'Stelle'),
                    (ConvertTo-JobAgentReportProviderMarkdownLink -Link $item.provider_link),
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
            (ConvertTo-JobAgentReportProviderMarkdownLink -Link $item.source_link),
            (ConvertTo-JobAgentReportDisplayMarkdownText $item.status -Domain 'scan_status'),
            (ConvertTo-JobAgentReportDisplayMarkdownText $item.error_class -Domain 'error_class'),
            (ConvertTo-JobAgentReportDisplayMarkdownText $item.retry_recommendation -Domain 'retry'),
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
                (ConvertTo-JobAgentReportDisplayMarkdownText $item.verification_status -Domain 'verification_status')
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
        [void]$Lines.Add('<tr><th>Prioritaet</th><th>Firma</th><th>Titel</th><th>Status</th><th>Standort</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Aenderung</th><th>Stelle</th><th>Anbieter</th><th>Begruendung</th></tr>')
    }
    else {
        [void]$Lines.Add('<tr><th>Prioritaet</th><th>Firma</th><th>Titel</th><th>Status</th><th>Standort</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Stelle</th><th>Anbieter</th><th>Begruendung</th></tr>')
    }
    [void]$Lines.Add('</thead>')
    [void]$Lines.Add('<tbody>')
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) {
            $change = $item.change_reason
        }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'Unbekannt' } else { ('{0} Tage ({1})' -f $item.age_days, (ConvertTo-JobAgentReportDisplayLabel -Value $item.age_basis -Domain 'age_basis')) }
        $urlCell = ConvertTo-JobAgentReportHtmlLink -Url $item.official_url -Label 'Stelle'
        $providerCell = ConvertTo-JobAgentReportProviderHtmlLink -Link $item.provider_link

        if ($IncludeChange) {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.status -Domain 'job_status') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.work_model -Domain 'work_model') +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.employment_type -Domain 'employment_type') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $change) +
                '</td><td>' + $urlCell +
                '</td><td>' + $providerCell +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_explanation) +
                '</td></tr>'
            )
        }
        else {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.status -Domain 'job_status') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.work_model -Domain 'work_model') +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.employment_type -Domain 'employment_type') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + $urlCell +
                '</td><td>' + $providerCell +
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
        $sourceCell = ConvertTo-JobAgentReportProviderHtmlLink -Link $item.source_link
        [void]$Lines.Add(
            '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.category) +
            '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
            '</td><td>' + $sourceCell +
            '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.status -Domain 'scan_status') +
            '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.error_class -Domain 'error_class') +
            '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.retry_recommendation -Domain 'retry') +
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
        $websiteCell = ConvertTo-JobAgentReportHtmlLink -Url $item.official_website_url -Label 'Website'
        $careerCell = ConvertTo-JobAgentReportHtmlLink -Url $item.career_url -Label 'Karriere'
        [void]$Lines.Add(
            '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
            '</td><td>' + $websiteCell +
            '</td><td>' + $careerCell +
            '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.verification_status -Domain 'verification_status') +
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
    [void]$lines.Add("- Status: $(ConvertTo-JobAgentReportDisplayLabel -Value $Report.statistics.status -Domain 'scan_status')")
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
        [void]$lines.Add(('| {0} | {1} |' -f (ConvertTo-JobAgentReportDisplayLabel -Value $metric -Domain 'metric'), $Report.statistics.$metric))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Coverage und Adapter-Backlog')
    [void]$lines.Add($Report.coverage.approximation_notice)
    [void]$lines.Add('')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('companies_total', 'with_career_url', 'without_career_url', 'successfully_scanned', 'failed_scanned', 'never_scanned', 'without_matching_jobs', 'with_matching_jobs', 'stale_or_unscanned')) {
        [void]$lines.Add(('| {0} | {1} |' -f (ConvertTo-JobAgentReportDisplayLabel -Value $metric -Domain 'metric'), $Report.coverage.metrics.$metric))
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
                (ConvertTo-JobAgentReportDisplayMarkdownText $item.next_action -Domain 'action'),
                (ConvertTo-JobAgentReportMarkdownText ((@($item.reasons | ForEach-Object { ConvertTo-JobAgentReportDisplayLabel -Value $_ -Domain 'reason' }) -join ', ')))
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
                (ConvertTo-JobAgentReportDisplayMarkdownText $item.kind -Domain 'backlog_kind'),
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
            @{ Label = 'Status'; Value = (ConvertTo-JobAgentReportDisplayLabel -Value $Report.statistics.status -Domain 'scan_status') },
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
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportDisplayHtmlText $metric -Domain 'metric') + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $Report.statistics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div></section>')

    [void]$lines.Add('<section><h2>Coverage und Adapter-Backlog</h2>')
    [void]$lines.Add('<p>' + (ConvertTo-JobAgentReportHtmlText $Report.coverage.approximation_notice) + '</p>')
    [void]$lines.Add('<div class="summary">')
    foreach ($metric in @('companies_total', 'with_career_url', 'without_career_url', 'successfully_scanned', 'failed_scanned', 'never_scanned', 'without_matching_jobs', 'with_matching_jobs', 'stale_or_unscanned')) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportDisplayHtmlText $metric -Domain 'metric') + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $Report.coverage.metrics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div>')

    [void]$lines.Add('<h3>Naechste Scanprioritaeten</h3>')
    if (@($Report.coverage.scan_priority).Count -eq 0) {
        [void]$lines.Add('<p>Keine Scanprioritaeten vorhanden.</p>')
    }
    else {
        [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Score</th><th>Firma</th><th>Aktion</th><th>Gruende</th></tr></thead><tbody>')
        foreach ($item in @($Report.coverage.scan_priority | Select-Object -First 10)) {
            [void]$lines.Add('<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) + '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.next_action -Domain 'action') + '</td><td>' + (ConvertTo-JobAgentReportHtmlText ((@($item.reasons | ForEach-Object { ConvertTo-JobAgentReportDisplayLabel -Value $_ -Domain 'reason' }) -join ', '))) + '</td></tr>')
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
            [void]$lines.Add('<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.kind -Domain 'backlog_kind') + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.reason) + '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.next_step) + '</td></tr>')
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
