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
                'DUE_BY_NEXT_SCAN_AT_THEN_PRIORITY' { return 'Faellig nach next_scan_at, danach Prioritaet' }
                'EXPLICIT_COMPANY_IDS' { return 'Explizite Firmenauswahl' }
                'DUE_BY_NEXT_SCAN_AT_THEN_ACQUISITION' { return 'Faellig nach next_scan_at plus neue Akquise' }
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
                'companies_selected' { return 'Firmen im Lauf' }
                'companies_due' { return 'Faellige Firmen' }
                'companies_skipped' { return 'Uebersprungene Firmen' }
                'run_limit' { return 'Limit' }
                'selection_reason' { return 'Auswahlgrund' }
                'checked_jobs' { return 'Gepruefte Stellen' }
                'captured_jobs_total' { return 'Erfasste Stellen gesamt' }
                'profile_matching_jobs_total' { return 'Profiltreffer gesamt' }
                'captured_jobs_this_run' { return 'Erfasste Stellen im Lauf' }
                'profile_matching_jobs_this_run' { return 'Profiltreffer im Lauf' }
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
                'sources_total' { return 'Quellen gesamt' }
                'official_sources' { return 'Offizielle Quellen' }
                'career_sources' { return 'Karrierequellen' }
                'ats_sources' { return 'ATS-Quellen' }
                'discovery_sources' { return 'Discovery-Hinweise' }
                'verified_sources' { return 'Verifizierte Quellen' }
                'unverified_sources' { return 'Offene Quellen' }
                'blocked_sources' { return 'Blockierte Quellen' }
                'retry_open_sources' { return 'Retry offen' }
                'sources_attempted_latest_run' { return 'Im letzten Lauf versucht' }
                'sources_succeeded_latest_run' { return 'Im letzten Lauf gescannt' }
                'sources_failed_latest_run' { return 'Im letzten Lauf fehlgeschlagen' }
                'never_scanned_sources' { return 'Nie gescannte Quellen' }
                'stale_sources' { return 'Faellige Quellen' }
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

function ConvertTo-JobAgentReportDescriptionText {
    param([Parameter()][AllowNull()][object]$Value)

    $text = ConvertTo-JobAgentReportText -Value $Value
    if ($text -eq 'UNKNOWN') {
        return 'Keine Beschreibung aus offizieller Quelle verfuegbar'
    }
    return $text
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

function Test-JobAgentReportCapturedJob {
    param([Parameter(Mandatory)][object]$Job)

    $validity = [string](Get-JobAgentReportProperty -Object (Get-JobAgentReportProperty -Object $Job -Name 'job_validity') -Name 'result' -Default 'UNKNOWN')
    return $validity -ne 'REJECTED'
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
    $description = ConvertTo-JobAgentReportDescriptionText -Value (Get-JobAgentReportProperty -Object $Job -Name 'description' -Default (Get-JobAgentReportProperty -Object $Job -Name 'summary' -Default 'UNKNOWN'))

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
    $parts.Add('Kurzprofil: ' + $description + '.')
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
    $description = ConvertTo-JobAgentReportDescriptionText -Value (Get-JobAgentReportProperty -Object $Job -Name 'description' -Default (Get-JobAgentReportProperty -Object $Job -Name 'summary' -Default 'UNKNOWN'))
    $ageInfo = Get-JobAgentReportAgeInfo -PublishedAt $publishedAt -FirstSeen $firstSeen -ReferenceTime $ReferenceTime
    $companyId = [string]$Job.company_id
    $company = if ($CompaniesById.ContainsKey($companyId)) { $CompaniesById[$companyId] } else { [pscustomobject]@{ company_id = $companyId; canonical_name = $companyId; verification_status = 'UNVERIFIED' } }
    $companySources = if ($SourcesByCompanyId.ContainsKey($companyId)) { @($SourcesByCompanyId[$companyId].ToArray()) } else { @() }
    $providerLink = Get-JobAgentReportProviderLink -Company $company -JobSources $companySources -PreferredSourceId ([string](Get-JobAgentReportProperty -Object $Job -Name 'source_id' -Default ''))

    $location = Get-JobAgentReportProperty -Object $Job -Name 'location'
    $locationCity = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $location -Name 'city' -Default 'UNKNOWN')
    $locationRegion = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $location -Name 'region' -Default 'UNKNOWN')
    $targetArea = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $location -Name 'target_area' -Default 'UNKNOWN')
    $areaFacets = [System.Collections.Generic.List[string]]::new()
    if ($targetArea -ne 'UNKNOWN') {
        $areaFacets.Add($targetArea)
    }
    else {
        $areaFacets.Add('UNKNOWN')
    }
    if ($locationCity -eq 'Freising') {
        $areaFacets.Add('FREISING_CITY')
    }
    if ($locationRegion -match '(?i)landkreis\s+freising') {
        $areaFacets.Add('FREISING_COUNTY')
    }
    if (($targetArea -eq 'FREISING') -and ($areaFacets.Count -eq 1)) {
        $areaFacets.Add('FREISING_UNSPECIFIED')
    }

    [pscustomobject]@{
        job_id = [string]$Job.job_id
        company_id = $companyId
        company = Get-JobAgentReportCompanyName -CompaniesById $CompaniesById -CompanyId $companyId
        title = ConvertTo-JobAgentReportText -Value $Job.title
        job_category = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'job_category' -Default (Get-JobAgentReportProperty -Object $Job.classification -Name 'category' -Default 'UNKNOWN'))
        priority = ConvertTo-JobAgentReportText -Value $Job.priority
        status = ConvertTo-JobAgentReportText -Value $Job.status
        location = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $location -Name 'label' -Default 'UNKNOWN')
        location_city = $locationCity
        location_region = $locationRegion
        target_area = $targetArea
        area_facets = @($areaFacets.ToArray() | Select-Object -Unique)
        work_model = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'work_model' -Default 'UNKNOWN')
        employment_type = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'employment_type' -Default 'UNKNOWN')
        work_time = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'work_time' -Default 'UNKNOWN')
        published_at = $publishedAt
        first_seen = $firstSeen
        last_seen = $lastSeen
        salary = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'salary' -Default 'UNKNOWN')
        requirements = @($requirements)
        requirements_text = ConvertTo-JobAgentReportListText -Values $requirements -Fallback 'UNKNOWN' -MaxItems 3
        description = $description
        description_source = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'description_source' -Default 'NONE')
        age_basis = [string]$ageInfo.age_basis
        age_days = [string]$ageInfo.age_days
        official_url = ConvertTo-JobAgentReportText -Value $Job.official_url
        career_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $company -Name 'career_url' -Default 'UNKNOWN')
        provider_link = $providerLink
        provider_label = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $providerLink -Name 'label' -Default 'Kein Link')
        provider_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $providerLink -Name 'url' -Default 'UNKNOWN')
        changed_fields = @((Get-JobAgentReportProperty -Object $ChangeEvent -Name 'changed_fields' -Default @()) | ForEach-Object { [string]$_ })
        change_reason = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $ChangeEvent -Name 'reason' -Default 'UNKNOWN')
        priority_explanation = Get-JobAgentReportPriorityExplanation -Job $Job
    }
}

function New-JobAgentReportCompanyEntry {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowEmptyCollection()][object[]]$JobSources = @()
    )

    $providerLink = Get-JobAgentReportProviderLink -Company $Company -JobSources $JobSources
    $locations = @((Get-JobAgentReportProperty -Object $Company -Name 'locations' -Default @()) | ForEach-Object {
            ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $_ -Name 'label' -Default 'UNKNOWN')
        } | Select-Object -Unique)
    [pscustomobject]@{
        company_id = [string]$Company.company_id
        company = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Company -Name 'canonical_name')
        locations = @($locations)
        locations_text = ConvertTo-JobAgentReportListText -Values $locations -Fallback 'UNKNOWN' -MaxItems 20
        official_website_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Company -Name 'official_website_url')
        career_url = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Company -Name 'career_url')
        verification_status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Company -Name 'verification_status')
        scan_status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Company -Name 'scan_status')
        provider_link = $providerLink
    }
}

function ConvertTo-JobAgentReportClientDataJson {
    param([Parameter(Mandatory)][object]$Value)

    $json = $Value | ConvertTo-Json -Depth 20 -Compress
    return $json.Replace('<', '\\u003c').Replace('>', '\\u003e').Replace('&', '\\u0026')
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
    $jobsById = @{}
    foreach ($job in @($Document.jobs)) {
        $jobsById[[string]$job.job_id] = $job
    }
    $capturedJobs = @($Document.jobs | Where-Object { Test-JobAgentReportCapturedJob -Job $_ })
    $capturedJobsThisRun = @($snapshots | Where-Object {
            $jobsById.ContainsKey([string]$_.job_id) -and (Test-JobAgentReportCapturedJob -Job $jobsById[[string]$_.job_id])
        })
    $profileMatchingJobsThisRun = @($capturedJobsThisRun | Where-Object { Test-JobAgentReportMatch -Job $jobsById[[string]$_.job_id] })
    $uncertainSourceErrors = @('UNCLEAR_SOURCE', 'BLOCKED', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')
    $unreachableSourceErrors = @('NOT_REACHABLE', 'TIMEOUT')

    $selection = Get-JobAgentReportProperty -Object $scanRun -Name 'selection_summary'
    $companiesInAttempts = @($attempts | ForEach-Object { [string]$_.company_id } | Select-Object -Unique).Count

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $scanRun -Name 'status' -Default 'UNKNOWN')
        companies_total = if ($null -ne $selection) { [int](Get-JobAgentReportProperty -Object $selection -Name 'companies_total' -Default @($Document.companies).Count) } else { @($Document.companies).Count }
        companies_scanned = $companiesInAttempts
        companies_selected = if ($null -ne $selection) { [int](Get-JobAgentReportProperty -Object $selection -Name 'companies_selected' -Default $companiesInAttempts) } else { $companiesInAttempts }
        companies_due = if ($null -ne $selection) { [int](Get-JobAgentReportProperty -Object $selection -Name 'companies_due' -Default 0) } else { 0 }
        companies_skipped = if ($null -ne $selection) { [int](Get-JobAgentReportProperty -Object $selection -Name 'companies_skipped' -Default 0) } else { 0 }
        run_limit = if ($null -ne $selection) { [int](Get-JobAgentReportProperty -Object $selection -Name 'limit' -Default $companiesInAttempts) } else { $companiesInAttempts }
        selection_reason = if ($null -ne $selection) { ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $selection -Name 'selection_reason' -Default 'UNKNOWN') } else { 'UNKNOWN' }
        adapter_attempts = $attempts.Count
        checked_jobs = $snapshots.Count
        snapshots = $snapshots.Count
        captured_jobs_total = $capturedJobs.Count
        profile_matching_jobs_total = @($capturedJobs | Where-Object { Test-JobAgentReportMatch -Job $_ }).Count
        captured_jobs_this_run = $capturedJobsThisRun.Count
        profile_matching_jobs_this_run = $profileMatchingJobsThisRun.Count
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

function New-JobAgentReportCaptureManifest {
    param(
        [Parameter(Mandatory)][object]$ScanRun,
        [Parameter()][AllowEmptyCollection()][object[]]$Attempts = @()
    )

    $scope = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $ScanRun -Name 'collection_scope' -Default 'UNKNOWN')
    $searchTerms = @((Get-JobAgentReportProperty -Object $ScanRun -Name 'search_terms' -Default @()) | ForEach-Object { [string]$_ })
    $completeAttempts = @($Attempts | Where-Object { ([string]$_.status -eq 'SUCCESS') -and ([string]$_.error_class -eq 'NONE') -and ([bool](Get-JobAgentReportProperty -Object $_ -Name 'scan_complete' -Default $false)) })
    $partialAttempts = @($Attempts | Where-Object { ([string]$_.status -eq 'PARTIAL') -or (([string]$_.status -eq 'SUCCESS') -and (-not [bool](Get-JobAgentReportProperty -Object $_ -Name 'scan_complete' -Default $false))) })
    $failedAttempts = @($Attempts | Where-Object { [string]$_.status -eq 'FAILED' })
    $selection = Get-JobAgentReportProperty -Object $ScanRun -Name 'selection_summary'
    $skipped = @((Get-JobAgentReportProperty -Object $selection -Name 'skipped' -Default @()))

    [pscustomobject]@{
        collection_scope = $scope
        search_terms = @($searchTerms)
        run_status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $ScanRun -Name 'status' -Default 'UNKNOWN')
        attempted_sources = $Attempts.Count
        complete_sources = $completeAttempts.Count
        partial_sources = $partialAttempts.Count
        failed_sources = $failedAttempts.Count
        skipped_companies = $skipped.Count
        completion_boundary = if (($partialAttempts.Count -eq 0) -and ($failedAttempts.Count -eq 0) -and ($skipped.Count -eq 0) -and ($scope -eq 'ALL_ROLES')) { 'COMPLETE_FOR_SELECTED_OFFICIAL_SOURCES' } else { 'LIMITED_OR_PARTIAL' }
        limitations = @(
            if ($scope -ne 'ALL_ROLES') { 'Explizite Suchbegriffe begrenzen die Erfassung auf den angegebenen Scope.' }
            if ($partialAttempts.Count -gt 0) { 'Mindestens eine Quelle war unvollstaendig; fehlende Jobs duerfen nicht als abwesend gelten.' }
            if ($failedAttempts.Count -gt 0) { 'Mindestens eine Quelle ist fehlgeschlagen; bestehende Jobs dieser Quelle bleiben erhalten.' }
            if ($skipped.Count -gt 0) { 'Nicht alle auswahlfaehigen Firmen wurden in diesem Lauf verarbeitet.' }
        )
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
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter()][AllowNull()][object]$SourceRegistry = $null,
        [Parameter()][AllowNull()][object]$HintStore = $null
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
    $allActiveEntries = @($Document.jobs |
        Where-Object { (@('NEW', 'ACTIVE', 'UPDATED') -contains [string]$_.status) -and (Test-JobAgentReportCapturedJob -Job $_) } |
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ReferenceTime $finished } |
        Sort-Object title, company, location, last_seen, job_id)
    $allCompanies = @($Document.companies |
        ForEach-Object {
            $companyId = [string]$_.company_id
            $companySources = if ($sourcesByCompanyId.ContainsKey($companyId)) { @($sourcesByCompanyId[$companyId].ToArray()) } else { @() }
            New-JobAgentReportCompanyEntry -Company $_ -JobSources $companySources
        } |
        Sort-Object company, company_id)
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

    if ($null -eq $SourceRegistry) {
        $sourceRegistryPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'data\jobagent\company-discovery.sources.json'
        if (Test-Path -LiteralPath $sourceRegistryPath -PathType Leaf) {
            $SourceRegistry = Get-Content -Raw -LiteralPath $sourceRegistryPath | ConvertFrom-Json -Depth 100
        }
    }
    if ($null -eq $HintStore) {
        $hintStorePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'data\jobagent\company-discovery.hints.json'
        if (Test-Path -LiteralPath $hintStorePath -PathType Leaf) {
            $HintStore = Get-Content -Raw -LiteralPath $hintStorePath | ConvertFrom-Json -Depth 100
        }
    }

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        generated_at = $finished.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        sections = [pscustomobject]@{
            companies = @($allCompanies)
            active_jobs = @($allActiveEntries)
            new_matching_jobs = @($createdEntries.ToArray() | Sort-Object priority, company, title)
            active_matching_jobs = @($activeEntries)
            changed_jobs = @($changedEntries.ToArray() | Sort-Object priority, company, title)
            closed_or_removed_jobs = @($removedEntries.ToArray() | Sort-Object priority, company, title)
            new_companies = @($newCompanies)
            source_issues = @($sourceIssues)
        }
        statistics = New-JobAgentReportStatistics -Document $Document -ScanRunId $ScanRunId -ActiveEntries $activeEntries -NewCompanies $newCompanies
        capture_manifest = New-JobAgentReportCaptureManifest -ScanRun $scanRun -Attempts $attempts
        coverage = New-JobAgentCoverageReport -Document $Document -SourceRegistry $SourceRegistry -HintStore $HintStore -Now $finished -MaxPriorityItems 10
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
    $header = if ($IncludeChange) { '| Titel | Firma | Standort | Prioritaet | Status | Offizielle Stellen-URL | Karriere-URL | Quelle | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Kurzprofil | Aenderung | Begruendung |' } else { '| Titel | Firma | Standort | Prioritaet | Status | Offizielle Stellen-URL | Karriere-URL | Quelle | Arbeitsmodell | Beschaeftigung | Veroeffentlicht | Erkannt | Letztmals gesehen | Alter (Tage/Basis) | Gehalt | Anforderungen | Kurzprofil | Begruendung |' }
    $separator = if ($IncludeChange) { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' } else { '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|' }
    [void]$Lines.Add($header)
    [void]$Lines.Add($separator)
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) { $change = $item.change_reason }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'Unbekannt' } else { ('{0} Tage ({1})' -f $item.age_days, (ConvertTo-JobAgentReportDisplayLabel -Value $item.age_basis -Domain 'age_basis')) }
        if ($IncludeChange) {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.status -Domain 'job_status'),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.official_url -Label 'Offizielle Stellen-URL'),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.career_url -Label 'Karriere-URL'),
                    (ConvertTo-JobAgentReportProviderMarkdownLink -Link $item.provider_link),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.work_model -Domain 'work_model'),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.employment_type -Domain 'employment_type'),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownText $item.description),
                    (ConvertTo-JobAgentReportMarkdownText $change),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority_explanation)
            )
            [void]$Lines.Add('| ' + ($cells -join ' | ') + ' |')
        }
        else {
            $cells = @(
                    (ConvertTo-JobAgentReportMarkdownText $item.title),
                    (ConvertTo-JobAgentReportMarkdownText $item.company),
                    (ConvertTo-JobAgentReportMarkdownText $item.location),
                    (ConvertTo-JobAgentReportMarkdownText $item.priority),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.status -Domain 'job_status'),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.official_url -Label 'Offizielle Stellen-URL'),
                    (ConvertTo-JobAgentReportMarkdownLink -Url $item.career_url -Label 'Karriere-URL'),
                    (ConvertTo-JobAgentReportProviderMarkdownLink -Link $item.provider_link),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.work_model -Domain 'work_model'),
                    (ConvertTo-JobAgentReportDisplayMarkdownText $item.employment_type -Domain 'employment_type'),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.published_at)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.first_seen)),
                    (ConvertTo-JobAgentReportMarkdownText (ConvertTo-JobAgentReportDateText $item.last_seen)),
                    (ConvertTo-JobAgentReportMarkdownText $ageText),
                    (ConvertTo-JobAgentReportMarkdownText $item.salary),
                    (ConvertTo-JobAgentReportMarkdownText $item.requirements_text),
                    (ConvertTo-JobAgentReportMarkdownText $item.description),
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
                (ConvertTo-JobAgentReportMarkdownLink -Url $item.official_website_url -Label 'Website'),
                (ConvertTo-JobAgentReportMarkdownLink -Url $item.career_url -Label 'Karriere-URL'),
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
        [void]$Lines.Add('<tr><th>Titel</th><th>Firma</th><th>Standort</th><th>Prioritaet</th><th>Status</th><th>Offizielle Stellen-URL</th><th>Karriere-URL</th><th>Quelle</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Kurzprofil</th><th>Aenderung</th><th>Begruendung</th></tr>')
    }
    else {
        [void]$Lines.Add('<tr><th>Titel</th><th>Firma</th><th>Standort</th><th>Prioritaet</th><th>Status</th><th>Offizielle Stellen-URL</th><th>Karriere-URL</th><th>Quelle</th><th>Arbeitsmodell</th><th>Beschaeftigung</th><th>Veroeffentlicht</th><th>Erkannt</th><th>Letztmals gesehen</th><th>Alter</th><th>Gehalt</th><th>Anforderungen</th><th>Kurzprofil</th><th>Begruendung</th></tr>')
    }
    [void]$Lines.Add('</thead>')
    [void]$Lines.Add('<tbody>')
    foreach ($item in $Items) {
        $change = ((@($item.changed_fields) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', ')
        if ([string]::IsNullOrWhiteSpace($change)) {
            $change = $item.change_reason
        }
        $ageText = if ([string]$item.age_days -eq 'UNKNOWN') { 'Unbekannt' } else { ('{0} Tage ({1})' -f $item.age_days, (ConvertTo-JobAgentReportDisplayLabel -Value $item.age_basis -Domain 'age_basis')) }
        $urlCell = ConvertTo-JobAgentReportHtmlLink -Url $item.official_url -Label 'Offizielle Stellen-URL'
        $careerCell = ConvertTo-JobAgentReportHtmlLink -Url $item.career_url -Label 'Karriere-URL'
        $providerCell = ConvertTo-JobAgentReportProviderHtmlLink -Link $item.provider_link

        if ($IncludeChange) {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.status -Domain 'job_status') +
                '</td><td>' + $urlCell +
                '</td><td>' + $careerCell +
                '</td><td>' + $providerCell +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.work_model -Domain 'work_model') +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.employment_type -Domain 'employment_type') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.description) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $change) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority_explanation) +
                '</td></tr>'
            )
        }
        else {
            [void]$Lines.Add(
                '<tr><td>' + (ConvertTo-JobAgentReportHtmlText $item.title) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.company) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.location) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.priority) +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.status -Domain 'job_status') +
                '</td><td>' + $urlCell +
                '</td><td>' + $careerCell +
                '</td><td>' + $providerCell +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.work_model -Domain 'work_model') +
                '</td><td>' + (ConvertTo-JobAgentReportDisplayHtmlText $item.employment_type -Domain 'employment_type') +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.published_at)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.first_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportDateText $item.last_seen)) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $ageText) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.salary) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.requirements_text) +
                '</td><td>' + (ConvertTo-JobAgentReportHtmlText $item.description) +
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
    [void]$lines.Add("- Firmen gesamt: $($Report.statistics.companies_total)")
    [void]$lines.Add("- Firmen im Lauf: $($Report.statistics.companies_selected)")
    [void]$lines.Add("- Faellige Firmen: $($Report.statistics.companies_due)")
    [void]$lines.Add("- Uebersprungene Firmen: $($Report.statistics.companies_skipped)")
    [void]$lines.Add("- Limit: $($Report.statistics.run_limit)")
    [void]$lines.Add("- Auswahlgrund: $(ConvertTo-JobAgentReportDisplayLabel -Value $Report.statistics.selection_reason -Domain 'reason')")
    [void]$lines.Add("- Adapterversuche: $($Report.statistics.adapter_attempts)")
    [void]$lines.Add("- Snapshots: $($Report.statistics.snapshots)")
    [void]$lines.Add("- Fehler: $($Report.statistics.errors)")
    [void]$lines.Add('')
    [void]$lines.Add('## Erfassungsscope und Vollstaendigkeit')
    [void]$lines.Add("- Scope: $($Report.capture_manifest.collection_scope)")
    [void]$lines.Add("- Suchbegriffe: $(if (@($Report.capture_manifest.search_terms).Count -eq 0) { 'Keine (alle Berufe)' } else { @($Report.capture_manifest.search_terms) -join ', ' })")
    [void]$lines.Add("- Vollstaendigkeitsgrenze: $($Report.capture_manifest.completion_boundary)")
    [void]$lines.Add("- Quellen: $($Report.capture_manifest.complete_sources) vollstaendig, $($Report.capture_manifest.partial_sources) teilweise, $($Report.capture_manifest.failed_sources) fehlgeschlagen, $($Report.capture_manifest.skipped_companies) Firmen uebersprungen")
    foreach ($limitation in @($Report.capture_manifest.limitations)) {
        [void]$lines.Add("- Grenze: $limitation")
    }
    [void]$lines.Add('')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('captured_jobs_total', 'profile_matching_jobs_total', 'captured_jobs_this_run', 'profile_matching_jobs_this_run')) {
        [void]$lines.Add(('| {0} | {1} |' -f (ConvertTo-JobAgentReportDisplayLabel -Value $metric -Domain 'metric'), $Report.statistics.$metric))
    }
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
    foreach ($metric in @('checked_jobs', 'captured_jobs_total', 'profile_matching_jobs_total', 'captured_jobs_this_run', 'profile_matching_jobs_this_run', 'new_jobs', 'active_matching_jobs', 'updated_jobs', 'removed_or_closed_jobs', 'invalid_jobs', 'new_companies', 'uncertain_sources', 'unreachable_career_pages', 'errors')) {
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
    [void]$lines.Add('### Quellenbestand')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('sources_total', 'official_sources', 'career_sources', 'ats_sources', 'discovery_sources', 'verified_sources', 'unverified_sources', 'blocked_sources', 'retry_open_sources', 'sources_attempted_latest_run', 'sources_succeeded_latest_run', 'sources_failed_latest_run', 'never_scanned_sources', 'stale_sources')) {
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

function Add-JobAgentReportSearchInterfaceHtml {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][object]$Report
    )

    $clientData = [pscustomobject]@{
        generated_at = $Report.generated_at
        reference_time = $Report.generated_at
        jobs = @($Report.sections.active_jobs | ForEach-Object {
                [pscustomobject]@{
                    job_id = $_.job_id
                    company = $_.company
                    title = $_.title
                    job_category = $_.job_category
                    location = $_.location
                    target_area = $_.target_area
                    area_facets = @($_.area_facets)
                    work_model = $_.work_model
                    employment_type = $_.employment_type
                    work_time = $_.work_time
                    age_basis = $_.age_basis
                    age_days = $_.age_days
                    last_seen = $_.last_seen
                    official_url = $_.official_url
                    career_url = $_.career_url
                }
            })
        companies = @($Report.sections.companies | ForEach-Object {
                [pscustomobject]@{
                    company_id = $_.company_id
                    company = $_.company
                    locations = @($_.locations)
                    official_website_url = $_.official_website_url
                    career_url = $_.career_url
                    verification_status = $_.verification_status
                    scan_status = $_.scan_status
                }
            })
    }
    [void]$Lines.Add('<section id="jobagent-search" aria-labelledby="jobagent-search-heading">')
    [void]$Lines.Add('<h2 id="jobagent-search-heading">Firmen und Stellen</h2>')
    [void]$Lines.Add('<p>Die Suche arbeitet ausschliesslich lokal im angezeigten Bestand. Filter starten keinen Joblauf und aendern keine gespeicherten Daten.</p>')
    [void]$Lines.Add('<div class="search-tabs" role="tablist" aria-label="Bestandsansicht"><button type="button" id="jobagent-tab-jobs" role="tab" aria-selected="true" aria-controls="jobagent-jobs" data-jobagent-view="jobs">Stellen</button><button type="button" id="jobagent-tab-companies" role="tab" aria-selected="false" aria-controls="jobagent-companies" data-jobagent-view="companies">Firmen</button></div>')
    [void]$Lines.Add('<form id="jobagent-filters" class="filters" novalidate><label>Freitext<input id="jobagent-query" name="q" type="search" autocomplete="off" placeholder="Titel, Firma oder Berufskategorie"></label><label>Gebiet<select id="jobagent-area" name="area" multiple size="5" aria-describedby="jobagent-filter-help"><option value="MUNICH">Muenchen Stadt</option><option value="MUNICH_20KM">Muenchen 20 km</option><option value="FREISING_CITY">Freising Stadt</option><option value="FREISING_COUNTY">Landkreis Freising</option><option value="FREISING_UNSPECIFIED">Freising (Gebiet nicht weiter belegt)</option><option value="REMOTE_WITH_TARGET_REFERENCE">Remote/Hybrid mit Zielgebietsbezug</option><option value="UNKNOWN">Unbekannt</option></select></label><label>Arbeitsmodell<select id="jobagent-work-model" name="workModel" multiple size="4"><option value="REMOTE">Remote</option><option value="HYBRID">Hybrid</option><option value="ONSITE">Vor Ort</option><option value="UNKNOWN">Unbekannt</option></select></label><label>Anstellungsart<select id="jobagent-employment-type" name="employmentType" multiple size="5"><option value="FULL_TIME">Vollzeit</option><option value="PART_TIME">Teilzeit</option><option value="CONTRACT">Befristet/Vertrag</option><option value="PERMANENT">Unbefristet</option><option value="INTERNSHIP">Praktikum</option><option value="UNKNOWN">Unbekannt</option></select></label><label>Arbeitszeit<select id="jobagent-work-time" name="workTime" multiple size="2"><option value="UNKNOWN">Unbekannt</option></select></label><label>Aktualitaet<select id="jobagent-age" name="age"><option value="">Alle</option><option value="7">Letzte 7 Tage</option><option value="30">Letzte 30 Tage</option><option value="older">Aelter als 30 Tage</option><option value="UNKNOWN">Unbekannt</option></select></label><button type="reset" id="jobagent-reset">Filter zuruecksetzen</button></form>')
    [void]$Lines.Add('<p id="jobagent-filter-help" class="unknown">Mehrfachauswahl: Strg/Cmd oder Touch-Auswahl. Werte im selben Feld werden alternativ, verschiedene Filter gemeinsam angewendet.</p>')
    [void]$Lines.Add('<p id="jobagent-result-count" class="result-count" role="status" aria-live="polite"></p>')
    [void]$Lines.Add('<div id="jobagent-jobs" role="tabpanel" aria-labelledby="jobagent-tab-jobs"><div id="jobagent-job-results" class="result-list"></div></div>')
    [void]$Lines.Add('<div id="jobagent-companies" role="tabpanel" aria-labelledby="jobagent-tab-companies" hidden><div id="jobagent-company-results" class="result-list"></div></div>')
    [void]$Lines.Add('<nav id="jobagent-pagination" class="pagination" aria-label="Seitennavigation"></nav>')
    [void]$Lines.Add('<script id="jobagent-search-data" type="application/json">' + (ConvertTo-JobAgentReportClientDataJson -Value $clientData) + '</script>')
    [void]$Lines.Add('<script>')
    [void]$Lines.Add('(function () {')
    [void]$Lines.Add('const data=JSON.parse(document.getElementById("jobagent-search-data").textContent),pageSize=50,form=document.getElementById("jobagent-filters"),count=document.getElementById("jobagent-result-count"),pagination=document.getElementById("jobagent-pagination");')
    [void]$Lines.Add('const normalize=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("de-DE").replace(/[^\p{L}\p{N}]+/gu," ").trim(),decodeQuery=value=>{let current=String(value||"");for(let attempt=0;attempt<3;attempt++){try{const decoded=decodeURIComponent(current.replace(/\+/g,"%20"));if(decoded===current)break;current=decoded}catch{break}}return current},selected=id=>Array.from(document.getElementById(id).selectedOptions,o=>o.value),text=(value,fallback="Unbekannt")=>value&&value!=="UNKNOWN"?String(value):fallback;')
    [void]$Lines.Add('const link=(url,label)=>{const a=document.createElement("a");if(/^https?:\/\//i.test(String(url||""))){a.href=url;a.target="_blank";a.rel="noopener noreferrer";a.textContent=label;return a}const span=document.createElement("span");span.className="unknown";span.textContent="Kein offizieller Link";return span};')
    [void]$Lines.Add('const read=()=>{const p=new URLSearchParams(location.hash.slice(1)),rawPage=p.get("page"),requestedPage=Number(rawPage),rawQuery=p.get("q")||"",query=decodeQuery(rawQuery);return{view:p.get("view")==="companies"?"companies":"jobs",page:Math.max(1,requestedPage||1),_pageNeedsNormalization:rawPage!==null&&(!Number.isInteger(requestedPage)||requestedPage<1),_queryNeedsNormalization:rawQuery!==query,q:query,area:(p.get("area")||"").split(",").filter(Boolean),workModel:(p.get("workModel")||"").split(",").filter(Boolean),employmentType:(p.get("employmentType")||"").split(",").filter(Boolean),workTime:(p.get("workTime")||"").split(",").filter(Boolean),age:p.get("age")||""}};')
    [void]$Lines.Add('const write=(state,replace)=>{const p=new URLSearchParams();Object.entries(state).forEach(([key,value])=>{if(key.startsWith("_"))return;const output=Array.isArray(value)?value.join(","):value;if(output&&!(key==="page"&&Number(output)===1))p.set(key,output)});const target="#"+p.toString();if(replace)history.replaceState(null,"",target);else location.hash=target};')
    [void]$Lines.Add('const setSelect=(id,values)=>Array.from(document.getElementById(id).options).forEach(option=>option.selected=values.includes(option.value));const sync=state=>{document.getElementById("jobagent-query").value=state.q;document.getElementById("jobagent-age").value=state.age;setSelect("jobagent-area",state.area);setSelect("jobagent-work-model",state.workModel);setSelect("jobagent-employment-type",state.employmentType);setSelect("jobagent-work-time",state.workTime)};')
    [void]$Lines.Add('const currentFilters=()=>({q:document.getElementById("jobagent-query").value,area:selected("jobagent-area"),workModel:selected("jobagent-work-model"),employmentType:selected("jobagent-employment-type"),workTime:selected("jobagent-work-time"),age:document.getElementById("jobagent-age").value});')
    [void]$Lines.Add('const includesAny=(values,candidates)=>values.length===0||candidates.some(candidate=>values.includes(candidate)),ageMatches=(job,age)=>{if(!age)return true;const days=Number(job.age_days);if(!Number.isFinite(days))return age==="UNKNOWN";return age==="older"?days>30:days<=Number(age)};')
    [void]$Lines.Add('const jobMatches=(job,state)=>{const tokens=normalize(state.q).split(" ").filter(Boolean),haystack=normalize([job.title,job.company,job.job_category].join(" "));return tokens.every(token=>haystack.includes(token))&&includesAny(state.area,job.area_facets||[job.target_area])&&includesAny(state.workModel,[job.work_model])&&includesAny(state.employmentType,[job.employment_type])&&includesAny(state.workTime,[job.work_time])&&ageMatches(job,state.age)};')
    [void]$Lines.Add('const companyMatches=(company,state)=>{const tokens=normalize(state.q).split(" ").filter(Boolean),haystack=normalize([company.company,...(company.locations||[])].join(" "));return tokens.every(token=>haystack.includes(token))};')
    [void]$Lines.Add('const jobCard=job=>{const article=document.createElement("article"),heading=document.createElement("h3"),meta=document.createElement("p"),detail=document.createElement("p");article.className="result-card";article.dataset.jobId=job.job_id;article.dataset.companyId=job.company_id;heading.textContent=job.title;meta.textContent=text(job.company)+" · "+text(job.location)+" · "+text(job.work_model)+" · "+text(job.employment_type)+" · "+text(job.work_time);detail.textContent="Aktualitaet: "+text(job.age_days,"Unbekannt")+" Tage ("+text(job.age_basis)+")";article.append(heading,meta,detail,link(job.official_url,"Offizielle Stelle"),document.createTextNode(" · "),link(job.career_url,"Karriere"));return article};')
    [void]$Lines.Add('const companyCard=company=>{const article=document.createElement("article"),heading=document.createElement("h3"),meta=document.createElement("p"),detail=document.createElement("p");article.className="result-card";article.dataset.companyId=company.company_id;heading.textContent=company.company;meta.textContent="Orte: "+text((company.locations||[]).join(", "));detail.textContent="Pruefstatus: "+text(company.verification_status)+" · Scan: "+text(company.scan_status);article.append(heading,meta,detail,link(company.official_website_url,"Website"),document.createTextNode(" · "),link(company.career_url,"Karriere"));return article};')
    [void]$Lines.Add('const render=()=>{const state=read();sync(state);const isJobs=state.view==="jobs",items=(isJobs?data.jobs.filter(job=>jobMatches(job,state)):data.companies.filter(company=>companyMatches(company,state))).sort((a,b)=>isJobs?[a.title,a.company,a.location,a.last_seen,a.job_id].join("\\u0000").localeCompare([b.title,b.company,b.location,b.last_seen,b.job_id].join("\\u0000"),"de"):[a.company,a.company_id].join("\\u0000").localeCompare([b.company,b.company_id].join("\\u0000"),"de")),pages=Math.max(1,Math.ceil(items.length/pageSize)),page=Math.min(state.page,pages),slice=items.slice((page-1)*pageSize,page*pageSize),target=document.getElementById(isJobs?"jobagent-job-results":"jobagent-company-results");document.getElementById("jobagent-jobs").hidden=!isJobs;document.getElementById("jobagent-companies").hidden=isJobs;document.getElementById("jobagent-tab-jobs").setAttribute("aria-selected",String(isJobs));document.getElementById("jobagent-tab-companies").setAttribute("aria-selected",String(!isJobs));target.replaceChildren(...slice.map(isJobs?jobCard:companyCard));if(!slice.length)target.textContent="Keine Treffer im angezeigten Bestand.";count.textContent=(isJobs?"Stellen":"Firmen")+": "+items.length+" Treffer, Seite "+page+" von "+pages+" (sichtbar "+slice.length+").";pagination.replaceChildren();if(pages>1){for(let number=1;number<=pages;number++){const button=document.createElement("button");button.type="button";button.textContent=String(number);button.disabled=number===page;button.addEventListener("click",()=>{write({...state,page:number},false);setTimeout(()=>{const current=Array.from(pagination.querySelectorAll("button")).find(candidate=>candidate.disabled);if(current)current.focus()},0)});pagination.append(button)}}if(page!==state.page||state._pageNeedsNormalization||state._queryNeedsNormalization)write({...state,page},true)};')
    [void]$Lines.Add('form.addEventListener("input",()=>write({...read(),...currentFilters(),page:1},false));form.addEventListener("change",()=>write({...read(),...currentFilters(),page:1},false));form.addEventListener("reset",()=>setTimeout(()=>write({view:read().view,page:1,q:"",area:[],workModel:[],employmentType:[],workTime:[],age:""},false),0));document.querySelectorAll("[data-jobagent-view]").forEach(button=>{button.addEventListener("click",()=>write({...read(),view:button.dataset.jobagentView,page:1},false));button.addEventListener("keydown",event=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(event.key))return;event.preventDefault();const tabs=Array.from(document.querySelectorAll("[data-jobagent-view]")),index=tabs.indexOf(button),target=event.key==="Home"?tabs[0]:event.key==="End"?tabs[tabs.length-1]:tabs[(index+(event.key==="ArrowRight"?1:tabs.length-1))%tabs.length];target.focus();target.click()})});window.addEventListener("hashchange",render);render();')
    [void]$Lines.Add('}());')
    [void]$Lines.Add('</script></section>')
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
    [void]$lines.Add('.job-table { min-width: 1500px; }')
    [void]$lines.Add('th, td { text-align: left; vertical-align: top; padding: 10px 12px; border-bottom: 1px solid var(--line); overflow-wrap: anywhere; }')
    [void]$lines.Add('th { background: #f2e7d4; font-size: 0.92rem; }')
    [void]$lines.Add('tbody tr:nth-child(even) { background: rgba(122, 75, 32, 0.04); }')
    [void]$lines.Add('a { color: var(--accent); }')
    [void]$lines.Add('.unknown { color: var(--muted); font-style: italic; }')
    [void]$lines.Add('.filters { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; align-items: end; }')
    [void]$lines.Add('.filters label { display: grid; gap: 5px; font-weight: 600; }')
    [void]$lines.Add('input, select, button { font: inherit; min-width: 44px; min-height: 44px; border: 1px solid var(--line); border-radius: 8px; padding: 8px; background: var(--surface); color: var(--text); }')
    [void]$lines.Add('select[multiple] { min-height: 116px; } button { cursor: pointer; font-weight: 600; } button:focus-visible, input:focus-visible, select:focus-visible, a:focus-visible { outline: 3px solid #1d70b8; outline-offset: 2px; }')
    [void]$lines.Add('.search-tabs, .pagination { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0; } .search-tabs button[aria-selected="true"] { background: var(--accent); color: #fff; } .result-count { font-weight: 600; }')
    [void]$lines.Add('.result-list { display: grid; gap: 10px; } .result-card { border: 1px solid var(--line); border-radius: 10px; padding: 12px; background: var(--surface-alt); overflow-wrap: anywhere; } .result-card h3, .result-card p { margin: 0 0 8px; }')
    [void]$lines.Add('@media (max-width: 800px) { main { padding: 16px 12px 28px; } section { padding: 12px; } table { min-width: 640px; } .job-table { min-width: 1360px; } th, td { padding: 9px 10px; } }')
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
            @{ Label = 'Firmen gesamt'; Value = $Report.statistics.companies_total },
            @{ Label = 'Firmen im Lauf'; Value = $Report.statistics.companies_selected },
            @{ Label = 'Faellige Firmen'; Value = $Report.statistics.companies_due },
            @{ Label = 'Uebersprungene Firmen'; Value = $Report.statistics.companies_skipped },
            @{ Label = 'Limit'; Value = $Report.statistics.run_limit },
            @{ Label = 'Auswahlgrund'; Value = (ConvertTo-JobAgentReportDisplayLabel -Value $Report.statistics.selection_reason -Domain 'reason') },
            @{ Label = 'Adapterversuche'; Value = $Report.statistics.adapter_attempts },
            @{ Label = 'Snapshots'; Value = $Report.statistics.snapshots },
            @{ Label = 'Fehler'; Value = $Report.statistics.errors }
        )) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportHtmlText $item.Label) + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $item.Value) + '</span></div>')
    }
    [void]$lines.Add('</div>')
    [void]$lines.Add('</section>')

    Add-JobAgentReportSearchInterfaceHtml -Lines $lines -Report $Report

    [void]$lines.Add('<section><h2>Erfassungsscope und Vollstaendigkeit</h2>')
    [void]$lines.Add('<div class="summary">')
    foreach ($item in @(
            @{ Label = 'Scope'; Value = $Report.capture_manifest.collection_scope },
            @{ Label = 'Suchbegriffe'; Value = if (@($Report.capture_manifest.search_terms).Count -eq 0) { 'Keine (alle Berufe)' } else { @($Report.capture_manifest.search_terms) -join ', ' } },
            @{ Label = 'Vollstaendigkeitsgrenze'; Value = $Report.capture_manifest.completion_boundary },
            @{ Label = 'Erfasste Stellen gesamt'; Value = $Report.statistics.captured_jobs_total },
            @{ Label = 'Profiltreffer gesamt'; Value = $Report.statistics.profile_matching_jobs_total },
            @{ Label = 'Erfasste Stellen im Lauf'; Value = $Report.statistics.captured_jobs_this_run },
            @{ Label = 'Profiltreffer im Lauf'; Value = $Report.statistics.profile_matching_jobs_this_run }
        )) {
        [void]$lines.Add('<div class="card"><span class="label">' + (ConvertTo-JobAgentReportHtmlText $item.Label) + '</span><span class="value">' + (ConvertTo-JobAgentReportHtmlText $item.Value) + '</span></div>')
    }
    [void]$lines.Add('</div>')
    foreach ($limitation in @($Report.capture_manifest.limitations)) {
        [void]$lines.Add('<p class="unknown">Grenze: ' + (ConvertTo-JobAgentReportHtmlText $limitation) + '</p>')
    }
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
    foreach ($metric in @('checked_jobs', 'captured_jobs_total', 'profile_matching_jobs_total', 'captured_jobs_this_run', 'profile_matching_jobs_this_run', 'new_jobs', 'active_matching_jobs', 'updated_jobs', 'removed_or_closed_jobs', 'invalid_jobs', 'new_companies', 'uncertain_sources', 'unreachable_career_pages', 'errors')) {
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

    [void]$lines.Add('<h3>Quellenbestand</h3><div class="summary">')
    foreach ($metric in @('sources_total', 'official_sources', 'career_sources', 'ats_sources', 'discovery_sources', 'verified_sources', 'unverified_sources', 'blocked_sources', 'retry_open_sources', 'sources_attempted_latest_run', 'sources_succeeded_latest_run', 'sources_failed_latest_run', 'never_scanned_sources', 'stale_sources')) {
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
