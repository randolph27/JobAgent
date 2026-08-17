#requires -Version 7.4

Set-StrictMode -Version 3.0

function Get-JobAgentCoverageProperty {
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

function ConvertTo-JobAgentCoverageDate {
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

function Test-JobAgentCoverageMatchingJob {
    param([Parameter(Mandatory)][object]$Job)

    $classification = Get-JobAgentCoverageProperty -Object $Job -Name 'classification'
    $result = [string](Get-JobAgentCoverageProperty -Object $classification -Name 'result' -Default 'UNKNOWN')
    return @('MATCH', 'POSSIBLE') -contains $result
}

function Get-JobAgentCoverageLatestAttemptMap {
    param([Parameter(Mandatory)][object]$Document)

    $map = @{}
    foreach ($attempt in @($Document.scan_attempts)) {
        $companyId = [string](Get-JobAgentCoverageProperty -Object $attempt -Name 'company_id' -Default '')
        if ([string]::IsNullOrWhiteSpace($companyId)) {
            continue
        }
        $startedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $attempt -Name 'started_at')
        if (-not $map.ContainsKey($companyId)) {
            $map[$companyId] = $attempt
            continue
        }
        $currentStartedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $map[$companyId] -Name 'started_at')
        if ($null -eq $currentStartedAt -or ($null -ne $startedAt -and $startedAt -gt $currentStartedAt)) {
            $map[$companyId] = $attempt
        }
    }
    return $map
}

function Get-JobAgentCoverageJobsByCompany {
    param([Parameter(Mandatory)][object]$Document)

    $map = @{}
    foreach ($job in @($Document.jobs)) {
        $companyId = [string](Get-JobAgentCoverageProperty -Object $job -Name 'company_id' -Default '')
        if ([string]::IsNullOrWhiteSpace($companyId)) {
            continue
        }
        if (-not $map.ContainsKey($companyId)) {
            $map[$companyId] = [System.Collections.Generic.List[object]]::new()
        }
        $map[$companyId].Add($job)
    }
    return $map
}

function Get-JobAgentCoverageCompanyMetric {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowNull()][object]$LatestAttempt,
        [Parameter()][AllowEmptyCollection()][object[]]$Jobs = @(),
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7
    )

    $companyId = [string]$Company.company_id
    $lastSuccessfulScanAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'last_successful_scan_at')
    $latestAttemptStatus = [string](Get-JobAgentCoverageProperty -Object $LatestAttempt -Name 'status' -Default 'NEVER_SCANNED')
    $latestErrorClass = [string](Get-JobAgentCoverageProperty -Object $LatestAttempt -Name 'error_class' -Default 'NONE')
    $hasCareerUrl = -not [string]::IsNullOrWhiteSpace([string](Get-JobAgentCoverageProperty -Object $Company -Name 'career_url'))
    $hasMatchingJobs = @($Jobs | Where-Object { $null -ne $_ -and (Test-JobAgentCoverageMatchingJob -Job $_) }).Count -gt 0
    $wasScanned = $null -ne $LatestAttempt
    $latestScanFailed = $wasScanned -and $latestAttemptStatus -eq 'FAILED'
    $latestScanSucceeded = $wasScanned -and $latestAttemptStatus -eq 'SUCCESS'
    $isStale = $null -eq $lastSuccessfulScanAt -or $lastSuccessfulScanAt -lt $Now.ToUniversalTime().AddDays(-$StaleAfterDays)
    $ats = @((Get-JobAgentCoverageProperty -Object $Company -Name 'ats' -Default @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $verificationStatus = [string](Get-JobAgentCoverageProperty -Object $Company -Name 'verification_status' -Default 'UNVERIFIED')
    $discoverySource = Get-JobAgentCoverageProperty -Object $Company -Name 'discovery_source' -Default $null
    $discoveryType = [string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'type' -Default 'UNKNOWN')
    $discoveryOrigin = [string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'discovery_origin' -Default 'UNKNOWN')
    $targetArea = [string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'target_area' -Default 'UNKNOWN')
    $inventoryState = if (-not $hasCareerUrl -and $verificationStatus -eq 'CAREER_URL_VERIFIED') {
        'DATA_INCONSISTENT'
    }
    elseif (-not $hasCareerUrl -and $verificationStatus -eq 'COMPANY_DOMAIN_VERIFIED') {
        'VERIFIED_WEBSITE_ONLY'
    }
    elseif ($verificationStatus -eq 'UNVERIFIED' -or $discoveryType -in @('MANUAL_REVIEW', 'DISCOVERY_HINT')) {
        'MANUAL_REVIEW_REQUIRED'
    }
    elseif (-not $wasScanned) {
        'NEVER_SCANNED'
    }
    elseif ($latestScanFailed) {
        'RETRY_REQUIRED'
    }
    elseif ($isStale) {
        'STALE_SCAN'
    }
    else {
        'ACTIVE_ROTATION'
    }
    $nextStep = switch ($inventoryState) {
        'VERIFIED_WEBSITE_ONLY' { 'Offizielle Website erneut auf Karrierepfad pruefen und Quelle ergaenzen.' ; break }
        'MANUAL_REVIEW_REQUIRED' { 'Discovery-Hinweis gegen offizielle Unternehmensquelle verifizieren.' ; break }
        'NEVER_SCANNED' { 'Offizielle Quelle in den naechsten Daily-Run aufnehmen.' ; break }
        'RETRY_REQUIRED' { 'Fehlerklasse pruefen und Quelle gezielt erneut scannen.' ; break }
        'STALE_SCAN' { 'Firma in die planmaessige Rotationspruefung aufnehmen.' ; break }
        default { 'In der regulaeren Rotation belassen.' }
    }

    [pscustomobject]@{
        company_id = $companyId
        company = [string](Get-JobAgentCoverageProperty -Object $Company -Name 'canonical_name' -Default $companyId)
        has_career_url = $hasCareerUrl
        was_scanned = $wasScanned
        latest_scan_succeeded = $latestScanSucceeded
        latest_scan_failed = $latestScanFailed
        latest_error_class = $latestErrorClass
        has_matching_jobs = $hasMatchingJobs
        last_successful_scan_at = if ($null -eq $lastSuccessfulScanAt) { $null } else { $lastSuccessfulScanAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture) }
        is_stale = $isStale
        ats_known = $ats.Count -gt 0
        scan_priority = [int](Get-JobAgentCoverageProperty -Object $Company -Name 'scan_priority' -Default 0)
        verification_status = $verificationStatus
        discovery_type = $discoveryType
        discovery_origin = $discoveryOrigin
        target_area = $targetArea
        inventory_state = $inventoryState
        next_step = $nextStep
    }
}

function New-JobAgentCoverageBacklogItem {
    param(
        [Parameter(Mandatory)][object]$Metric,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$NextStep,
        [Parameter(Mandatory)][int]$Score
    )

    [pscustomobject]@{
        company_id = [string]$Metric.company_id
        company = [string]$Metric.company
        kind = $Kind
        reason = $Reason
        next_step = $NextStep
        priority_score = $Score
    }
}

function Get-JobAgentCoverageBacklog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CompanyMetrics
    )

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($metric in @($CompanyMetrics)) {
        if ([string]$metric.inventory_state -eq 'MANUAL_REVIEW_REQUIRED') {
            $items.Add((New-JobAgentCoverageBacklogItem -Metric $metric -Kind 'MANUAL_REVIEW_DISCOVERY' -Reason ('Discovery-Quelle ist noch nicht als offizielle Firmenquelle verifiziert: ' + [string]$metric.discovery_type + '.') -NextStep 'Offizielle Unternehmenswebsite oder Karriere-URL als Primärbeleg dokumentieren.' -Score 98))
            continue
        }
        if (-not [bool]$metric.has_career_url) {
            $items.Add((New-JobAgentCoverageBacklogItem -Metric $metric -Kind 'CAREER_URL_DISCOVERY' -Reason 'Keine Karriere-URL im Firmeninventar.' -NextStep 'Offizielle Unternehmenswebsite auf Karrierepfad pruefen und verifizieren.' -Score 95))
            continue
        }
        if ([bool]$metric.latest_scan_failed) {
            $kind = if (-not [bool]$metric.ats_known) { 'ATS_OR_PORTAL_ADAPTER_REVIEW' } else { 'RETRY_LANE_REVIEW' }
            $items.Add((New-JobAgentCoverageBacklogItem -Metric $metric -Kind $kind -Reason ('Letzter Scan fehlgeschlagen: ' + [string]$metric.latest_error_class + '.') -NextStep 'Fehlerklasse, Portaltyp und moeglichen Adapterbedarf mit offizieller Quelle pruefen.' -Score 90))
            continue
        }
        if ([bool]$metric.is_stale) {
            $items.Add((New-JobAgentCoverageBacklogItem -Metric $metric -Kind 'STALE_SCAN_ROTATION' -Reason 'Firma wurde noch nie oder lange nicht erfolgreich gescannt.' -NextStep 'Firma in naechsten Daily-Run aufnehmen und Ergebnis protokollieren.' -Score 70))
            continue
        }
        if ([bool]$metric.latest_scan_succeeded -and -not [bool]$metric.has_matching_jobs) {
            $items.Add((New-JobAgentCoverageBacklogItem -Metric $metric -Kind 'NO_MATCH_RECHECK' -Reason 'Letzter Scan erfolgreich, aber ohne passende Stelle.' -NextStep 'In Rotation belassen; keine Vollstaendigkeit behaupten.' -Score 35))
        }
    }

    return @($items.ToArray() | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, company)
}

function Get-JobAgentCoverageScanPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CompanyMetrics,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25
    )

    $items = foreach ($metric in @($CompanyMetrics)) {
        $score = [int]$metric.scan_priority
        $reasons = [System.Collections.Generic.List[string]]::new()
        if (-not [bool]$metric.has_career_url) {
            $score += 50
            $reasons.Add('career_url_missing')
        }
        if ([string]$metric.inventory_state -eq 'MANUAL_REVIEW_REQUIRED') {
            $score += 40
            $reasons.Add('manual_review_source')
        }
        if (-not [bool]$metric.was_scanned) {
            $score += 45
            $reasons.Add('never_scanned')
        }
        elseif ([bool]$metric.latest_scan_failed) {
            $score += 35
            $reasons.Add('last_scan_failed')
        }
        elseif ([bool]$metric.is_stale) {
            $score += 30
            $reasons.Add('stale_scan')
        }
        else {
            $score -= 25
            $reasons.Add('recent_success_rotation_penalty')
        }
        if ([bool]$metric.has_matching_jobs) {
            $score -= 10
            $reasons.Add('matching_job_already_known')
        }

        [pscustomobject]@{
            company_id = [string]$metric.company_id
            company = [string]$metric.company
            priority_score = $score
            reasons = @($reasons.ToArray())
            next_action = if ([string]$metric.inventory_state -eq 'MANUAL_REVIEW_REQUIRED') { 'verify_discovery_hint' } elseif (-not [bool]$metric.has_career_url) { 'discover_career_url' } elseif ([bool]$metric.latest_scan_failed) { 'retry_or_adapter_review' } else { 'scan_rotation' }
        }
    }

    return @($items | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, company | Select-Object -First $MaxCompanies)
}

function New-JobAgentCoverageReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxPriorityItems = 25
    )

    $latestAttempts = Get-JobAgentCoverageLatestAttemptMap -Document $Document
    $jobsByCompany = Get-JobAgentCoverageJobsByCompany -Document $Document
    $metrics = foreach ($company in @($Document.companies)) {
        $companyId = [string]$company.company_id
        $latestAttempt = if ($latestAttempts.ContainsKey($companyId)) { $latestAttempts[$companyId] } else { $null }
        $jobs = if ($jobsByCompany.ContainsKey($companyId)) { @($jobsByCompany[$companyId].ToArray()) } else { @() }
        Get-JobAgentCoverageCompanyMetric -Company $company -LatestAttempt $latestAttempt -Jobs $jobs -Now $Now -StaleAfterDays $StaleAfterDays
    }

    $metricsArray = @($metrics)
    [pscustomobject]@{
        generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        stale_after_days = $StaleAfterDays
        approximation_notice = 'Coverage-Werte sind operative Naeherungen aus dem lokalen Firmeninventar und behaupten keine vollstaendige Marktdeckung.'
        metrics = [pscustomobject]@{
            companies_total = $metricsArray.Count
            with_career_url = @($metricsArray | Where-Object has_career_url).Count
            without_career_url = @($metricsArray | Where-Object { -not [bool]$_.has_career_url }).Count
            successfully_scanned = @($metricsArray | Where-Object latest_scan_succeeded).Count
            failed_scanned = @($metricsArray | Where-Object latest_scan_failed).Count
            never_scanned = @($metricsArray | Where-Object { -not [bool]$_.was_scanned }).Count
            without_matching_jobs = @($metricsArray | Where-Object { [bool]$_.latest_scan_succeeded -and -not [bool]$_.has_matching_jobs }).Count
            with_matching_jobs = @($metricsArray | Where-Object has_matching_jobs).Count
            stale_or_unscanned = @($metricsArray | Where-Object is_stale).Count
            manual_review_required = @($metricsArray | Where-Object { [string]$_.inventory_state -eq 'MANUAL_REVIEW_REQUIRED' }).Count
            verified_without_career_url = @($metricsArray | Where-Object { [string]$_.inventory_state -eq 'VERIFIED_WEBSITE_ONLY' }).Count
            retry_required = @($metricsArray | Where-Object { [string]$_.inventory_state -eq 'RETRY_REQUIRED' }).Count
        }
        companies = @($metricsArray | Sort-Object company)
        backlog = @(Get-JobAgentCoverageBacklog -CompanyMetrics $metricsArray)
        scan_priority = @(Get-JobAgentCoverageScanPriority -CompanyMetrics $metricsArray -MaxCompanies $MaxPriorityItems)
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentCoverageBacklog',
    'Get-JobAgentCoverageScanPriority',
    'New-JobAgentCoverageReport'
)
