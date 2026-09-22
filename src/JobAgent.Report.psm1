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

function Get-JobAgentReportBerlinTimeZone {
    try {
        return [TimeZoneInfo]::FindSystemTimeZoneById('W. Europe Standard Time')
    }
    catch {
        return [TimeZoneInfo]::FindSystemTimeZoneById('Europe/Berlin')
    }
}

function ConvertTo-JobAgentReportTimestampInfo {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $text = ConvertTo-JobAgentReportText -Value $Value
    if ($text -eq 'UNKNOWN') {
        return [pscustomobject]@{ value = 'UNKNOWN'; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Historie nicht vorhanden' }
    }
    if ($text -notmatch '(?i)(Z|[+-]\d{2}:\d{2})$') {
        return [pscustomobject]@{ value = $text; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Zeitpunkt ohne Offset ist nicht eindeutig' }
    }
    try {
        $timestamp = [datetimeoffset]::Parse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AllowWhiteSpaces).ToUniversalTime()
        $reference = [datetimeoffset]::new($ReferenceTime.ToUniversalTime())
        if ($timestamp -gt $reference) {
            return [pscustomobject]@{ value = $timestamp.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture); display = 'Unbekannt'; precision = 'SECOND'; age_days = 'UNKNOWN'; data_notice = 'Zeitpunkt liegt nach der Reportreferenz' }
        }
        $berlin = [TimeZoneInfo]::ConvertTime($timestamp, (Get-JobAgentReportBerlinTimeZone))
        return [pscustomobject]@{
            value = $timestamp.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            display = $berlin.ToString('dd.MM.yyyy HH:mm:ss', [Globalization.CultureInfo]::GetCultureInfo('de-DE')) + ' UTC' + $berlin.ToString('zzz', [Globalization.CultureInfo]::InvariantCulture)
            precision = 'SECOND'
            age_days = [string][int][math]::Floor(($reference - $timestamp).TotalSeconds / 86400)
            data_notice = 'NONE'
        }
    }
    catch {
        return [pscustomobject]@{ value = $text; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Ungueltiger Zeitpunkt' }
    }
}

function ConvertTo-JobAgentReportDateInfo {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $text = ConvertTo-JobAgentReportText -Value $Value
    if ($text -notmatch '^\d{4}-\d{2}-\d{2}$') {
        return [pscustomobject]@{ value = if ($text -eq 'UNKNOWN') { 'UNKNOWN' } else { $text }; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = if ($text -eq 'UNKNOWN') { 'Historie nicht vorhanden' } else { 'Ungueltiges Quelldatum' } }
    }
    try {
        $date = [datetime]::ParseExact($text, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None).Date
        $referenceLocal = [TimeZoneInfo]::ConvertTimeFromUtc($ReferenceTime.ToUniversalTime(), (Get-JobAgentReportBerlinTimeZone)).Date
        if ($date -gt $referenceLocal) {
            return [pscustomobject]@{ value = $text; display = 'Unbekannt'; precision = 'DAY'; age_days = 'UNKNOWN'; data_notice = 'Quelldatum liegt nach der Reportreferenz' }
        }
        return [pscustomobject]@{ value = $text; display = $date.ToString('dd.MM.yyyy', [Globalization.CultureInfo]::GetCultureInfo('de-DE')) + ' (Uhrzeit unbekannt)'; precision = 'DAY'; age_days = [string][int]($referenceLocal - $date).TotalDays; data_notice = 'NONE' }
    }
    catch {
        return [pscustomobject]@{ value = $text; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Ungueltiges Quelldatum' }
    }
}

function Get-JobAgentReportAgeInfo {
    param(
        [Parameter()][AllowNull()][object]$PublishedAt,
        [Parameter()][AllowNull()][object]$PublishedOn,
        [Parameter()][AllowNull()][object]$FirstSeen,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $publishedText = ConvertTo-JobAgentReportText -Value $PublishedAt
    $publishedOnText = ConvertTo-JobAgentReportText -Value $PublishedOn
    $firstSeenText = ConvertTo-JobAgentReportText -Value $FirstSeen
    $basis = if ($publishedText -ne 'UNKNOWN') { 'published_at' } elseif ($publishedOnText -ne 'UNKNOWN') { 'published_on' } elseif ($firstSeenText -ne 'UNKNOWN') { 'first_seen' } else { 'UNKNOWN' }
    $info = switch ($basis) {
        'published_at' { ConvertTo-JobAgentReportTimestampInfo -Value $publishedText -ReferenceTime $ReferenceTime; break }
        'published_on' { ConvertTo-JobAgentReportDateInfo -Value $publishedOnText -ReferenceTime $ReferenceTime; break }
        'first_seen' { ConvertTo-JobAgentReportTimestampInfo -Value $firstSeenText -ReferenceTime $ReferenceTime; break }
        default { [pscustomobject]@{ value = 'UNKNOWN'; display = 'Unbekannt'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Historie nicht vorhanden' } }
    }

    # Die Zeitangabe selbst bleibt in der Projektion vollstaendig. Fuer die
    # Altersanzeige ist ein Zeitstempel innerhalb der ersten 24 Stunden jedoch
    # absichtlich nicht als "0 Tage" zu lesen.
    $ageDisplay = [string]$info.display
    if (($info.precision -eq 'SECOND') -and ($info.age_days -eq '0') -and ($info.data_notice -eq 'NONE')) {
        $ageDisplay = 'Unter 1 Tag'
    }

    [pscustomobject]@{
        age_basis = $basis
        age_days = [string]$info.age_days
        age_display = $ageDisplay
        age_precision = [string]$info.precision
        age_data_notice = [string]$info.data_notice
    }
}

function Get-JobAgentReportAvailabilityInfo {
    param(
        [Parameter(Mandatory)][object]$Job,
        [Parameter()][AllowEmptyCollection()][object[]]$ScanAttempts = @(),
        [Parameter(Mandatory)][datetime]$ReferenceTime,
        [Parameter()][ValidateRange(1, 365)][int]$FreshnessWindowDays = 7
    )

    $sourceId = [string](Get-JobAgentReportProperty -Object $Job -Name 'source_id' -Default '')
    $confirmedAt = $null
    foreach ($attempt in @($ScanAttempts)) {
        if (([string](Get-JobAgentReportProperty -Object $attempt -Name 'source_id' -Default '')) -ne $sourceId) {
            continue
        }
        if (([string](Get-JobAgentReportProperty -Object $attempt -Name 'status' -Default '')) -ne 'SUCCESS' -or
            ([string](Get-JobAgentReportProperty -Object $attempt -Name 'error_class' -Default '')) -ne 'NONE') {
            continue
        }
        $finishedAt = Get-JobAgentReportProperty -Object $attempt -Name 'finished_at'
        try {
            $parsed = [datetime]::Parse([string]$finishedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
            if ($parsed -gt $ReferenceTime.ToUniversalTime()) {
                continue
            }
            if (($null -eq $confirmedAt) -or ($parsed -gt $confirmedAt)) {
                $confirmedAt = $parsed
            }
        }
        catch {
            continue
        }
    }

    if ($null -eq $confirmedAt) {
        return [pscustomobject]@{
            availability = 'FRESHNESS_UNKNOWN'
            source_confirmed_at = 'UNKNOWN'
            freshness_age_seconds = 'UNKNOWN'
            reason = 'Keine erfolgreiche Quellenbestaetigung mit gueltigem Zeitpunkt vor der Reportreferenz.'
        }
    }

    $ageSeconds = [math]::Floor(($ReferenceTime.ToUniversalTime() - $confirmedAt).TotalSeconds)
    $windowSeconds = $FreshnessWindowDays * 24 * 60 * 60
    [pscustomobject]@{
        availability = if ($ageSeconds -le $windowSeconds) { 'CURRENT' } else { 'CHECK_PENDING' }
        source_confirmed_at = $confirmedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        freshness_age_seconds = [string][int64]$ageSeconds
        reason = if ($ageSeconds -le $windowSeconds) { 'Erfolgreiche Quellenbestaetigung innerhalb des konfigurierten 7-Tage-Fensters.' } else { 'Letzte erfolgreiche Quellenbestaetigung liegt ausserhalb des konfigurierten 7-Tage-Fensters.' }
    }
}

function Get-JobAgentReportSourceTimeInfo {
    param(
        [Parameter(Mandatory)][object]$Job,
        [Parameter()][AllowEmptyCollection()][object[]]$ScanAttempts = @(),
        [Parameter()][AllowNull()][object]$Company = $null,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $sourceId = [string](Get-JobAgentReportProperty -Object $Job -Name 'source_id' -Default '')
    $latestAttempt = $null
    $latestSuccess = $null
    $latestComplete = $null
    foreach ($attempt in @($ScanAttempts)) {
        if ([string](Get-JobAgentReportProperty -Object $attempt -Name 'source_id' -Default '') -ne $sourceId) {
            continue
        }
        $finished = ConvertTo-JobAgentReportTimestampInfo -Value (Get-JobAgentReportProperty -Object $attempt -Name 'finished_at') -ReferenceTime $ReferenceTime
        $started = ConvertTo-JobAgentReportTimestampInfo -Value (Get-JobAgentReportProperty -Object $attempt -Name 'started_at') -ReferenceTime $ReferenceTime
        $sortValue = if ($finished.precision -eq 'SECOND') { $finished.value } elseif ($started.precision -eq 'SECOND') { $started.value } else { '' }
        if ([string]::IsNullOrWhiteSpace($sortValue)) {
            continue
        }
        $entry = [pscustomobject]@{
            scan_attempt_id = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'scan_attempt_id')
            scan_run_id = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'scan_run_id')
            status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'status')
            error_class = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'error_class')
            finished = $finished
            started = $started
            sort_value = $sortValue
            scan_complete = if ($attempt.PSObject.Properties.Name -contains 'scan_complete') { [bool]$attempt.scan_complete } else { $null }
        }
        if (($null -eq $latestAttempt) -or ($entry.sort_value -gt $latestAttempt.sort_value)) { $latestAttempt = $entry }
        if (($entry.status -eq 'SUCCESS') -and ($entry.error_class -eq 'NONE')) {
            if (($null -eq $latestSuccess) -or ($entry.sort_value -gt $latestSuccess.sort_value)) { $latestSuccess = $entry }
            if (($entry.scan_complete -eq $true) -and (($null -eq $latestComplete) -or ($entry.sort_value -gt $latestComplete.sort_value))) { $latestComplete = $entry }
        }
    }
    $nextScan = ConvertTo-JobAgentReportTimestampInfo -Value (Get-JobAgentReportProperty -Object $Company -Name 'next_scan_at') -ReferenceTime ([datetime]::MaxValue)
    [pscustomobject]@{
        source_id = $sourceId
        latest_attempt = $latestAttempt
        latest_successful_attempt = $latestSuccess
        latest_complete_list_attempt = $latestComplete
        next_company_scan = if ($nextScan.precision -eq 'SECOND') { $nextScan } else { [pscustomobject]@{ value = 'UNKNOWN'; display = 'Nicht geplant'; precision = 'UNKNOWN'; age_days = 'UNKNOWN'; data_notice = 'Firmenplanung nicht vorhanden' } }
        history_status = if ($null -eq $latestAttempt) { 'HISTORY_UNAVAILABLE' } else { 'AVAILABLE' }
    }
}

function New-JobAgentReportJobEntry {
    param(
        [Parameter(Mandatory)][object]$Job,
        [Parameter(Mandatory)][hashtable]$CompaniesById,
        [Parameter()][hashtable]$SourcesByCompanyId = @{},
        [Parameter()][AllowNull()][object]$ChangeEvent = $null,
        [Parameter()][AllowEmptyCollection()][object[]]$ScanAttempts = @(),
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $publishedAt = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'published_at' -Default 'UNKNOWN')
    $publishedOn = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'published_on' -Default 'UNKNOWN')
    $firstSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'first_seen' -Default 'UNKNOWN')
    $lastSeen = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'last_seen' -Default 'UNKNOWN')
    $requirements = @((Get-JobAgentReportProperty -Object $Job -Name 'requirements' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    $description = ConvertTo-JobAgentReportDescriptionText -Value (Get-JobAgentReportProperty -Object $Job -Name 'description' -Default (Get-JobAgentReportProperty -Object $Job -Name 'summary' -Default 'UNKNOWN'))
    $companyId = [string]$Job.company_id
    $company = if ($CompaniesById.ContainsKey($companyId)) { $CompaniesById[$companyId] } else { [pscustomobject]@{ company_id = $companyId; canonical_name = $companyId; verification_status = 'UNVERIFIED' } }
    $ageInfo = Get-JobAgentReportAgeInfo -PublishedAt $publishedAt -PublishedOn $publishedOn -FirstSeen $firstSeen -ReferenceTime $ReferenceTime
    $availabilityInfo = Get-JobAgentReportAvailabilityInfo -Job $Job -ScanAttempts $ScanAttempts -ReferenceTime $ReferenceTime
    $sourceTimeInfo = Get-JobAgentReportSourceTimeInfo -Job $Job -ScanAttempts $ScanAttempts -Company $company -ReferenceTime $ReferenceTime
    $publishedAtInfo = ConvertTo-JobAgentReportTimestampInfo -Value $publishedAt -ReferenceTime $ReferenceTime
    $publishedOnInfo = ConvertTo-JobAgentReportDateInfo -Value $publishedOn -ReferenceTime $ReferenceTime
    $firstSeenInfo = ConvertTo-JobAgentReportTimestampInfo -Value $firstSeen -ReferenceTime $ReferenceTime
    $lastSeenInfo = ConvertTo-JobAgentReportTimestampInfo -Value $lastSeen -ReferenceTime $ReferenceTime
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
        published_on = $publishedOn
        first_seen = $firstSeen
        last_seen = $lastSeen
        salary = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'salary' -Default 'UNKNOWN')
        requirements = @($requirements)
        requirements_text = ConvertTo-JobAgentReportListText -Values $requirements -Fallback 'UNKNOWN' -MaxItems 3
        description = $description
        description_source = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $Job -Name 'description_source' -Default 'NONE')
        age_basis = [string]$ageInfo.age_basis
        age_days = [string]$ageInfo.age_days
        age_display = [string]$ageInfo.age_display
        age_precision = [string]$ageInfo.age_precision
        age_data_notice = [string]$ageInfo.age_data_notice
        time_projection = [pscustomobject]@{
            reference_time = $ReferenceTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            timezone = 'Europe/Berlin'
            published_at = $publishedAtInfo
            published_on = $publishedOnInfo
            first_seen = $firstSeenInfo
            last_seen = $lastSeenInfo
            source = $sourceTimeInfo
        }
        availability = [string]$availabilityInfo.availability
        source_confirmed_at = [string]$availabilityInfo.source_confirmed_at
        freshness_age_seconds = [string]$availabilityInfo.freshness_age_seconds
        availability_reason = [string]$availabilityInfo.reason
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

function ConvertTo-JobAgentReportChangeText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return 'UNKNOWN'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @($Value | ForEach-Object { ConvertTo-JobAgentReportChangeText -Value $_ } | Sort-Object -Unique)
        if ($items.Count -eq 0) {
            return 'UNKNOWN'
        }
        return ($items -join '; ')
    }
    $text = [System.Net.WebUtility]::HtmlDecode([string]$Value)
    $text = [regex]::Replace($text, '<[^>]*>', ' ')
    $text = $text.Normalize([Text.NormalizationForm]::FormKC)
    $text = [regex]::Replace($text.Replace("`r`n", "`n").Replace("`r", "`n"), '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return 'UNKNOWN'
    }
    return $text
}

function Get-JobAgentReportSnapshotFieldText {
    param(
        [Parameter()][AllowNull()][object]$Snapshot,
        [Parameter(Mandatory)][string]$Field
    )

    if ($null -eq $Snapshot) {
        return 'Vorheriger Inhalt nicht archiviert'
    }
    switch ($Field) {
        'location' {
            return ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object (Get-JobAgentReportProperty -Object $Snapshot -Name 'location') -Name 'label' -Default 'UNKNOWN')
        }
        'description' {
            return ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $Snapshot -Name 'description' -Default (Get-JobAgentReportProperty -Object $Snapshot -Name 'summary' -Default 'UNKNOWN'))
        }
        default {
            return ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $Snapshot -Name $Field -Default 'UNKNOWN')
        }
    }
}

function Get-JobAgentReportChangeHistory {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$JobId,
        [Parameter()][ValidateRange(1, 10000)][int]$MaximumEntries = 10000
    )

    $whitelist = @('title', 'location', 'work_model', 'employment_type', 'work_time', 'description', 'requirements', 'salary', 'official_url', 'status')
    $snapshots = @($Document.job_snapshots | Where-Object { [string]$_.job_id -eq $JobId } | Sort-Object @{ Expression = { [string]$_.captured_at } }, @{ Expression = { [string]$_.snapshot_id } })
    $snapshotsByRun = @{}
    foreach ($snapshot in $snapshots) {
        $snapshotsByRun[[string]$snapshot.scan_run_id] = $snapshot
    }
    $entries = [System.Collections.Generic.List[object]]::new()
    $events = @($Document.change_events | Where-Object {
            ([string]$_.job_id -eq $JobId) -and (@('JOB_CREATED', 'JOB_UPDATED', 'JOB_CLOSED', 'JOB_REMOVED') -contains [string]$_.event_type)
        } | Sort-Object @{ Expression = { [string]$_.created_at } }, @{ Expression = { [string]$_.change_event_id } })
    foreach ($event in $events) {
        $current = $snapshotsByRun[[string]$event.scan_run_id]
        $previousCandidates = @($snapshots | Where-Object {
                ([string]$_.captured_at -lt [string](Get-JobAgentReportProperty -Object $current -Name 'captured_at' -Default '')) -or
                (([string]$_.captured_at -eq [string](Get-JobAgentReportProperty -Object $current -Name 'captured_at' -Default '')) -and ([string]$_.snapshot_id -lt [string](Get-JobAgentReportProperty -Object $current -Name 'snapshot_id' -Default '')))
            } | Select-Object -Last 1)
        $previous = if ($previousCandidates.Count -eq 0) { $null } else { $previousCandidates[0] }
        $fields = @((Get-JobAgentReportProperty -Object $event -Name 'changed_fields' -Default @()) | Where-Object { $whitelist -contains [string]$_ } | ForEach-Object { [string]$_ } | Select-Object -Unique)
        if (([string]$event.event_type -eq 'JOB_CREATED') -and $fields.Count -eq 0) {
            $fields = @('status')
        }
        if (([string]$event.event_type -in @('JOB_CLOSED', 'JOB_REMOVED')) -and ($fields -notcontains 'status')) {
            $fields = @($fields + 'status')
        }
        $fieldChanges = [System.Collections.Generic.List[object]]::new()
        foreach ($field in $fields) {
            $before = if ($field -eq 'status') { ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $event -Name 'old_status' -Default 'UNKNOWN') } else { Get-JobAgentReportSnapshotFieldText -Snapshot $previous -Field $field }
            $after = if ($field -eq 'status') { ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $event -Name 'new_status' -Default 'UNKNOWN') } else { Get-JobAgentReportSnapshotFieldText -Snapshot $current -Field $field }
            $fieldChanges.Add([pscustomobject]@{
                    field = $field
                    before = $before
                    after = $after
                    previous_content_archived = ($null -ne $previous)
                })
        }
        $eventType = [string]$event.event_type
        $entries.Add([pscustomobject]@{
                change_event_id = [string]$event.change_event_id
                event_type = $eventType
                observed_at = [string]$event.created_at
                scan_run_id = [string]$event.scan_run_id
                source_id = if ($null -eq $current) { 'UNKNOWN' } else { ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $current -Name 'source_id' -Default 'UNKNOWN') }
                label = switch ($eventType) { 'JOB_CREATED' { 'Erstmals erfasst' } 'JOB_UPDATED' { 'Inhaltsaenderung erkannt' } 'JOB_CLOSED' { 'Als geschlossen erfasst' } 'JOB_REMOVED' { 'Nicht mehr aufgefunden' } }
                changed_fields = @($fields)
                fields = @($fieldChanges.ToArray())
                reason = ConvertTo-JobAgentReportChangeText -Value (Get-JobAgentReportProperty -Object $event -Name 'reason' -Default 'UNKNOWN')
            })
    }
    return @($entries | Sort-Object @{ Expression = { [string]$_.observed_at }; Descending = $true }, @{ Expression = { [string]$_.change_event_id }; Descending = $false } | Select-Object -First $MaximumEntries)
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
        [Parameter()][AllowEmptyCollection()][object[]]$AllActiveEntries = @(),
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
        open_jobs = @($AllActiveEntries).Count
        current_open_jobs = @($AllActiveEntries | Where-Object { [string]$_.availability -eq 'CURRENT' }).Count
        check_pending_open_jobs = @($AllActiveEntries | Where-Object { [string]$_.availability -eq 'CHECK_PENDING' }).Count
        freshness_unknown_open_jobs = @($AllActiveEntries | Where-Object { [string]$_.availability -eq 'FRESHNESS_UNKNOWN' }).Count
        excluded_jobs = @($Document.jobs | Where-Object { @('CLOSED', 'REMOVED', 'INVALID') -contains [string]$_.status }).Count
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

function New-JobAgentCalendarProjection {
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][datetime]$ReferenceTime
    )

    $companiesById = @{}
    foreach ($company in @($Document.companies)) {
        $companiesById[[string]$company.company_id] = $company
    }
    $createdJobsByRun = @{}
    foreach ($change in @($Document.change_events | Where-Object { [string]$_.event_type -eq 'JOB_CREATED' })) {
        $runId = [string](Get-JobAgentReportProperty -Object $change -Name 'scan_run_id' -Default '')
        $jobId = [string](Get-JobAgentReportProperty -Object $change -Name 'job_id' -Default '')
        if ([string]::IsNullOrWhiteSpace($runId) -or [string]::IsNullOrWhiteSpace($jobId)) { continue }
        if (-not $createdJobsByRun.ContainsKey($runId)) {
            $createdJobsByRun[$runId] = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        }
        [void]$createdJobsByRun[$runId].Add($jobId)
    }

    $attempts = [Collections.Generic.List[object]]::new()
    foreach ($attempt in @($Document.scan_attempts)) {
        $companyId = [string](Get-JobAgentReportProperty -Object $attempt -Name 'company_id' -Default '')
        $company = if ($companiesById.ContainsKey($companyId)) { $companiesById[$companyId] } else { $null }
        $runId = [string](Get-JobAgentReportProperty -Object $attempt -Name 'scan_run_id' -Default '')
        $startedAt = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'started_at' -Default '') -Fallback ''
        $finishedAt = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'finished_at' -Default '') -Fallback ''
        if ([string]::IsNullOrWhiteSpace($startedAt)) { continue }
        $attempts.Add([pscustomobject]@{
                event_id = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'scan_attempt_id' -Default '') -Fallback ''
                scan_run_id = $runId
                company_id = $companyId
                company = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $company -Name 'canonical_name' -Default $companyId)
                source_id = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'source_id' -Default '') -Fallback ''
                started_at = $startedAt
                finished_at = if ([string]::IsNullOrWhiteSpace($finishedAt)) { $null } else { $finishedAt }
                status = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'status' -Default 'RUNNING')
                error_class = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $attempt -Name 'error_class' -Default 'NONE')
                scan_complete = [bool](Get-JobAgentReportProperty -Object $attempt -Name 'scan_complete' -Default $false)
                new_job_ids = if ($createdJobsByRun.ContainsKey($runId)) { @($createdJobsByRun[$runId] | Sort-Object) } else { @() }
            })
    }

    $plans = [Collections.Generic.List[object]]::new()
    foreach ($company in @($Document.companies)) {
        $nextScan = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $company -Name 'next_scan_at' -Default '') -Fallback ''
        if ([string]::IsNullOrWhiteSpace($nextScan)) { continue }
        $plans.Add([pscustomobject]@{
                event_id = 'plan:' + [string]$company.company_id
                company_id = [string]$company.company_id
                company = ConvertTo-JobAgentReportText -Value (Get-JobAgentReportProperty -Object $company -Name 'canonical_name')
                next_scan_at = $nextScan
            })
    }
    $timestamps = @($attempts | ForEach-Object { if ($null -ne $_.finished_at) { $_.finished_at } else { $_.started_at } } | Sort-Object)
    [pscustomobject]@{
        timezone = 'Europe/Berlin'
        reference_time = $ReferenceTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        history_start = if ($timestamps.Count -gt 0) { [string]$timestamps[0] } else { $null }
        attempts = @($attempts.ToArray() | Sort-Object started_at, event_id)
        planned_scans = @($plans.ToArray() | Sort-Object next_scan_at, company_id)
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
                    $createdEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ScanAttempts $Document.scan_attempts -ReferenceTime $finished))
                }
            }
            'JOB_UPDATED' {
                if (Test-JobAgentReportMatch -Job $job) {
                    $changedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ScanAttempts $Document.scan_attempts -ReferenceTime $finished))
                }
            }
            { @('JOB_REMOVED', 'JOB_CLOSED') -contains $_ } {
                if (Test-JobAgentReportMatch -Job $job) {
                    $removedEntries.Add((New-JobAgentReportJobEntry -Job $job -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ChangeEvent $event -ScanAttempts $Document.scan_attempts -ReferenceTime $finished))
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
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ScanAttempts $Document.scan_attempts -ReferenceTime $finished } |
        Sort-Object priority, company, title)
    $allActiveEntries = @($Document.jobs |
        Where-Object { (@('NEW', 'ACTIVE', 'UPDATED') -contains [string]$_.status) -and (Test-JobAgentReportCapturedJob -Job $_) } |
        ForEach-Object { New-JobAgentReportJobEntry -Job $_ -CompaniesById $companiesById -SourcesByCompanyId $sourcesByCompanyId -ScanAttempts $Document.scan_attempts -ReferenceTime $finished } |
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

    $historyByJobId = @{}
    $historyJobIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($event in @($Document.change_events)) {
        if (@('JOB_CREATED', 'JOB_UPDATED', 'JOB_CLOSED', 'JOB_REMOVED') -contains [string]$event.event_type) {
            [void]$historyJobIds.Add([string]$event.job_id)
        }
    }
    foreach ($entry in @($allActiveEntries + $createdEntries.ToArray() + $activeEntries + $changedEntries.ToArray() + $removedEntries.ToArray())) {
        $jobId = [string]$entry.job_id
        if (-not $historyByJobId.ContainsKey($jobId)) {
            $historyByJobId[$jobId] = if ($historyJobIds.Contains($jobId)) { @(Get-JobAgentReportChangeHistory -Document $Document -JobId $jobId) } else { @() }
        }
        $entry | Add-Member -NotePropertyName change_history -NotePropertyValue @($historyByJobId[$jobId]) -Force
    }

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
        statistics = New-JobAgentReportStatistics -Document $Document -ScanRunId $ScanRunId -ActiveEntries $activeEntries -AllActiveEntries $allActiveEntries -NewCompanies $newCompanies
        capture_manifest = New-JobAgentReportCaptureManifest -ScanRun $scanRun -Attempts $attempts
        calendar = New-JobAgentCalendarProjection -Document $Document -ReferenceTime $finished
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
    [void]$lines.Add('## Aktualitaet offener Stellen')
    [void]$lines.Add("- Offene Stellen: $($Report.statistics.open_jobs)")
    [void]$lines.Add("- Aktuell bestaetigt (<= 7 Tage): $($Report.statistics.current_open_jobs)")
    [void]$lines.Add("- Pruefung ausstehend (> 7 Tage): $($Report.statistics.check_pending_open_jobs)")
    [void]$lines.Add("- Aktualitaet unbekannt: $($Report.statistics.freshness_unknown_open_jobs)")
    [void]$lines.Add("- Ausgeschlossen (geschlossen, entfernt, ungueltig): $($Report.statistics.excluded_jobs)")
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

function ConvertTo-JobAgentReportJobBoardText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    $normalized = ConvertTo-JobAgentReportText -Value $Value
    if ($normalized -eq 'UNKNOWN') {
        return 'Keine Angabe'
    }
    if ($Domain -eq 'generic') {
        return $normalized
    }
    $display = ConvertTo-JobAgentReportDisplayLabel -Value $normalized -Domain $Domain
    if ($display -match '^Unbekannt') {
        return 'Keine Angabe'
    }
    return $display
}

function Add-JobAgentReportStaticJobCardsHtml {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][object[]]$Jobs
    )

    foreach ($job in @($Jobs)) {
        $description = ConvertTo-JobAgentReportText -Value $job.description -Fallback 'Keine Beschreibung vorhanden'
        if ($description -eq 'UNKNOWN') {
            $description = 'Keine Beschreibung vorhanden'
        }
        if ($description.Length -gt 240) {
            $description = $description.Substring(0, 237) + '...'
        }
        $publication = if ($job.age_basis -eq 'PUBLISHED_AT') {
            'Veroeffentlicht: ' + (ConvertTo-JobAgentReportJobBoardText -Value $job.age_display)
        }
        else {
            'Erstmals erfasst am: ' + (ConvertTo-JobAgentReportJobBoardText -Value $job.age_display)
        }
        $meta = @(
            (ConvertTo-JobAgentReportJobBoardText -Value $job.company),
            (ConvertTo-JobAgentReportJobBoardText -Value $job.location),
            (ConvertTo-JobAgentReportJobBoardText -Value $job.work_model -Domain 'work_model'),
            (ConvertTo-JobAgentReportJobBoardText -Value $job.employment_type -Domain 'employment_type'),
            (ConvertTo-JobAgentReportJobBoardText -Value $job.work_time)
        )
        [void]$Lines.Add('<article class="result-card job-card" data-job-id="' + (ConvertTo-JobAgentReportHtmlText $job.job_id) + '" data-company-id="' + (ConvertTo-JobAgentReportHtmlText $job.company_id) + '">')
        [void]$Lines.Add('<h3>' + (ConvertTo-JobAgentReportHtmlText $job.title) + '</h3>')
        [void]$Lines.Add('<p class="job-card-meta">' + (ConvertTo-JobAgentReportHtmlText ($meta -join ' · ')) + '</p>')
        [void]$Lines.Add('<p class="job-card-date">' + (ConvertTo-JobAgentReportHtmlText $publication) + '</p>')
        [void]$Lines.Add('<p class="job-card-description">' + (ConvertTo-JobAgentReportHtmlText $description) + '</p>')
        [void]$Lines.Add('<details class="job-card-evidence"><summary>Zeitbelege und Herkunft</summary><p>Aktualitaet: ' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportJobBoardText -Value $job.availability)) + '. Zuletzt gesehen: ' + (ConvertTo-JobAgentReportHtmlText (ConvertTo-JobAgentReportJobBoardText -Value $job.last_seen)) + '. Letzte vollstaendige Listenpruefung: im Datenstand der Quelle.</p></details>')
        [void]$Lines.Add('<p class="job-card-links">' + (ConvertTo-JobAgentReportHtmlLink -Url $job.official_url -Label 'Original-Stellenanzeige' -Fallback 'Kein offizieller Link') + ' · ' + (ConvertTo-JobAgentReportHtmlLink -Url $job.career_url -Label 'Firma' -Fallback 'Kein Firmenlink') + '</p>')
        [void]$Lines.Add('</article>')
    }
}

function Add-JobAgentReportSearchInterfaceHtml {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][object]$Report
    )

    $clientData = [pscustomobject]@{
        scan_run_id = $Report.scan_run_id
        generated_at = $Report.generated_at
        reference_time = $Report.generated_at
        jobs = @($Report.sections.active_jobs | ForEach-Object {
                [pscustomobject]@{
                    job_id = $_.job_id
                    company = $_.company
                    title = $_.title
                    job_category = $_.job_category
                    requirements = @($_.requirements)
                    location = $_.location
                    company_id = $_.company_id
                    target_area = $_.target_area
                    area_facets = @($_.area_facets)
                    work_model = $_.work_model
                    employment_type = $_.employment_type
                    work_time = $_.work_time
                    age_basis = $_.age_basis
                    age_days = $_.age_days
                    age_display = $_.age_display
                    age_precision = $_.age_precision
                    time_projection = $_.time_projection
                    last_seen = $_.last_seen
                    availability = $_.availability
                    availability_reason = $_.availability_reason
                    official_url = $_.official_url
                    career_url = $_.career_url
                    description = $_.description
                    published_at = $_.published_at
                    published_on = $_.published_on
                    first_seen = $_.first_seen
                    change_history = @($_.change_history)
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
        report_status = $Report.statistics.status
        source_issues_count = @($Report.sections.source_issues).Count
        calendar = $Report.calendar
    }
    $calendarFallbackItems = [Collections.Generic.List[string]]::new()
    foreach ($attempt in @($Report.calendar.attempts | Sort-Object { if ($null -ne $_.finished_at) { $_.finished_at } else { $_.started_at } }, event_id)) {
        $timestamp = if ($null -ne $attempt.finished_at) { [string]$attempt.finished_at } else { [string]$attempt.started_at }
        $label = (ConvertTo-JobAgentReportHtmlText $timestamp) + ' · ' + (ConvertTo-JobAgentReportHtmlText ([string]$attempt.company)) + ' · ' + (ConvertTo-JobAgentReportHtmlText ([string]$attempt.status))
        [void]$calendarFallbackItems.Add('<li>' + $label + '</li>')
    }
    if ($calendarFallbackItems.Count -eq 0) {
        [void]$calendarFallbackItems.Add('<li>Keine gespeicherten Abrufe.</li>')
    }
    $calendarFallbackHtml = '<noscript><section class="calendar-static-fallback" aria-label="Gespeicherte Abrufe"><h2>Gespeicherte Abrufe</h2><p>Statische Abrufliste; Kalenderdetails erfordern JavaScript. Die Ansicht startet keine Abrufe.</p><ul>' + ($calendarFallbackItems -join '') + '</ul></section></noscript>'
    [void]$Lines.Add('<section id="jobagent-search" class="jobboard" aria-labelledby="jobagent-search-heading">')
    [void]$Lines.Add('<p class="eyebrow">JobAgent</p>')
    [void]$Lines.Add('<h1 id="jobagent-search-heading">Stellenangebote</h1>')
    [void]$Lines.Add('<p class="jobboard-reference">Datenstand: ' + (ConvertTo-JobAgentReportHtmlText $Report.generated_at) + '</p>')
    [void]$Lines.Add('<p>Die Suche arbeitet ausschliesslich lokal im angezeigten Bestand. Filter starten keinen Joblauf und aendern keine gespeicherten Daten.</p>')
    [void]$Lines.Add('<p><a href="company-coverage.html">Zur Firmen- und Coverage-Diagnose</a></p>')
    [void]$Lines.Add('<div class="search-tabs" role="tablist" aria-label="Bestandsansicht"><button type="button" id="jobagent-tab-jobs" role="tab" aria-selected="true" aria-controls="jobagent-jobs" data-jobagent-view="jobs">Stellen</button><button type="button" id="jobagent-tab-companies" role="tab" aria-selected="false" aria-controls="jobagent-companies" data-jobagent-view="companies">Firmen</button><button type="button" id="jobagent-tab-applications" role="tab" aria-selected="false" aria-controls="jobagent-applications" data-jobagent-view="applications">Bewerbungen</button><button type="button" id="jobagent-tab-calendar" role="tab" aria-selected="false" aria-controls="jobagent-calendar" data-jobagent-view="calendar">Kalender</button></div>')
    [void]$Lines.Add('<div class="jobboard-layout"><details class="filter-region" open><summary>Filter</summary><form id="jobagent-filters" class="filters" novalidate><label>Was?<input id="jobagent-query" name="q" type="search" autocomplete="off" placeholder="Titel, Firma, Beruf, Beschreibung oder Anforderung"></label><label>Arbeitgeber<select id="jobagent-company" name="company" multiple size="5"></select></label><label>Berufsgruppe<select id="jobagent-category" name="category" multiple size="5"></select></label><label>Wo?<select id="jobagent-area" name="area" multiple size="5" aria-describedby="jobagent-filter-help"><option value="MUNICH">Muenchen Stadt</option><option value="MUNICH_20KM">Muenchen 20 km</option><option value="FREISING_CITY">Freising Stadt</option><option value="FREISING_COUNTY">Landkreis Freising</option><option value="FREISING_UNSPECIFIED">Freising (Gebiet nicht weiter belegt)</option><option value="REMOTE_WITH_TARGET_REFERENCE">Remote/Hybrid mit Zielgebietsbezug</option><option value="UNKNOWN">Keine Angabe</option></select></label><label>Arbeitsmodell<select id="jobagent-work-model" name="workModel" multiple size="4"><option value="REMOTE">Remote</option><option value="HYBRID">Hybrid</option><option value="ONSITE">Vor Ort</option><option value="UNKNOWN">Keine Angabe</option></select></label><label>Anstellungsart<select id="jobagent-employment-type" name="employmentType" multiple size="5"><option value="FULL_TIME">Vollzeit</option><option value="PART_TIME">Teilzeit</option><option value="CONTRACT">Befristet/Vertrag</option><option value="PERMANENT">Unbefristet</option><option value="INTERNSHIP">Praktikum</option><option value="UNKNOWN">Keine Angabe</option></select></label><label>Arbeitszeit<select id="jobagent-work-time" name="workTime" multiple size="2"><option value="UNKNOWN">Keine Angabe</option></select></label><label>Aktualitaet<select id="jobagent-age" name="age"><option value="">Alle</option><option value="1">Letzter Tag</option><option value="7">Letzte 7 Tage</option><option value="30">Letzte 30 Tage</option><option value="older">Aelter als 30 Tage</option><option value="UNKNOWN">Keine Angabe</option></select></label><label><input id="jobagent-favorites" name="favorite" type="checkbox"> Nur Favoriten</label><label>Bewerbungsstatus<select id="jobagent-applied" name="applied"><option value="all">Alle</option><option value="beworben">Schon beworben</option><option value="nicht_beworben">Noch nicht beworben</option></select></label><label>Sortierung<select id="jobagent-sort" name="sort"><option value="published_desc">Neueste zuerst</option><option value="title_asc">Titel A-Z</option><option value="company_asc">Arbeitgeber A-Z</option><option value="confirmed_desc">Zuletzt bestaetigt</option></select></label><button type="reset" id="jobagent-reset">Alle Filter zuruecksetzen</button></form><p id="jobagent-filter-help" class="unknown">Mehrfachauswahl: Werte im selben Feld werden alternativ, verschiedene Filter gemeinsam angewendet. Facettenzahlen beziehen sich auf alle passenden Stellen ausserhalb der jeweiligen Facette.</p><div id="jobagent-filter-chips" class="search-tabs" aria-label="Aktive Filter"></div></details><div class="jobboard-results"><p id="jobagent-result-count" class="result-count" role="status" aria-live="polite"></p><div id="jobagent-jobs" role="tabpanel" aria-labelledby="jobagent-tab-jobs"><div id="jobagent-job-results" class="result-list">')
    if (@($Report.sections.active_jobs).Count -eq 0) {
        $emptyText = if (($Report.statistics.status -eq 'PARTIAL') -or (@($Report.sections.source_issues).Count -gt 0)) { 'Abruf unvollstaendig' } else { 'Keine offenen Stellen erfasst' }
        [void]$Lines.Add('<p class="empty-state">' + (ConvertTo-JobAgentReportHtmlText $emptyText) + '</p>')
    }
    else {
        Add-JobAgentReportStaticJobCardsHtml -Lines $Lines -Jobs @($Report.sections.active_jobs)
    }
    [void]$Lines.Add('</div></div><div id="jobagent-companies" role="tabpanel" aria-labelledby="jobagent-tab-companies" hidden><div id="jobagent-company-results" class="result-list"></div></div><div id="jobagent-applications" role="tabpanel" aria-labelledby="jobagent-tab-applications" hidden><form id="jobagent-application-filters" class="filters application-filters" novalidate><label>Notiz, Aktion oder Stelle<input id="jobagent-application-query" type="search" autocomplete="off" aria-label="Notiz, Aktion oder Stelle" placeholder="Lokale Notiz, naechste Aktion, Titel oder Firma"></label><label>Status<select id="jobagent-application-stage" aria-label="Bewerbungsstatus"><option value="all">Alle aktiven Status</option><option value="PREPARING">Vorbereiten</option><option value="APPLIED">Beworben</option><option value="INTERVIEW">Gespraech</option><option value="REJECTED">Absage</option><option value="WITHDRAWN">Zurueckgezogen</option></select></label><label>Faelligkeit<select id="jobagent-application-due" aria-label="Faelligkeit"><option value="all">Alle Termine</option><option value="overdue">Ueberfaellig</option><option value="next_7">Faellig in 7 Tagen</option><option value="open">Mit offenem Termin</option><option value="none">Ohne offenen Termin</option></select></label><label>Sortierung<select id="jobagent-application-sort" aria-label="Bewerbungssortierung"><option value="due_then_id">Faelligkeit, dann Stellen-ID</option><option value="stage_then_id">Status, dann Stellen-ID</option><option value="job_id">Stellen-ID</option></select></label><button type="reset" id="jobagent-application-reset" aria-label="Bewerbungsfilter zuruecksetzen">Filter zuruecksetzen</button></form><p id="jobagent-application-filter-help" class="unknown">Die Fälligkeit wird gegen den Datenstand des Reports berechnet; persönliche Daten bleiben ausschliesslich lokal.</p><div id="jobagent-application-results" class="result-list"></div></div><div id="jobagent-calendar" role="tabpanel" aria-labelledby="jobagent-tab-calendar" hidden>' + $calendarFallbackHtml + '</div><nav id="jobagent-pagination" class="pagination" aria-label="Seitennavigation"></nav><p class="no-js-notice">Persoenliche Funktionen erfordern JavaScript und sind in dieser statischen Ansicht nicht verfuegbar.</p></div></div>')
    [void]$Lines.Add('<script id="jobagent-search-data" type="application/json">' + (ConvertTo-JobAgentReportClientDataJson -Value $clientData) + '</script>')
    [void]$Lines.Add('<script>' + (Get-JobAgentReportUserStateScript) + '</script>')
    [void]$Lines.Add('<script>')
    [void]$Lines.Add('(function () {')
    [void]$Lines.Add('const data=JSON.parse(document.getElementById("jobagent-search-data").textContent),pageSize=50,form=document.getElementById("jobagent-filters"),count=document.getElementById("jobagent-result-count"),pagination=document.getElementById("jobagent-pagination");')
    [void]$Lines.Add('const normalize=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("de-DE").replace(/[^\p{L}\p{N}]+/gu," ").trim(),decodeQuery=value=>{let current=String(value||"");for(let attempt=0;attempt<3;attempt++){try{const decoded=decodeURIComponent(current.replace(/\+/g,"%20"));if(decoded===current)break;current=decoded}catch{break}}return current},selected=id=>Array.from(document.getElementById(id).selectedOptions,o=>o.value),text=(value,fallback="Keine Angabe")=>value&&value!=="UNKNOWN"?String(value):fallback,display=(value,labels={})=>value&&value!=="UNKNOWN"?(labels[value]||String(value)):"Keine Angabe";')
    [void]$Lines.Add('const link=(url,label)=>{const a=document.createElement("a");if(/^https?:\/\//i.test(String(url||""))){a.href=url;a.target="_blank";a.rel="noopener noreferrer";a.textContent=label;return a}const span=document.createElement("span");span.className="unknown";span.textContent="Kein offizieller Link";return span};')
    [void]$Lines.Add('const companyIds=data.jobs.map(job=>job.company_id),categories=data.jobs.map(job=>job.job_category||"UNKNOWN"),allowed={company:[...new Set(companyIds)],category:[...new Set(categories)],area:["MUNICH","MUNICH_20KM","FREISING_CITY","FREISING_COUNTY","FREISING_UNSPECIFIED","REMOTE_WITH_TARGET_REFERENCE","UNKNOWN"],workModel:["REMOTE","HYBRID","ONSITE","UNKNOWN"],employmentType:["FULL_TIME","PART_TIME","CONTRACT","PERMANENT","INTERNSHIP","UNKNOWN"],workTime:[...new Set(data.jobs.map(job=>job.work_time||"UNKNOWN"))]};const canonicalList=(value,values,preserveUnsupported=false)=>[...new Set(String(value||"").split(",").filter(item=>item&&(preserveUnsupported||values.includes(item))))].sort((a,b)=>a.localeCompare(b,"de")),listFromHash=(p,key,values,preserveUnsupported=false)=>canonicalList(p.get(key),values,preserveUnsupported),selectOptions=(id,items,label)=>{const node=document.getElementById(id);items.slice().sort((a,b)=>label(a).localeCompare(label(b),"de")).forEach(value=>{const option=document.createElement("option");option.value=value;option.textContent=label(value);node.append(option)})};const hydrateCompanies=()=>{const node=document.getElementById("jobagent-company");if(node.options.length)return;selectOptions("jobagent-company",allowed.company,id=>{const job=data.jobs.find(entry=>entry.company_id===id);return (job?text(job.company):id)+" ["+id+"]"});sync(read())};const companySelect=document.getElementById("jobagent-company");companySelect.addEventListener("pointerdown",hydrateCompanies,{once:true});companySelect.addEventListener("keydown",event=>{if(["ArrowDown","ArrowUp","Enter"," "].includes(event.key))hydrateCompanies()});selectOptions("jobagent-category",allowed.category,value=>display(value));')
    [void]$Lines.Add('const visibilityLabel=document.createElement("label"),visibilitySelect=document.createElement("select");visibilityLabel.textContent="Sichtbarkeit";visibilitySelect.id="jobagent-visibility";[["visible","Sichtbare Stellen"],["all","Alle Stellen"],["hidden","Ausblendungen verwalten"]].forEach(([value,label])=>{const option=document.createElement("option");option.value=value;option.textContent=label;visibilitySelect.append(option)});visibilityLabel.append(visibilitySelect);form.insertBefore(visibilityLabel,document.getElementById("jobagent-reset"));visibilitySelect.addEventListener("change",()=>{const p=new URLSearchParams(location.hash.slice(1));if(visibilitySelect.value==="visible")p.delete("visibility");else p.set("visibility",visibilitySelect.value);p.delete("page");location.hash="#"+p.toString()});')
    [void]$Lines.Add('const read=()=>{const rawHash=location.hash.slice(1),p=new URLSearchParams(rawHash),rawPage=p.get("page"),requestedPage=Number(rawPage),rawQuery=p.get("q")||"",query=decodeQuery(rawQuery),rawJob=p.get("job"),job=rawJob||"",unknownJob=rawJob!==null&&rawJob!==""&&!data.jobs.some(candidate=>candidate.job_id===rawJob),jobNeedsNormalization=rawJob!==null&&rawJob!==""&&!rawHash.includes("job="+encodeURIComponent(rawJob)),sort=["published_desc","title_asc","company_asc","confirmed_desc"].includes(p.get("sort"))?p.get("sort"):"published_desc",applied=["all","beworben","nicht_beworben"].includes(p.get("applied"))?p.get("applied"):"all",age=["","1","7","30","older","UNKNOWN"].includes(p.get("age"))?p.get("age"):"",listKeys=[["company",allowed.company,false],["category",allowed.category,false],["area",allowed.area,true],["workModel",allowed.workModel,false],["employmentType",allowed.employmentType,false],["workTime",allowed.workTime,false]],filtersNeedNormalization=listKeys.some(([key,values,preserveUnsupported])=>canonicalList(p.get(key),values,preserveUnsupported).join(",")!==(p.get(key)||""))||(p.has("favorite")&&p.get("favorite")!=="1")||(p.has("applied")&&p.get("applied")!==applied)||(p.has("sort")&&p.get("sort")!==sort)||(p.has("age")&&p.get("age")!==age);return{view:p.get("view")==="companies"?"companies":"jobs",page:Math.max(1,requestedPage||1),_pageNeedsNormalization:rawPage!==null&&(!Number.isInteger(requestedPage)||requestedPage<1),_queryNeedsNormalization:rawQuery!==query,_jobNeedsNormalization:jobNeedsNormalization,_filtersNeedNormalization:filtersNeedNormalization,_unknownJob:unknownJob,q:query,job,company:listFromHash(p,"company",allowed.company),category:listFromHash(p,"category",allowed.category),area:listFromHash(p,"area",allowed.area,true),workModel:listFromHash(p,"workModel",allowed.workModel),employmentType:listFromHash(p,"employmentType",allowed.employmentType),workTime:listFromHash(p,"workTime",allowed.workTime),age,favorite:p.get("favorite")==="1",applied,sort}};')
    [void]$Lines.Add('const write=(state,replace)=>{const p=new URLSearchParams();Object.entries(state).forEach(([key,value])=>{if(key.startsWith("_"))return;const output=Array.isArray(value)?value.join(","):value;if(output&&!(key==="page"&&Number(output)===1)&&!(key==="sort"&&output==="published_desc")&&!(key==="applied"&&output==="all")&&!(key==="favorite"&&value===false))p.set(key,output)});const target="#"+p.toString();if(replace)history.replaceState(null,"",target);else location.hash=target};')
    [void]$Lines.Add('const setSelect=(id,values)=>Array.from(document.getElementById(id).options).forEach(option=>option.selected=values.includes(option.value));const sync=state=>{document.getElementById("jobagent-query").value=state.q;document.getElementById("jobagent-age").value=state.age;document.getElementById("jobagent-favorites").checked=state.favorite;document.getElementById("jobagent-applied").value=state.applied;document.getElementById("jobagent-sort").value=state.sort;visibilitySelect.value=visibilityMode();["company","category","area","workModel","employmentType","workTime"].forEach(key=>setSelect("jobagent-"+(key==="company"?"company":key==="category"?"category":key.replace(/[A-Z]/g,letter=>"-"+letter.toLowerCase())),state[key]))};')
    [void]$Lines.Add('const currentFilters=()=>({q:document.getElementById("jobagent-query").value,company:selected("jobagent-company"),category:selected("jobagent-category"),area:selected("jobagent-area"),workModel:selected("jobagent-work-model"),employmentType:selected("jobagent-employment-type"),workTime:selected("jobagent-work-time"),age:document.getElementById("jobagent-age").value,favorite:document.getElementById("jobagent-favorites").checked,applied:document.getElementById("jobagent-applied").value,sort:document.getElementById("jobagent-sort").value});')
    [void]$Lines.Add('const includesAny=(values,candidates)=>values.length===0||candidates.some(candidate=>values.includes(candidate)),ageMatches=(job,age)=>{if(!age)return true;const days=Number(job.age_days);if(!Number.isFinite(days))return age==="UNKNOWN";return age==="older"?days>30:days<=Number(age)},userRecords=()=>{try{const loaded=window.JobAgentUserState&&window.JobAgentUserState.read(window.localStorage);return loaded&&loaded.persistent?loaded.state.jobs:{}}catch{return {}}};')
    [void]$Lines.Add('const visibilityMode=()=>{const value=new URLSearchParams(location.hash.slice(1)).get("visibility");return ["visible","all","hidden"].includes(value)?value:"visible"},userState=()=>{try{const loaded=window.JobAgentUserState&&window.JobAgentUserState.read(window.localStorage);return loaded&&loaded.persistent?loaded.state:window.JobAgentUserState.createEmptyState()}catch{return {jobs:{},hidden_jobs:{},hidden_companies:{}}}},visibilityOf=job=>{const state=userState(),entry=state.hidden_jobs[job.job_id],company=state.hidden_companies[job.company_id];return entry&&entry.hidden?{hidden:true,scope:"job",entry,companyHidden:Boolean(company&&company.hidden)}:company&&company.hidden?{hidden:true,scope:"company",entry:company,companyHidden:true}:{hidden:false,scope:"",entry:null,companyHidden:false}},visibilityMatches=(job,record={},mode=visibilityMode())=>{const hidden=visibilityOf(job).hidden;return mode==="all"?true:mode==="hidden"?hidden:!hidden||record.favorite===true||record.applied===true};')
    [void]$Lines.Add('const jobMatches=(job,state,records=userRecords())=>{const tokens=normalize(state.q).split(" ").filter(Boolean),haystack=job._search_text||(job._search_text=normalize([job.title,job.company,job.job_category,job.description,...(job.requirements||[])].join(" "))),record=records[job.job_id]||{},subset=window.JobAgentSavedSearchSubset;return tokens.every(token=>haystack.includes(token))&&includesAny(state.company,[job.company_id])&&includesAny(state.category,[job.job_category||"UNKNOWN"])&&includesAny(state.area,job.area_facets||[job.target_area])&&includesAny(state.workModel,[job.work_model])&&includesAny(state.employmentType,[job.employment_type])&&includesAny(state.workTime,[job.work_time])&&ageMatches(job,state.age)&&(!state.favorite||record.favorite===true)&&(state.applied==="all"||(state.applied==="beworben"?record.applied===true:record.applied!==true))&&visibilityMatches(job,record,state.visibility||visibilityMode())&&(!subset||subset.ids.includes(job.job_id))};')
    [void]$Lines.Add('const companyMatches=(company,state)=>{const tokens=normalize(state.q).split(" ").filter(Boolean),haystack=normalize([company.company,...(company.locations||[])].join(" "));return tokens.every(token=>haystack.includes(token))};const hasStructuredFilters=state=>state.company.length||state.category.length||state.area.length||state.workModel.length||state.employmentType.length||state.workTime.length||state.age||state.applied==="nicht_beworben";const historicalRecords=(records,state)=>{if(hasStructuredFilters(state)||(!state.favorite&&state.applied!=="beworben"))return[];const tokens=normalize(state.q).split(" ").filter(Boolean),activeIds=new Set(data.jobs.map(job=>job.job_id));return Object.entries(records).filter(([jobId,record])=>!activeIds.has(jobId)&&record&&record.reference&&(state.favorite?record.favorite===true:true)&&(state.applied==="beworben"?record.applied===true:true)).filter(([,record])=>tokens.every(token=>normalize([record.reference.title,record.reference.company].join(" ")).includes(token))).sort(([left],[right])=>left.localeCompare(right,"de"))};')
    [void]$Lines.Add('const sortJobs=(items,sort)=>items.slice().sort((left,right)=>{const textOrder=(a,b)=>String(a||"").localeCompare(String(b||""),"de"),byId=()=>textOrder(left.job_id,right.job_id);if(sort==="title_asc")return textOrder(left.title,right.title)||textOrder(left.company,right.company)||byId();if(sort==="company_asc")return textOrder(left.company,right.company)||textOrder(left.title,right.title)||byId();const timestamp=item=>{const value=sort==="confirmed_desc"?item.last_seen:(item.published_at&&item.published_at!=="UNKNOWN"?item.published_at:item.first_seen);const parsed=Date.parse(value);return Number.isFinite(parsed)?parsed:0};return timestamp(right)-timestamp(left)||byId()});const matchesFacet=(job,key,value)=>key==="company"?job.company_id===value:key==="category"?(job.job_category||"UNKNOWN")===value:key==="area"?(job.area_facets||[job.target_area]).includes(value):key==="workModel"?job.work_model===value:key==="employmentType"?job.employment_type===value:key==="workTime"?job.work_time===value:false;')
    [void]$Lines.Add('const applicationLabels={NONE:"Nicht begonnen",PREPARING:"Vorbereiten",APPLIED:"Beworben",INTERVIEW:"Gespraech",REJECTED:"Absage",WITHDRAWN:"Zurueckgezogen"},allowedStageChange=(from,to)=>(from==="NONE"&&["PREPARING","APPLIED"].includes(to))||(from==="PREPARING"&&["NONE","APPLIED"].includes(to))||(from==="APPLIED"&&["INTERVIEW","REJECTED","WITHDRAWN"].includes(to))||(from==="INTERVIEW"&&["REJECTED","WITHDRAWN"].includes(to)),applicationEditor=(job,record,onSaved,expanded)=>{const panel=document.createElement("details"),heading=document.createElement("summary"),status=document.createElement("p"),stageLabel=document.createElement("label"),stage=document.createElement("select"),noteLabel=document.createElement("label"),note=document.createElement("textarea"),nextLabel=document.createElement("label"),next=document.createElement("input"),save=document.createElement("button"),taskHeading=document.createElement("h5"),taskType=document.createElement("select"),taskTitle=document.createElement("input"),taskDate=document.createElement("input"),taskTime=document.createElement("input"),addTask=document.createElement("button"),taskList=document.createElement("ul"),draft=record||{};panel.className="application-editor";panel.open=expanded===true;heading.textContent="Bewerbung bearbeiten";status.className="job-mark-message";status.setAttribute("role","status");stageLabel.textContent="Status";Object.entries(applicationLabels).forEach(([value,label])=>{const option=document.createElement("option");option.value=value;option.textContent=label;option.selected=value===(draft.application_stage||"NONE");stage.append(option)});stageLabel.append(stage);noteLabel.textContent="Notiz";note.maxLength=4000;note.rows=4;note.value=draft.note||"";noteLabel.append(note);nextLabel.textContent="Naechste Aktion";next.maxLength=200;next.value=draft.next_action||"";nextLabel.append(next);save.type="button";save.textContent="Notiz und naechste Aktion speichern";save.addEventListener("click",()=>{try{const changedStage=stage.value!==(draft.application_stage||"NONE");if(changedStage){const correction=!allowedStageChange(draft.application_stage||"NONE",stage.value);if(correction&&!window.confirm("Dieser Statuswechsel ist eine Korrektur. Vorheriger und neuer Status werden lokal in der Chronik gespeichert. Fortfahren?")){status.textContent="Statuskorrektur abgebrochen.";return}const result=window.JobAgentUserState.transitionApplication(window.localStorage,job,stage.value,correction?{correction:true,reason:"Manuelle Statuskorrektur"}:null);if(!result.persistent){status.textContent="Bewerbungsstatus konnte nicht lokal gespeichert werden.";return}}const result=window.JobAgentUserState.updateApplicationText(window.localStorage,job,{note:note.value,next_action:next.value});status.textContent=result.persistent?"Bewerbungsdaten lokal gespeichert.":"Bewerbungsdaten konnten nicht lokal gespeichert werden.";if(result.persistent)onSaved()}catch(error){status.textContent=error&&error.message?error.message:"Bewerbungsdaten sind ungueltig."}});taskHeading.textContent="Termin hinzufuegen";[["APPLICATION_DEADLINE","Bewerbungsfrist"],["INTERVIEW","Gespraech"],["FOLLOW_UP","Nachfassen"],["OTHER","Sonstiges"]].forEach(([value,label])=>{const option=document.createElement("option");option.value=value;option.textContent=label;taskType.append(option)});taskType.setAttribute("aria-label","Terminart");taskTitle.placeholder="Titel";taskTitle.maxLength=200;taskTitle.setAttribute("aria-label","Termintitel");taskDate.type="date";taskDate.setAttribute("aria-label","Lokales Datum");taskTime.type="text";taskTime.placeholder="09:00+02:00 (optional)";taskTime.setAttribute("aria-label","Uhrzeit mit Offset");addTask.type="button";addTask.textContent="Termin speichern";addTask.addEventListener("click",()=>{try{const task={task_id:"task_"+Date.now()+"_"+Math.random().toString(36).slice(2,8),type:taskType.value,title:taskTitle.value,local_date:taskDate.value,time_with_offset:taskTime.value||null,status:"OPEN"},result=window.JobAgentUserState.upsertTask(window.localStorage,job,task);status.textContent=result.persistent?"Termin lokal gespeichert.":"Termin konnte nicht lokal gespeichert werden.";if(result.persistent)onSaved()}catch(error){status.textContent=error&&error.message?error.message:"Termin ist ungueltig."}});(draft.tasks||[]).filter(task=>task.deleted_at===null).sort((a,b)=>a.local_date.localeCompare(b.local_date)||a.task_id.localeCompare(b.task_id)).forEach(task=>{const item=document.createElement("li"),done=document.createElement("button"),remove=document.createElement("button");item.textContent=(task.status==="DONE"?"Erledigt: ":"Offen: ")+task.local_date+(task.time_with_offset?" "+task.time_with_offset:"")+" · "+task.title+" ";done.type="button";done.textContent=task.status==="DONE"?"Wieder oeffnen":"Erledigen";done.addEventListener("click",()=>{try{const result=window.JobAgentUserState.upsertTask(window.localStorage,job,{...task,status:task.status==="DONE"?"OPEN":"DONE"});status.textContent=result.persistent?"Termin aktualisiert.":"Termin konnte nicht gespeichert werden.";if(result.persistent)onSaved()}catch(error){status.textContent=error.message}});remove.type="button";remove.textContent="Loeschen";remove.addEventListener("click",()=>{try{const result=window.JobAgentUserState.deleteTask(window.localStorage,job,task.task_id);status.textContent=result.persistent?"Termin geloescht.":"Termin konnte nicht geloescht werden.";if(result.persistent)onSaved()}catch(error){status.textContent=error.message}});item.append(done,remove);taskList.append(item)});panel.append(heading,status,stageLabel,noteLabel,nextLabel,save,taskHeading,taskType,taskTitle,taskDate,taskTime,addTask,taskList);return panel};window.JobAgentApplicationEditor=applicationEditor;')
    [void]$Lines.Add('const markStatusByJob=new Map(),markButton=(job,field,record,onSaved)=>{const enabled=record[field]===true,button=document.createElement("button");button.type="button";button.className="job-mark job-mark-"+field;button.dataset.jobMark=field;button.setAttribute("aria-pressed",String(enabled));button.setAttribute("aria-label",field==="favorite"?(enabled?"Favorit entfernen":"Als Favorit merken"):(enabled?"Bewerbungsmarkierung entfernen":"Als schon beworben markieren"));button.textContent=field==="favorite"?(enabled?"★ Favorit entfernen":"☆ Als Favorit merken"):(enabled?"☑ Bewerbungsmarkierung entfernen":"☐ Als schon beworben markieren");button.addEventListener("click",event=>{event.preventDefault();event.stopPropagation();let result;try{const reset=field==="applied"&&enabled&&["INTERVIEW","REJECTED","WITHDRAWN"].includes(record.application_stage);if(reset&&!window.confirm("Die Bewerbungsmarkierung wird zurueckgesetzt. Der Status wird auf Nicht begonnen gesetzt; Notizen, Termine und Chronik bleiben erhalten. Fortfahren?"))return;result=window.JobAgentUserState&&window.JobAgentUserState.setMark(window.localStorage,job,field,!enabled,undefined,reset?{correction:true,reason:"Ruecksetzung ueber Bewerbungsmarkierung"}:null)}catch{result={persistent:false,reason:"storage_unavailable"}};const saved=result&&result.persistent,notification=field==="favorite"?(saved?"Favorit lokal gespeichert.":"Favorit konnte nicht lokal gespeichert werden."):(saved?"Bewerbungsmarkierung lokal gespeichert.":"Bewerbungsmarkierung konnte nicht lokal gespeichert werden.");markStatusByJob.set(job.job_id,notification);onSaved(result,field);setTimeout(render,0);});return button};')
    [void]$Lines.Add('const jobCard=(job,record=userRecords()[job.job_id]||{})=>{const article=document.createElement("article"),heading=document.createElement("h3"),detailButton=document.createElement("button"),meta=document.createElement("p"),date=document.createElement("p"),description=document.createElement("p"),evidence=document.createElement("details"),summary=document.createElement("summary"),evidenceText=document.createElement("p"),actions=document.createElement("p"),message=document.createElement("p"),links=document.createElement("p"),modelLabels={REMOTE:"Remote",HYBRID:"Hybrid",ONSITE:"Vor Ort"},employmentLabels={FULL_TIME:"Vollzeit",PART_TIME:"Teilzeit",CONTRACT:"Befristet/Vertrag",PERMANENT:"Unbefristet",INTERNSHIP:"Praktikum"},published=job.published_at&&job.published_at!=="UNKNOWN"||job.published_on&&job.published_on!=="UNKNOWN",projection=job.time_projection||{},source=projection.source||{},complete=source.latest_complete_list_attempt||{};article.className="result-card job-card";article.dataset.jobId=job.job_id;article.dataset.companyId=job.company_id;detailButton.type="button";detailButton.className="job-detail-open";detailButton.textContent=text(job.title);detailButton.addEventListener("click",()=>write({...read(),job:job.job_id},false));heading.append(detailButton);meta.className="job-card-meta";meta.textContent=[text(job.company),text(job.location),display(job.work_model,modelLabels),display(job.employment_type,employmentLabels),text(job.work_time)].join(" · ");date.className="job-card-date";date.textContent=published?"Veroeffentlicht: "+text(job.age_display):"Erstmals erfasst am: "+text(job.age_display);description.className="job-card-description";description.textContent=text(job.description,"Keine Beschreibung vorhanden").slice(0,240);evidence.className="job-card-evidence";summary.textContent="Zeitbelege und Herkunft";evidenceText.textContent="Aktualitaet: "+text(job.availability)+". Zuletzt gesehen: "+text(job.last_seen)+". Letzte vollstaendige Listenpruefung: "+text(complete.finished&&complete.finished.display,"Historie nicht vorhanden")+".";evidence.append(summary,evidenceText);actions.className="job-card-actions";message.className="job-mark-message";message.setAttribute("role","status");message.textContent=markStatusByJob.get(job.job_id)||"";actions.append(markButton(job,"favorite",record,result=>{message.textContent=result&&result.persistent?"Favorit lokal gespeichert.":"Favorit konnte nicht lokal gespeichert werden."}),markButton(job,"applied",record,result=>{message.textContent=result&&result.persistent?"Bewerbungsmarkierung lokal gespeichert.":"Bewerbungsmarkierung konnte nicht lokal gespeichert werden."}));links.className="job-card-links";links.append(link(job.official_url,"Original-Stellenanzeige"),document.createTextNode(" · "),link(job.career_url,"Firma"));article.append(heading,meta,date,description,evidence,actions,message,applicationEditor(job,record,()=>setTimeout(render,0)),links);return article};')
    [void]$Lines.Add('const detailCard=(job,record)=>{const article=document.createElement("article"),back=document.createElement("button"),heading=document.createElement("h2"),meta=document.createElement("p"),facts=document.createElement("dl"),description=document.createElement("p"),requirements=document.createElement("p"),actions=document.createElement("p"),message=document.createElement("p"),links=document.createElement("p"),addFact=(label,value)=>{const term=document.createElement("dt"),definition=document.createElement("dd");term.textContent=label;definition.textContent=text(value);facts.append(term,definition)};article.className="result-card job-detail";article.dataset.jobId=job.job_id;back.type="button";back.textContent="Zur Trefferliste";back.addEventListener("click",()=>{focusDetailReturn=job.job_id;write({...read(),job:""},false)});heading.textContent=text(job.title);meta.className="job-card-meta";meta.textContent=text(job.company)+" · "+text(job.location);addFact("Arbeitsmodell",display(job.work_model,{REMOTE:"Remote",HYBRID:"Hybrid",ONSITE:"Vor Ort"}));addFact("Anstellungsart",display(job.employment_type,{FULL_TIME:"Vollzeit",PART_TIME:"Teilzeit",CONTRACT:"Befristet/Vertrag",PERMANENT:"Unbefristet",INTERNSHIP:"Praktikum"}));addFact("Arbeitszeit",job.work_time);addFact("Veroeffentlicht",job.published_at||job.published_on||"Keine Angabe");addFact("Erstmals erfasst",job.first_seen);addFact("Zuletzt gesehen",job.last_seen);addFact("Aktualitaet",job.availability);description.textContent="Beschreibung: "+text(job.description,"Keine Beschreibung vorhanden");requirements.textContent="Anforderungen: "+((job.requirements||[]).map(item=>text(item)).join("; ")||"Keine Angabe");actions.className="job-card-actions";message.className="job-mark-message";message.setAttribute("role","status");message.textContent=markStatusByJob.get(job.job_id)||"";actions.append(markButton(job,"favorite",record,result=>{message.textContent=result&&result.persistent?"Favorit lokal gespeichert.":"Favorit konnte nicht lokal gespeichert werden."}),markButton(job,"applied",record,result=>{message.textContent=result&&result.persistent?"Bewerbungsmarkierung lokal gespeichert.":"Bewerbungsmarkierung konnte nicht lokal gespeichert werden."}));links.className="job-card-links";links.append(link(job.official_url,"Original-Stellenanzeige"),document.createTextNode(" · "),link(job.career_url,"Firma"));article.append(back,heading,meta,facts,description,requirements,actions,message,applicationEditor(job,record,()=>setTimeout(render,0)),links);return article};')
    [void]$Lines.Add('const companyCard=company=>{const article=document.createElement("article"),heading=document.createElement("h3"),meta=document.createElement("p"),detail=document.createElement("p");article.className="result-card";article.dataset.companyId=company.company_id;heading.textContent=company.company;meta.textContent="Orte: "+text((company.locations||[]).join(", "));detail.textContent="Pruefstatus: "+text(company.verification_status)+" · Scan: "+text(company.scan_status);article.append(heading,meta,detail,link(company.official_website_url,"Website"),document.createTextNode(" · "),link(company.career_url,"Karriere"));return article};const historicalCard=([jobId,record])=>{const reference=record.reference,job={job_id:jobId,title:reference.title,company:reference.company,official_url:reference.official_url},article=document.createElement("article"),heading=document.createElement("h3"),status=document.createElement("p"),detail=document.createElement("p"),actions=document.createElement("p"),message=document.createElement("p");article.className="result-card job-card historical-job-card";article.dataset.jobId=jobId;heading.textContent=text(reference.title,"Lokale Stellenreferenz");status.className="historical-job-status";status.textContent="Nicht mehr im aktuellen offenen Stellenbestand";detail.textContent="Lokale Referenz: "+text(reference.company)+" · zuletzt lokal gespeichert: "+text(reference.observed_at);actions.className="job-card-actions";message.className="job-mark-message";message.setAttribute("role","status");message.textContent=markStatusByJob.get(jobId)||"";actions.append(markButton(job,"favorite",record,result=>{message.textContent=result&&result.persistent?"Favorit lokal gespeichert.":"Favorit konnte nicht lokal gespeichert werden."}),markButton(job,"applied",record,result=>{message.textContent=result&&result.persistent?"Bewerbungsmarkierung lokal gespeichert.":"Bewerbungsmarkierung konnte nicht lokal gespeichert werden."}));article.append(heading,status,detail,actions,message,link(reference.official_url,"Gespeicherter Original-Link"));return article};const unavailableDetail=()=>{const article=document.createElement("article"),back=document.createElement("button"),heading=document.createElement("h2"),message=document.createElement("p");article.className="result-card job-detail empty-state";back.type="button";back.textContent="Zur Trefferliste";back.addEventListener("click",()=>write({...read(),job:""},false));heading.textContent="Stellendetail nicht verfuegbar";message.textContent="Die angeforderte Stelle ist im aktuellen offenen Stellenbestand nicht enthalten.";article.append(back,heading,message);return article};')
    [void]$Lines.Add('const stageLabel={NONE:"Nicht begonnen",PREPARING:"Vorbereiten",APPLIED:"Beworben",INTERVIEW:"Gespraech",REJECTED:"Absage",WITHDRAWN:"Zurueckgezogen"},applicationRecords=records=>Object.entries(records).filter(([,record])=>record&&record.application_stage&&record.application_stage!=="NONE").map(([jobId,record])=>({job:data.jobs.find(item=>item.job_id===jobId)||{job_id:jobId,title:(record.reference&&record.reference.title)||"Lokale Stellenreferenz",company:(record.reference&&record.reference.company)||"Keine Angabe"},record})).sort((left,right)=>{const due=entry=>entry.record.tasks.filter(task=>task.deleted_at===null&&task.status==="OPEN").sort((a,b)=>a.local_date.localeCompare(b.local_date)||a.task_id.localeCompare(b.task_id))[0];const leftDue=due(left),rightDue=due(right);return String(leftDue&&leftDue.local_date||"9999-12-31").localeCompare(String(rightDue&&rightDue.local_date||"9999-12-31"))||left.job.job_id.localeCompare(right.job.job_id,"de")}),applicationCard=entry=>{const article=document.createElement("article"),heading=document.createElement("h3"),stage=document.createElement("p"),next=document.createElement("p"),tasks=document.createElement("ul"),job=entry.job,record=entry.record;article.className="result-card application-card";article.dataset.jobId=job.job_id;heading.textContent=text(job.title)+" · "+text(job.company);stage.textContent="Status: "+(stageLabel[record.application_stage]||"Keine Angabe");next.textContent=record.next_action?"Naechste Aktion: "+record.next_action:"Keine naechste Aktion gespeichert.";record.tasks.filter(task=>task.deleted_at===null&&task.status==="OPEN").sort((a,b)=>a.local_date.localeCompare(b.local_date)||a.task_id.localeCompare(b.task_id)).forEach(task=>{const item=document.createElement("li");item.textContent="Offen: "+task.local_date+(task.time_with_offset?" "+task.time_with_offset:"")+" · "+task.title;tasks.append(item)});if(!tasks.childElementCount){const item=document.createElement("li");item.textContent="Keine offenen Termine.";tasks.append(item)}article.append(heading,stage,next,tasks);return article};')
    [void]$Lines.Add('const renderChips=state=>{const root=document.getElementById("jobagent-filter-chips"),entries=[];if(state.q)entries.push(["q",state.q,"Was"]);["company","category","area","workModel","employmentType","workTime"].forEach(key=>state[key].forEach(value=>entries.push([key,value,key])));if(state.age)entries.push(["age",state.age,"Aktualitaet"]);if(state.favorite)entries.push(["favorite","1","Favoriten"]);if(state.applied!=="all")entries.push(["applied",state.applied,"Bewerbung"]);root.replaceChildren(...entries.map(([key,value,label])=>{const button=document.createElement("button");button.type="button";button.className="filter-chip";button.textContent=label+": "+value+" ×";button.setAttribute("aria-label","Filter "+label+" "+value+" entfernen");button.addEventListener("click",()=>{const next={...state,page:1};if(Array.isArray(next[key]))next[key]=next[key].filter(candidate=>candidate!==value);else if(key==="favorite")next.favorite=false;else if(key==="applied")next.applied="all";else next[key]="";write(next,false)});return button}))};')
    [void]$Lines.Add('let focusCurrentPage=false,focusReset=false,focusDetailReturn="";const render=()=>{const state=read(),records=userRecords();sync(state);renderChips(state);const isJobs=state.view==="jobs",matchedJobs=data.jobs.filter(job=>jobMatches(job,state,records)),items=isJobs?sortJobs(matchedJobs,state.sort):data.companies.filter(company=>companyMatches(company,state)).sort((a,b)=>[a.company,a.company_id].join("\\u0000").localeCompare([b.company,b.company_id].join("\\u0000"),"de")),pages=Math.max(1,Math.ceil(items.length/pageSize)),page=Math.min(state.page,pages),slice=items.slice((page-1)*pageSize,page*pageSize),historical=isJobs&&!state.job&&!state._unknownJob?historicalRecords(records,state):[],target=document.getElementById(isJobs?"jobagent-job-results":"jobagent-company-results");["company","category","area","workModel","employmentType","workTime"].forEach(key=>{const reduced={...state,[key]:[]};const node=document.getElementById("jobagent-"+(key==="company"?"company":key==="category"?"category":key.replace(/[A-Z]/g,letter=>"-"+letter.toLowerCase())));Array.from(node.options).forEach(option=>{const total=data.jobs.filter(job=>jobMatches(job,reduced,records)&&matchesFacet(job,key,option.value)).length;const original=option.dataset.label||option.textContent.replace(/ \\(\\d+\\)$/,""),label=option.dataset.label||original;option.dataset.label=label;option.textContent=label+" ("+total+")"})});document.getElementById("jobagent-jobs").hidden=!isJobs;document.getElementById("jobagent-companies").hidden=isJobs;document.getElementById("jobagent-tab-jobs").setAttribute("aria-selected",String(isJobs));document.getElementById("jobagent-tab-companies").setAttribute("aria-selected",String(!isJobs));if(isJobs&&state._unknownJob){target.replaceChildren(unavailableDetail());count.textContent="Stellendetail nicht verfuegbar";pagination.replaceChildren()}else if(isJobs&&state.job){const selectedJob=data.jobs.find(job=>job.job_id===state.job);target.replaceChildren(detailCard(selectedJob,records[selectedJob.job_id]||{}));count.textContent="Stellendetails: "+text(selectedJob.title);pagination.replaceChildren()}else{target.replaceChildren(...slice.map(isJobs?job=>jobCard(job,records[job.job_id]||{}):companyCard));if(historical.length){const heading=document.createElement("h3");heading.className="historical-job-heading";heading.textContent="Fruehere persoenliche Markierungen";target.append(heading,...historical.map(historicalCard))}if(!slice.length&&!historical.length){const empty=document.createElement("p");empty.className="empty-state";empty.textContent=isJobs?(state.q||state.company.length||state.category.length||state.area.length||state.workModel.length||state.employmentType.length||state.workTime.length||state.age||state.favorite||state.applied!=="all"?"Keine Treffer fuer diese Filter":(data.report_status==="PARTIAL"||data.source_issues_count>0?"Abruf unvollstaendig":"Keine offenen Stellen erfasst")):"Keine Firmen im angezeigten Bestand.";target.replaceChildren(empty)}count.textContent=(isJobs?"Stellen":"Firmen")+": "+items.length+" Treffer, Seite "+page+" von "+pages+" (sichtbar "+slice.length+")."+(historical.length?" Historische Markierungen: "+historical.length+".":"");pagination.replaceChildren();if(pages>1){for(let number=1;number<=pages;number++){const button=document.createElement("button");button.type="button";button.textContent=String(number);if(number===page)button.setAttribute("aria-current","page");button.addEventListener("click",()=>{focusCurrentPage=true;write({...state,page:number},false)});pagination.append(button)}}}if(focusCurrentPage){focusCurrentPage=false;const current=Array.from(pagination.getElementsByTagName("button")).find(candidate=>candidate.getAttribute("aria-current")==="page");if(current)current.focus({preventScroll:true})}if(focusReset){focusReset=false;const reset=document.getElementById("jobagent-reset");if(reset)requestAnimationFrame(()=>reset.focus({preventScroll:true}))}if(focusDetailReturn){const jobId=focusDetailReturn;focusDetailReturn="";const card=Array.from(target.querySelectorAll("[data-job-id]")).find(candidate=>candidate.dataset.jobId===jobId),button=card&&card.querySelector(".job-detail-open");if(button)button.focus({preventScroll:true})}if(page!==state.page||state._pageNeedsNormalization||state._queryNeedsNormalization||state._jobNeedsNormalization||state._filtersNeedNormalization)write({...state,page},true)};')
    [void]$Lines.Add('document.addEventListener("click",event=>{if(event.target.closest("[data-job-mark]"))setTimeout(render,0)});')
    [void]$Lines.Add('window.JobAgentSearch=Object.freeze({currentFilters:()=>({...currentFilters(),visibility:visibilityMode()}),applyFilters:filters=>{delete window.JobAgentSavedSearchSubset;write({...read(),...filters,view:"jobs",page:1,job:""},false)},snapshot:filters=>{const subset=window.JobAgentSavedSearchSubset;delete window.JobAgentSavedSearchSubset;const state={...read(),...filters,view:"jobs",page:1,job:"",visibility:filters.visibility||"visible"},records=userRecords(),jobs=data.jobs.filter(job=>jobMatches(job,state,records));if(subset)window.JobAgentSavedSearchSubset=subset;const personal=jobs.filter(job=>{const entry=userState().hidden_jobs[job.job_id];return entry&&entry.hidden===false}).map(job=>job.job_id),changes={};jobs.forEach(job=>changes[job.job_id]=(job.change_history||[]).map(entry=>entry.change_event_id).filter(Boolean));return{generation_id:data.scan_run_id||"",matching_job_ids:jobs.map(job=>job.job_id),visible_job_ids:jobs.map(job=>job.job_id),change_events_by_job:changes,personal_visibility_job_ids:personal}},rerender:()=>window.dispatchEvent(new HashChangeEvent("hashchange"))});')
    [void]$Lines.Add('form.addEventListener("input",()=>{delete window.JobAgentSavedSearchSubset;write({...read(),...currentFilters(),page:1},false)});form.addEventListener("change",()=>{delete window.JobAgentSavedSearchSubset;write({...read(),...currentFilters(),page:1},false)});form.addEventListener("reset",()=>{delete window.JobAgentSavedSearchSubset;focusReset=true;setTimeout(()=>write({view:read().view,page:1,q:"",company:[],category:[],area:[],workModel:[],employmentType:[],workTime:[],age:"",favorite:false,applied:"all",sort:"published_desc"},false),0)});window.addEventListener("storage",render);document.querySelectorAll("[data-jobagent-view]").forEach(button=>{button.addEventListener("click",()=>write({...read(),view:button.dataset.jobagentView,page:1},false));button.addEventListener("keydown",event=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(event.key))return;event.preventDefault();const tabs=Array.from(document.querySelectorAll("[data-jobagent-view]")),index=tabs.indexOf(button),target=event.key==="Home"?tabs[0]:event.key==="End"?tabs[tabs.length-1]:tabs[(index+(event.key==="ArrowRight"?1:tabs.length-1))%tabs.length];target.focus();target.click()})});window.addEventListener("hashchange",render);render();')
    [void]$Lines.Add('}());')
    [void]$Lines.Add('</script>')
    [void]$Lines.Add('<script>' + (Get-JobAgentReportCalendarScript) + '</script>')
    [void]$Lines.Add('<script>' + (Get-JobAgentReportSavedSearchScript) + '</script>')
    [void]$Lines.Add('<script>(function(){const dataNode=document.getElementById("jobagent-search-data");if(!dataNode||!window.JobAgentUserState)return;let data;try{data=JSON.parse(dataNode.textContent)}catch{return}const jobById=new Map((data.jobs||[]).map(job=>[job.job_id,job])),rerender=()=>window.dispatchEvent(new HashChangeEvent("hashchange")),message=(card,value)=>{let node=card.querySelector(".job-visibility-message");if(!node){node=document.createElement("p");node.className="job-mark-message job-visibility-message";node.setAttribute("role","status");card.append(node)}node.textContent=value},addJobAction=card=>{if(card.querySelector("[data-job-visibility]"))return;const job=jobById.get(card.dataset.jobId);if(!job)return;const state=window.JobAgentUserState.read(localStorage).state,visibility=window.JobAgentUserState.visibilityFor(state,job.job_id,job.company_id),button=document.createElement("button");button.type="button";button.dataset.jobVisibility="job";button.textContent=visibility.scope==="job"&&visibility.entry.hidden?"Stelle wieder einblenden":"Nicht interessant";button.addEventListener("click",()=>{const current=window.JobAgentUserState.read(localStorage).state,now=window.JobAgentUserState.visibilityFor(current,job.job_id,job.company_id),hidden=!(now.scope==="job"&&now.entry.hidden),result=window.JobAgentUserState.setVisibility(localStorage,"job",job.job_id,hidden,hidden?{reason:"",text:""}:{});message(card,result.persistent?(hidden?"Stelle lokal ausgeblendet.":now.company_hidden?"Stelle einzeln eingeblendet; Arbeitgeber bleibt ausgeblendet.":"Stelle lokal eingeblendet."):"Ausblendung konnte nicht lokal gespeichert werden.");if(result.persistent)rerender()});const actions=card.querySelector(".job-card-actions");if(actions)actions.append(button);if(visibility.hidden){const badge=document.createElement("p");badge.className="unknown job-visibility-badge";badge.textContent=visibility.scope==="company"?"Durch ausgeblendeten Arbeitgeber verborgen.":"Persoenlich ausgeblendet.";card.insertBefore(badge,actions||null)}},addCompanyAction=card=>{if(card.querySelector("[data-company-visibility]"))return;const companyId=card.dataset.companyId;if(!companyId)return;const state=window.JobAgentUserState.read(localStorage).state,entry=state.hidden_companies[companyId],button=document.createElement("button");button.type="button";button.dataset.companyVisibility="company";button.textContent=entry&&entry.hidden?"Arbeitgeber wieder einblenden":"Stellen dieses Arbeitgebers ausblenden";button.addEventListener("click",()=>{const current=window.JobAgentUserState.read(localStorage).state,existing=current.hidden_companies[companyId],hidden=!(existing&&existing.hidden),result=window.JobAgentUserState.setVisibility(localStorage,"company",companyId,hidden,hidden?{reason:"EMPLOYER",text:""}:{});message(card,result.persistent?(hidden?"Arbeitgeber und seine Stellen lokal ausgeblendet.":"Arbeitgeber lokal eingeblendet."):"Ausblendung konnte nicht lokal gespeichert werden.");if(result.persistent)rerender()});card.append(document.createTextNode(" · "),button)},apply=()=>{document.querySelectorAll(".job-card[data-job-id],.job-detail[data-job-id]").forEach(addJobAction);document.querySelectorAll("#jobagent-company-results [data-company-id]").forEach(addCompanyAction)},observer=new MutationObserver(apply);observer.observe(document.getElementById("jobagent-search"),{childList:true,subtree:true});apply()}());</script>')
    [void]$Lines.Add('<script>(function(){const dataNode=document.getElementById("jobagent-search-data"),api=window.JobAgentUserState;if(!dataNode||!api)return;let data;try{data=JSON.parse(dataNode.textContent)}catch{return}const jobs=new Map((data.jobs||[]).map(job=>[job.job_id,job])),search=document.getElementById("jobagent-search"),notice=document.createElement("p"),rerender=()=>window.dispatchEvent(new HashChangeEvent("hashchange"));notice.id="jobagent-visibility-notice";notice.className="job-mark-message";notice.setAttribute("role","status");search.prepend(notice);const read=()=>api.read(localStorage).state,visible=(job,state=read())=>api.visibilityFor(state,job.job_id,job.company_id),clear=card=>card.querySelectorAll("[data-job-visibility],[data-company-visibility],[data-job-visibility-reason],[data-job-visibility-text],.job-visibility-badge,.company-visibility-summary").forEach(item=>item.remove()),announce=(text,undo)=>{notice.replaceChildren(document.createTextNode(text));if(undo){const button=document.createElement("button");button.type="button";button.textContent="Rueckgaengig";button.addEventListener("click",()=>{const result=api.setVisibility(localStorage,undo.scope,undo.id,false,{});notice.textContent=result.persistent?"Ausblendung lokal aufgehoben.":"Ausblendung konnte nicht lokal gespeichert werden.";if(result.persistent)rerender()});notice.append(document.createTextNode(" "),button)}};const option=(value,label)=>{const item=document.createElement("option");item.value=value;item.textContent=label;return item},reasonControl=()=>{const label=document.createElement("label"),select=document.createElement("select"),text=document.createElement("input");label.textContent="Grund";label.dataset.jobVisibilityReason="true";select.setAttribute("aria-label","Ausblendgrund");[["","Keine Angabe"],["ROLE","Rolle"],["LOCATION","Ort"],["CONDITIONS","Arbeitsbedingungen"],["EMPLOYER","Arbeitgeber"],["OTHER","Sonstiges"]].forEach(entry=>select.append(option(entry[0],entry[1])));text.type="text";text.maxLength=500;text.placeholder="Erlaeuterung (optional)";text.setAttribute("aria-label","Erlaeuterung zur Ausblendung");text.dataset.jobVisibilityText="true";label.append(select);return{label,text,options:()=>({reason:select.value,text:text.value})}},decorateJob=card=>{if(card.dataset.visibilityDecorated==="true")return;const job=jobs.get(card.dataset.jobId);if(!job)return;clear(card);card.dataset.visibilityDecorated="true";const state=read(),status=visible(job,state),local=state.hidden_jobs[job.job_id],actions=card.querySelector(".job-card-actions")||card,button=document.createElement("button");button.type="button";button.dataset.jobVisibility="job";button.textContent=local&&local.hidden?"Stelle wieder einblenden":"Nicht interessant";let controls=null;if(!(local&&local.hidden)){controls=reasonControl();actions.append(controls.label,controls.text)}button.addEventListener("click",()=>{const current=read(),now=visible(job,current),localEntry=current.hidden_jobs[job.job_id],hidden=!(localEntry&&localEntry.hidden);const result=api.setVisibility(localStorage,"job",job.job_id,hidden,hidden?controls.options():{});if(!result.persistent){announce("Ausblendung konnte nicht lokal gespeichert werden.");return}announce(hidden?"Stelle lokal ausgeblendet.":now.company_hidden?"Stelle einzeln eingeblendet; Arbeitgeber bleibt ausgeblendet.":"Stelle lokal eingeblendet.",hidden?{scope:"job",id:job.job_id}:null);rerender()});actions.append(button);if(status.hidden){const badge=document.createElement("p");badge.className="unknown job-visibility-badge";badge.textContent=status.scope==="company"?"Durch ausgeblendeten Arbeitgeber verborgen.":"Persoenlich ausgeblendet.";card.insertBefore(badge,actions)}},decorateCompany=card=>{if(card.dataset.visibilityDecorated==="true")return;const companyId=card.dataset.companyId;if(!companyId)return;clear(card);card.dataset.visibilityDecorated="true";const state=read(),entry=state.hidden_companies[companyId],companyJobs=(data.jobs||[]).filter(job=>job.company_id===companyId),hiddenCount=companyJobs.filter(job=>visible(job,state).hidden).length,summary=document.createElement("p"),button=document.createElement("button");summary.className="unknown company-visibility-summary";summary.textContent=(entry&&entry.hidden?"Arbeitgeber persoenlich ausgeblendet. ":"")+companyJobs.length+" offene Stellen erfasst, "+hiddenCount+" persoenlich ausgeblendet.";button.type="button";button.dataset.companyVisibility="company";button.textContent=entry&&entry.hidden?"Arbeitgeber wieder einblenden":"Stellen dieses Arbeitgebers ausblenden";let controls=null;if(!(entry&&entry.hidden)){controls=reasonControl();card.append(controls.label,controls.text)}button.addEventListener("click",()=>{const current=read(),localEntry=current.hidden_companies[companyId],hidden=!(localEntry&&localEntry.hidden);const result=api.setVisibility(localStorage,"company",companyId,hidden,hidden?controls.options():{});if(!result.persistent){announce("Ausblendung konnte nicht lokal gespeichert werden.");return}announce(hidden?"Arbeitgeber und seine Stellen lokal ausgeblendet.":"Arbeitgeber lokal eingeblendet.",hidden?{scope:"company",id:companyId}:null);rerender()});card.append(summary,button)},decorate=()=>{document.querySelectorAll(".job-card[data-job-id],.job-detail[data-job-id]").forEach(decorateJob);document.querySelectorAll("#jobagent-company-results [data-company-id]").forEach(decorateCompany)};new MutationObserver(decorate).observe(search,{childList:true,subtree:true});window.addEventListener("storage",decorate);decorate()}());</script>')
    [void]$Lines.Add('<script>(function(){const dataNode=document.getElementById("jobagent-search-data"),api=window.JobAgentUserState,count=document.getElementById("jobagent-result-count"),root=document.getElementById("jobagent-job-results");if(!dataNode||!api||!count||!root)return;let data;try{data=JSON.parse(dataNode.textContent)}catch{return}const normalize=value=>String(value||"").normalize("NFD").replace(/[\\u0300-\\u036f]/g,"").toLocaleLowerCase("de-DE").replace(/[^\\p{L}\\p{N}]+/gu," ").trim(),selected=(params,key)=>String(params.get(key)||"").split(",").filter(Boolean),includesAny=(values,candidates)=>!values.length||candidates.some(candidate=>values.includes(candidate)),ageMatches=(job,age)=>{if(!age)return true;const days=Number(job.age_days);return Number.isFinite(days)?(age==="older"?days>30:days<=Number(age)):age==="UNKNOWN"},state=()=>{try{const loaded=api.read(localStorage);return loaded.persistent?loaded.state:api.createEmptyState()}catch{return api.createEmptyState()}},mode=params=>["visible","all","hidden"].includes(params.get("visibility"))?params.get("visibility"):"visible",records=current=>current.jobs||{},matches=(job,params,current)=>{const tokens=normalize(params.get("q")).split(" ").filter(Boolean),record=records(current)[job.job_id]||{},haystack=normalize([job.title,job.company,job.job_category,job.description,...(job.requirements||[])].join(" ")),applied=params.get("applied")||"all";return tokens.every(token=>haystack.includes(token))&&includesAny(selected(params,"company"),[job.company_id])&&includesAny(selected(params,"category"),[job.job_category||"UNKNOWN"])&&includesAny(selected(params,"area"),job.area_facets||[job.target_area])&&includesAny(selected(params,"workModel"),[job.work_model])&&includesAny(selected(params,"employmentType"),[job.employment_type])&&includesAny(selected(params,"workTime"),[job.work_time])&&ageMatches(job,params.get("age")||"")&&(params.get("favorite")!=="1"||record.favorite===true)&&(applied==="all"||(applied==="beworben"?record.applied===true:record.applied!==true))},hidden=(job,current)=>api.visibilityFor(current,job.job_id,job.company_id).hidden,render=()=>{const params=new URLSearchParams(location.hash.slice(1));if(params.get("view")==="companies"||params.get("job"))return;const current=state(),matching=data.jobs.filter(job=>matches(job,params,current)),excluded=matching.filter(job=>hidden(job,current)&&!(records(current)[job.job_id]||{}).favorite&&!(records(current)[job.job_id]||{}).applied),shown=matching.length-excluded.length,base=count.textContent.replace(/\\s+\\d+ sichtbare Treffer, \\d+ durch Ausblendung ausgeschlossen\\.$/,"");count.textContent=base+" "+shown+" sichtbare Treffer, "+excluded.length+" durch Ausblendung ausgeschlossen.";if(mode(params)!=="hidden")return;const entries=[...Object.entries(current.hidden_jobs||{}).filter(([,entry])=>entry.hidden).map(([id,entry])=>({scope:"job",id,entry,label:(data.jobs.find(job=>job.job_id===id)||{}).title||id})),...Object.entries(current.hidden_companies||{}).filter(([,entry])=>entry.hidden).map(([id,entry])=>({scope:"company",id,entry,label:(data.companies.find(company=>company.company_id===id)||{}).company||id}))],key=JSON.stringify(entries.map(item=>[item.scope,item.id,item.entry.updated_at]));let panel=root.querySelector("#jobagent-visibility-management");if(panel&&panel.dataset.key===key)return;if(panel)panel.remove();panel=document.createElement("section");panel.id="jobagent-visibility-management";panel.dataset.key=key;const heading=document.createElement("h3");heading.textContent="Ausblendungen verwalten";panel.append(heading);if(!entries.length){const empty=document.createElement("p");empty.textContent="Keine lokalen Ausblendungen gespeichert.";panel.append(empty)}entries.forEach(item=>{const row=document.createElement("article"),description=document.createElement("p"),button=document.createElement("button");description.textContent=(item.scope==="job"?"Stelle: ":"Arbeitgeber: ")+item.label+" · Grund: "+(item.entry.reason||"Keine Angabe")+(item.entry.text?" · "+item.entry.text:"");button.type="button";button.textContent=item.scope==="job"?"Stelle wieder einblenden":"Arbeitgeber wieder einblenden";button.addEventListener("click",()=>{const result=api.setVisibility(localStorage,item.scope,item.id,false,{});if(result.persistent)window.dispatchEvent(new HashChangeEvent("hashchange"))});row.append(description,button);panel.append(row)});root.prepend(panel)};new MutationObserver(render).observe(root,{childList:true});window.addEventListener("hashchange",()=>setTimeout(render,0));window.addEventListener("storage",render);render()}());</script>')
    [void]$Lines.Add('<script>(function(){const count=document.getElementById("jobagent-result-count"),root=document.getElementById("jobagent-job-results");if(!count||!root)return;const tidy=()=>{count.textContent=count.textContent.replace(/(\\s+\\d+ sichtbare Treffer, \\d+ durch Ausblendung ausgeschlossen\\.)(?:\\s+\\d+ sichtbare Treffer, \\d+ durch Ausblendung ausgeschlossen\\.)+$/, "$1")};new MutationObserver(tidy).observe(root,{childList:true});tidy()}());</script>')
    [void]$Lines.Add('<script>(function(){const count=document.getElementById("jobagent-result-count"),root=document.getElementById("jobagent-job-results");if(!count||!root)return;const tidy=()=>{count.textContent=count.textContent.replace(/(\s+\d+ sichtbare Treffer, \d+ durch Ausblendung ausgeschlossen\.)(?:\s+\d+ sichtbare Treffer, \d+ durch Ausblendung ausgeschlossen\.)+$/, "$1")};new MutationObserver(tidy).observe(root,{childList:true});tidy()}());</script>')
    [void]$Lines.Add('<script>(function(){const count=document.getElementById("jobagent-result-count");if(!count)return;const tidy=()=>{const next=count.textContent.replace(/(\s+\d+ sichtbare Treffer, \d+ durch Ausblendung ausgeschlossen\.)(?:\s+\d+ sichtbare Treffer, \d+ durch Ausblendung ausgeschlossen\.)+$/, "$1");if(next!==count.textContent)count.textContent=next};new MutationObserver(tidy).observe(count,{childList:true,characterData:true,subtree:true});tidy()}());</script>')
    [void]$Lines.Add('<script>(function(){const limit=section=>{if(section.dataset.historyLimited)return;const entries=Array.from(section.children).filter(node=>node.tagName==="DETAILS");if(entries.length<=20){section.dataset.historyLimited="true";return}section.dataset.historyLimited="true";entries.slice(20).forEach(node=>node.hidden=true);const more=document.createElement("button");more.type="button";more.textContent="Weitere Aenderungen ("+(entries.length-20)+")";more.addEventListener("click",()=>{entries.slice(20).forEach(node=>node.hidden=false);more.remove()});section.append(more)};const root=document.getElementById("jobagent-job-results");if(!root)return;new MutationObserver(()=>root.querySelectorAll(".job-change-history").forEach(limit)).observe(root,{childList:true,subtree:true});root.querySelectorAll(".job-change-history").forEach(limit)}());</script>')
    [void]$Lines.Add('<script>(function(){const dataNode=document.getElementById("jobagent-search-data");if(!dataNode)return;let jobs={};try{jobs=Object.fromEntries(JSON.parse(dataNode.textContent).jobs.map(job=>[job.job_id,job]))}catch{return}const renderHistory=card=>{if(card.querySelector(".job-change-history"))return;const job=jobs[card.dataset.jobId],history=job&&job.change_history||[];const section=document.createElement("section"),heading=document.createElement("h3");section.className="job-change-history";heading.textContent="Quellenchronik";section.append(heading);if(!history.length){const empty=document.createElement("p");empty.textContent="Keine belegten Inhaltsaenderungen archiviert.";section.append(empty)}history.forEach(entry=>{const details=document.createElement("details"),summary=document.createElement("summary"),meta=document.createElement("p");summary.textContent=entry.label+": Aenderung erkannt am "+entry.observed_at;meta.textContent="Lauf: "+entry.scan_run_id+" · Quelle: "+entry.source_id;details.append(summary,meta);(entry.fields||[]).forEach(field=>{const text=document.createElement("p");text.textContent=field.field+" – Vorher: "+field.before+" · Nachher: "+field.after;details.append(text)});section.append(details)});const links=card.querySelector(".job-card-links");card.insertBefore(section,links)};new MutationObserver(()=>document.querySelectorAll(".job-detail[data-job-id]").forEach(renderHistory)).observe(document.getElementById("jobagent-job-results"),{childList:true,subtree:true});document.querySelectorAll(".job-detail[data-job-id]").forEach(renderHistory)}());</script>')
    [void]$Lines.Add('<script>(function(){const panel=document.getElementById("jobagent-applications"),tab=document.getElementById("jobagent-tab-applications");if(!panel||!tab)return;["jobagent-tab-jobs","jobagent-tab-companies"].forEach(id=>{const button=document.getElementById(id);if(button)button.addEventListener("click",()=>{panel.hidden=true;tab.setAttribute("aria-selected","false")})})}());</script>')
    [void]$Lines.Add('<script>(function(){const tab=document.getElementById("jobagent-tab-applications"),panel=document.getElementById("jobagent-applications"),jobsPanel=document.getElementById("jobagent-jobs"),companiesPanel=document.getElementById("jobagent-companies"),count=document.getElementById("jobagent-result-count"),pagination=document.getElementById("jobagent-pagination"),dataNode=document.getElementById("jobagent-search-data"),form=document.getElementById("jobagent-application-filters");if(!tab||!panel||!dataNode||!form)return;const labels={PREPARING:"Vorbereiten",APPLIED:"Beworben",INTERVIEW:"Gespraech",REJECTED:"Absage",WITHDRAWN:"Zurueckgezogen"},query=document.getElementById("jobagent-application-query"),stage=document.getElementById("jobagent-application-stage"),due=document.getElementById("jobagent-application-due"),sort=document.getElementById("jobagent-application-sort"),today=reference=>String(reference||"").slice(0,10),openTasks=record=>(record.tasks||[]).filter(task=>task.deleted_at===null&&task.status==="OPEN").sort((a,b)=>a.local_date.localeCompare(b.local_date)||a.task_id.localeCompare(b.task_id)),matches=entry=>{const tasks=openTasks(entry.record),first=tasks[0],needle=String(query.value||"").normalize("NFD").replace(/[\\u0300-\\u036f]/g,"").toLocaleLowerCase("de-DE").trim(),haystack=[entry.job.title,entry.job.company,entry.record.note,entry.record.next_action].join(" ").normalize("NFD").replace(/[\\u0300-\\u036f]/g,"").toLocaleLowerCase("de-DE"),reference=today(entry.reference),limit=new Date(reference+"T00:00:00Z");limit.setUTCDate(limit.getUTCDate()+7);const dueMatches=due.value==="all"||(due.value==="open"&&tasks.length>0)||(due.value==="none"&&tasks.length===0)||(due.value==="overdue"&&first&&first.local_date<reference)||(due.value==="next_7"&&first&&first.local_date>=reference&&first.local_date<=limit.toISOString().slice(0,10));return(stage.value==="all"||entry.record.application_stage===stage.value)&&(!needle||haystack.includes(needle))&&dueMatches},compare=(left,right)=>{const leftTask=openTasks(left.record)[0],rightTask=openTasks(right.record)[0],byId=()=>left.job.job_id.localeCompare(right.job.job_id,"de");if(sort.value==="job_id")return byId();if(sort.value==="stage_then_id")return labels[left.record.application_stage].localeCompare(labels[right.record.application_stage],"de")||byId();return String(leftTask&&leftTask.local_date||"9999-12-31").localeCompare(String(rightTask&&rightTask.local_date||"9999-12-31"))||String(leftTask&&leftTask.task_id||"~").localeCompare(String(rightTask&&rightTask.task_id||"~"),"de")||byId()},render=()=>{let data,records={};try{data=JSON.parse(dataNode.textContent);const loaded=window.JobAgentUserState.read(window.localStorage);records=loaded.persistent?loaded.state.jobs:{}}catch{return}const known=new Map((data.jobs||[]).map(job=>[job.job_id,job])),entries=Object.entries(records).filter(([,record])=>record&&labels[record.application_stage]).map(([id,record])=>({job:known.get(id)||{job_id:id,title:record.reference&&record.reference.title||"Lokale Stellenreferenz",company:record.reference&&record.reference.company||"Keine Angabe"},record,reference:data.reference_time})).filter(matches).sort(compare),root=document.getElementById("jobagent-application-results");root.replaceChildren(...entries.map(entry=>{const card=document.createElement("article"),heading=document.createElement("h3"),status=document.createElement("p"),next=document.createElement("p"),note=document.createElement("p"),tasks=document.createElement("ul"),open=openTasks(entry.record);card.className="result-card application-card";card.dataset.jobId=entry.job.job_id;heading.textContent=entry.job.title+" · "+entry.job.company;status.textContent="Status: "+labels[entry.record.application_stage];next.textContent=entry.record.next_action?"Naechste Aktion: "+entry.record.next_action:"Keine naechste Aktion gespeichert.";note.textContent=entry.record.note?"Notiz: "+entry.record.note:"Keine Notiz gespeichert.";open.forEach(task=>{const item=document.createElement("li");item.textContent="Offen: "+task.local_date+(task.time_with_offset?" "+task.time_with_offset:"")+" · "+task.title;tasks.append(item)});if(!tasks.childElementCount){const item=document.createElement("li");item.textContent="Keine offenen Termine.";tasks.append(item)}card.append(heading,status,next,note,tasks);return card}));if(!entries.length){const empty=document.createElement("p");empty.className="empty-state";empty.textContent="Keine Bewerbungen fuer diese lokalen Filter.";root.append(empty)}count.textContent="Bewerbungen: "+entries.length+" Treffer.";pagination.replaceChildren()};tab.addEventListener("click",event=>{event.stopImmediatePropagation();event.preventDefault();jobsPanel.hidden=true;companiesPanel.hidden=true;panel.hidden=false;document.getElementById("jobagent-tab-jobs").setAttribute("aria-selected","false");document.getElementById("jobagent-tab-companies").setAttribute("aria-selected","false");tab.setAttribute("aria-selected","true");render()},{capture:true});form.addEventListener("input",render);form.addEventListener("change",render);form.addEventListener("reset",()=>setTimeout(render,0));window.addEventListener("storage",()=>{if(!panel.hidden)render()})}());</script></section>')
}

function Get-JobAgentReportUserStateScript {
    $assetPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\html\jobagent\assets\jobboard-state.js'))
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "JobAgent UserState-Asset fehlt: $assetPath"
    }

    $script = [IO.File]::ReadAllText($assetPath)
    if ($script -match '(?i)</script') {
        throw 'JobAgent UserState-Asset enthaelt einen unzulaessigen Script-Abschluss.'
    }
    return $script
}

function Get-JobAgentReportCalendarScript {
    $assetPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\html\jobagent\assets\jobboard-calendar.js'))
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "JobAgent Kalender-Asset fehlt: $assetPath"
    }
    $script = [IO.File]::ReadAllText($assetPath)
    if ($script -match '(?i)</script') {
        throw 'JobAgent Kalender-Asset enthaelt einen unzulaessigen Script-Abschluss.'
    }
    return $script
}

function Get-JobAgentReportSavedSearchScript {
    $assetPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\html\jobagent\assets\jobboard-saved-searches.js'))
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "JobAgent Suchauftrags-Asset fehlt: $assetPath"
    }

    $script = [IO.File]::ReadAllText($assetPath)
    if ($script -match '(?i)</script') {
        throw 'JobAgent Suchauftrags-Asset enthaelt einen unzulaessigen Script-Abschluss.'
    }
    return $script
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
    [void]$lines.Add('<title>Stellenangebote | JobAgent</title>')
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
    [void]$lines.Add('.eyebrow { margin: 0 0 4px; color: var(--muted); font-size: 0.85rem; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; } .jobboard h1 { margin-bottom: 4px; } .jobboard-reference { margin-top: 0; color: var(--muted); }')
    [void]$lines.Add('.jobboard-layout { display: grid; grid-template-columns: 280px minmax(0, 1fr); gap: 20px; align-items: start; } .filter-region { min-width: 0; border: 1px solid var(--line); border-radius: 12px; padding: 12px; background: var(--surface-alt); } .filter-region summary { cursor: pointer; min-height: 28px; font-weight: 700; } .filter-region[open] summary { margin-bottom: 12px; }')
    [void]$lines.Add('.filters { display: grid; gap: 12px; align-items: end; }')
    [void]$lines.Add('.filters label { display: grid; gap: 5px; font-weight: 600; }')
    [void]$lines.Add('input, select, button { font: inherit; min-width: 44px; min-height: 44px; border: 1px solid var(--line); border-radius: 8px; padding: 8px; background: var(--surface); color: var(--text); }')
    [void]$lines.Add('select[multiple] { min-height: 116px; } button { cursor: pointer; font-weight: 600; } button:focus-visible, input:focus-visible, select:focus-visible, a:focus-visible { outline: 3px solid #1d70b8; outline-offset: 2px; }')
    [void]$lines.Add('.search-tabs, .pagination { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0; } .search-tabs button[aria-selected="true"] { background: var(--accent); color: #fff; } .result-count { margin-top: 0; font-weight: 600; }')
    [void]$lines.Add('.saved-searches { margin: 16px 0; border: 1px solid var(--line); border-radius: 12px; padding: 14px; background: var(--surface); } .saved-searches > label { display: grid; gap: 5px; margin: 10px 0; font-weight: 600; } .saved-searches > button { margin: 0 8px 8px 0; } .saved-search-card h3 { margin-top: 0; } .saved-search-result-label { color: var(--ok); font-weight: 700; }')
    [void]$lines.Add('.calendar-controls, .calendar-filters { display: flex; flex-wrap: wrap; gap: 8px; align-items: end; margin: 12px 0; } .calendar-controls label, .calendar-filters label { display: grid; gap: 4px; font-weight: 600; } .calendar-grid { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 6px; } .calendar-weekday { color: var(--muted); font-weight: 700; text-align: center; padding: 6px; } .calendar-day { min-height: 120px; padding: 8px; text-align: left; overflow-wrap: anywhere; } .calendar-day.is-outside { opacity: .62; } .calendar-day[aria-current="date"] { outline: 3px solid var(--accent); outline-offset: 1px; } .calendar-day.is-selected { background: var(--accent); color: #fff; } .calendar-day .calendar-count { display: block; margin-top: 8px; font-size: .84rem; } .calendar-legend { display: flex; flex-wrap: wrap; gap: 10px; } .calendar-legend span::before { content: ""; display: inline-block; width: .8rem; height: .8rem; margin-right: .3rem; border-radius: 50%; background: var(--muted); } .calendar-legend .calendar-plan::before { border: 2px dashed var(--warn); background: transparent; border-radius: 0; } .calendar-legend .calendar-task::before { background: var(--ok); } .calendar-event { border-left: 4px solid var(--accent); padding-left: 10px; margin: 10px 0; } .calendar-event.calendar-plan { border-left-style: dashed; border-left-color: var(--warn); } .calendar-event.calendar-task { border-left-color: var(--ok); } .calendar-agenda { display: grid; gap: 10px; } @media (max-width: 800px) { .calendar-grid { display: none; } .calendar-weekday { display: none; } .calendar-agenda { display: grid; } } @media (min-width: 801px) { .calendar-agenda { display: none; } }')
    [void]$lines.Add('.result-list { display: grid; gap: 12px; } .result-card { border: 1px solid var(--line); border-radius: 10px; padding: 14px; background: var(--surface-alt); overflow-wrap: anywhere; } .result-card h3, .result-card p { margin: 0 0 8px; } .job-card h3 { color: var(--accent); font-size: clamp(1.2rem, 2.2vw, 1.5rem); } .job-detail-open { color: inherit; font: inherit; font-weight: inherit; text-align: start; background: none; border: 0; padding: 0; } .job-card-meta { font-weight: 600; } .job-card-date, .job-card-description { color: var(--muted); } .job-card-links { margin-bottom: 0; } .job-card-actions { display: flex; flex-wrap: wrap; gap: 8px; } .job-mark { min-width: 44px; min-height: 44px; } .job-mark[aria-pressed="true"] { font-weight: 700; } .job-mark-message { min-height: 1.25em; color: var(--muted); } .historical-job-heading { margin: 20px 0 0; } .historical-job-card { border-style: dashed; } .historical-job-status { font-weight: 700; } .job-detail dl { display: grid; grid-template-columns: minmax(9rem, max-content) 1fr; gap: 6px 14px; } .job-detail dt { font-weight: 700; } .job-detail dd { margin: 0; } .job-detail-open:focus-visible, .job-mark:focus-visible, .job-detail button:focus-visible { outline: 3px solid var(--accent); outline-offset: 3px; } .empty-state { border: 1px dashed var(--line); border-radius: 10px; padding: 16px; color: var(--muted); } .no-js-notice { color: var(--muted); font-size: 0.9rem; }')
    [void]$lines.Add('@media (max-width: 1023px) { .jobboard-layout { grid-template-columns: 1fr; } .filter-region { width: 100%; } .filters { grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); } } @media (max-width: 800px) { main { padding: 16px 12px 28px; } section { padding: 12px; } table { min-width: 640px; } .job-table { min-width: 1360px; } th, td { padding: 9px 10px; } }')
    [void]$lines.Add('</style>')
    [void]$lines.Add('</head>')
    [void]$lines.Add('<body>')
    [void]$lines.Add('<main>')
    Add-JobAgentReportSearchInterfaceHtml -Lines $lines -Report $Report

    [void]$lines.Add('<section id="jobagent-data-status">')
    [void]$lines.Add('<h2>Datenstand und Quellen</h2>')
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
    'Get-JobAgentReportChangeHistory',
    'New-JobAgentDailyReport'
)
