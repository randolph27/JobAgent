#requires -Version 7.4

Set-StrictMode -Version 3.0

if ($null -eq (Get-Command -Name Resolve-JobAgentCompanyCandidateClusters -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'JobAgent.CompanyInventory.psm1') -DisableNameChecking
}

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

function ConvertTo-JobAgentCoverageNameKey {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return 'UNKNOWN'
    }
    $text = ([string]$Value).ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $text = [regex]::Replace($text, '\b(gmbh\s+and\s+co\.?\s+kg|gmbh\s+und\s+co\.?\s+kg|gmbh|ag|se|kg|kgaa|inc|ltd|llc)\b', ' ')
    $text = [regex]::Replace($text, '[^a-z0-9]+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return 'UNKNOWN'
    }
    return [regex]::Replace($text, '\s+', ' ')
}

function Add-JobAgentCoverageCount {
    param(
        [Parameter(Mandatory)][hashtable]$Counts,
        [Parameter()][AllowNull()][object]$Key
    )

    $name = if ($null -eq $Key -or [string]::IsNullOrWhiteSpace([string]$Key)) { 'UNKNOWN' } else { [string]$Key }
    if (-not $Counts.ContainsKey($name)) {
        $Counts[$name] = 0
    }
    $Counts[$name]++
}

function ConvertTo-JobAgentCoverageCountsObject {
    param([Parameter(Mandatory)][hashtable]$Counts)

    $ordered = [ordered]@{}
    foreach ($key in @($Counts.Keys | Sort-Object)) {
        $ordered[$key] = [int]$Counts[$key]
    }
    return [pscustomobject]$ordered
}

function New-JobAgentCoverageCandidateClusterDimensions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Clusters
    )

    $targetBasis = @{}
    $conflicts = @{}
    $reviewReasons = @{}
    foreach ($cluster in @($Clusters)) {
        foreach ($basis in @($cluster.target_area_basis)) {
            Add-JobAgentCoverageCount -Counts $targetBasis -Key $basis
        }
        foreach ($flag in @($cluster.conflict_flags)) {
            Add-JobAgentCoverageCount -Counts $conflicts -Key $flag
        }
        Add-JobAgentCoverageCount -Counts $reviewReasons -Key $cluster.review_queue_reason
    }

    [pscustomobject]@{
        by_target_area_basis = ConvertTo-JobAgentCoverageCountsObject -Counts $targetBasis
        by_conflict_flag = ConvertTo-JobAgentCoverageCountsObject -Counts $conflicts
        by_review_queue_reason = ConvertTo-JobAgentCoverageCountsObject -Counts $reviewReasons
    }
}

function New-JobAgentCoverageCandidateClusterReport {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxReviewItems = 25
    )

    if ($null -eq $HintStore) {
        return [pscustomobject]@{
            schema_version = 'jobagent/company-candidate-coverage/v1'
            generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            candidates_total = 0
            clusters_total = 0
            conflict_clusters = 0
            review_queue_total = 0
            dimensions = New-JobAgentCoverageCandidateClusterDimensions -Clusters @()
            review_queue = @()
            clusters = @()
        }
    }

    $clusterReport = Resolve-JobAgentCompanyCandidateClusters -Candidates @($HintStore.hints) -ObservedAt $Now
    $reviewQueue = @($clusterReport.clusters |
        Where-Object { [string]$_.review_queue_reason -ne 'READY_FOR_OFFICIAL_VERIFICATION' } |
        Sort-Object review_queue_reason, canonical_name |
        Select-Object -First $MaxReviewItems)

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-coverage/v1'
        generated_at = $clusterReport.generated_at
        candidates_total = $clusterReport.candidates_total
        clusters_total = $clusterReport.clusters_total
        conflict_clusters = $clusterReport.conflict_clusters
        review_queue_total = $clusterReport.review_queue_total
        dimensions = New-JobAgentCoverageCandidateClusterDimensions -Clusters @($clusterReport.clusters)
        review_queue = @($reviewQueue)
        clusters = @($clusterReport.clusters)
    }
}

function Get-JobAgentCoverageCompanyTargetAreas {
    param([Parameter(Mandatory)][object]$Company)

    $areas = @($Company.locations |
        Where-Object { $null -ne $_ } |
        ForEach-Object { Get-JobAgentCoverageProperty -Object $_ -Name 'target_area' -Default 'UNKNOWN' } |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique)
    if ($areas.Count -eq 0) {
        $discoverySource = Get-JobAgentCoverageProperty -Object $Company -Name 'discovery_source'
        $area = [string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'target_area' -Default 'UNKNOWN')
        return @($area)
    }
    return @($areas)
}

function Get-JobAgentCoverageCompanyLastReviewAt {
    param([Parameter(Mandatory)][object]$Company)

    foreach ($property in @('career_verification_reviewed_at', 'career_verification_checked_at', 'updated_at', 'created_at')) {
        $value = Get-JobAgentCoverageProperty -Object $Company -Name $property
        if ($null -ne (ConvertTo-JobAgentCoverageDate -Value $value)) {
            return (ConvertTo-JobAgentCoverageDate -Value $value).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return $null
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
    $targetAreas = @(Get-JobAgentCoverageCompanyTargetAreas -Company $Company)
    if ($targetAreas.Count -gt 0 -and $targetAreas[0] -ne 'UNKNOWN') {
        $targetArea = [string]$targetAreas[0]
    }
    $industry = [string](Get-JobAgentCoverageProperty -Object $Company -Name 'industry' -Default 'UNKNOWN')
    $lastReviewAt = Get-JobAgentCoverageCompanyLastReviewAt -Company $Company
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
        target_areas = @($targetAreas)
        industry = $industry
        last_review_at = $lastReviewAt
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

function Test-JobAgentCoverageImportableSource {
    param([Parameter(Mandatory)][object]$Source)

    $mode = [string](Get-JobAgentCoverageProperty -Object $Source -Name 'import_mode' -Default '')
    return @('TARGETED_LOOKUP_ONLY', 'BULK_SNAPSHOT', 'FIXTURE_OR_SNAPSHOT_ONLY') -contains $mode
}

function Test-JobAgentCoverageRejectedSource {
    param([Parameter(Mandatory)][object]$Source)

    return [string](Get-JobAgentCoverageProperty -Object $Source -Name 'source_class' -Default '') -eq 'REJECTED'
}

function Test-JobAgentCoverageManualReviewSource {
    param([Parameter(Mandatory)][object]$Source)

    $sourceClass = [string](Get-JobAgentCoverageProperty -Object $Source -Name 'source_class' -Default '')
    $mode = [string](Get-JobAgentCoverageProperty -Object $Source -Name 'import_mode' -Default '')
    $reviewRequired = [bool](Get-JobAgentCoverageProperty -Object $Source -Name 'review_required' -Default $false)
    return $sourceClass -eq 'MANUAL_REVIEW' -or $mode -eq 'MANUAL_REVIEW_ONLY' -or $reviewRequired
}

function Test-JobAgentCoverageSourceVerificationGap {
    param([Parameter(Mandatory)][object]$Source)

    if (Test-JobAgentCoverageRejectedSource -Source $Source) {
        return $false
    }
    $sourceClass = [string](Get-JobAgentCoverageProperty -Object $Source -Name 'source_class' -Default '')
    $evidenceLevel = [string](Get-JobAgentCoverageProperty -Object $Source -Name 'evidence_level' -Default '')
    $reviewRequired = [bool](Get-JobAgentCoverageProperty -Object $Source -Name 'review_required' -Default $true)
    return -not (@('OFFICIAL_COMPANY', 'OFFICIAL_ATS') -contains $sourceClass -and $evidenceLevel -eq 'PRIMARY_OFFICIAL' -and -not $reviewRequired)
}

function New-JobAgentDiscoverySourceCoverageReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SourceRegistry,
        [Parameter()][datetime]$Now = [datetime]::UtcNow
    )

    $items = @($SourceRegistry.items)
    $classCounts = [ordered]@{}
    $modeCounts = [ordered]@{}
    $evidenceCounts = [ordered]@{}
    foreach ($source in $items) {
        $sourceClass = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_class' -Default 'UNKNOWN')
        $mode = [string](Get-JobAgentCoverageProperty -Object $source -Name 'import_mode' -Default 'UNKNOWN')
        $evidenceLevel = [string](Get-JobAgentCoverageProperty -Object $source -Name 'evidence_level' -Default 'UNKNOWN')
        if (-not $classCounts.Contains($sourceClass)) {
            $classCounts[$sourceClass] = 0
        }
        if (-not $modeCounts.Contains($mode)) {
            $modeCounts[$mode] = 0
        }
        if (-not $evidenceCounts.Contains($evidenceLevel)) {
            $evidenceCounts[$evidenceLevel] = 0
        }
        $classCounts[$sourceClass]++
        $modeCounts[$mode]++
        $evidenceCounts[$evidenceLevel]++
    }

    $manualReviewSources = @($items | Where-Object { Test-JobAgentCoverageManualReviewSource -Source $_ })
    $rejectedSources = @($items | Where-Object { Test-JobAgentCoverageRejectedSource -Source $_ })
    $verificationGaps = @($items | Where-Object { Test-JobAgentCoverageSourceVerificationGap -Source $_ })
    $importableSources = @($items | Where-Object { Test-JobAgentCoverageImportableSource -Source $_ })

    [pscustomobject]@{
        generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        source_registry_version = [string](Get-JobAgentCoverageProperty -Object $SourceRegistry -Name 'schema_version' -Default 'UNKNOWN')
        sources_total = $items.Count
        class_counts = [pscustomobject]$classCounts
        import_mode_counts = [pscustomobject]$modeCounts
        evidence_level_counts = [pscustomobject]$evidenceCounts
        importable_sources = $importableSources.Count
        rejected_sources = $rejectedSources.Count
        manual_review_sources = $manualReviewSources.Count
        verification_gap_sources = $verificationGaps.Count
        rejected_source_ids = @($rejectedSources | ForEach-Object { [string]$_.source_id } | Sort-Object)
        manual_review_source_ids = @($manualReviewSources | ForEach-Object { [string]$_.source_id } | Sort-Object)
        verification_gap_source_ids = @($verificationGaps | ForEach-Object { [string]$_.source_id } | Sort-Object)
    }
}

function Get-JobAgentCoverageDuplicateGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document
    )

    $domainGroups = @($Document.companies |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-JobAgentCoverageProperty -Object $_ -Name 'canonical_domain')) } |
        Group-Object { [string]$_.canonical_domain } |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                basis = 'canonical_domain'
                key = [string]$_.Name
                company_ids = @($_.Group | ForEach-Object { [string]$_.company_id } | Sort-Object)
                companies = @($_.Group | ForEach-Object { [string]$_.canonical_name } | Sort-Object)
            }
        })
    $nameGroups = @($Document.companies |
        Group-Object { ConvertTo-JobAgentCoverageNameKey -Value (Get-JobAgentCoverageProperty -Object $_ -Name 'canonical_name') } |
        Where-Object { $_.Name -ne 'UNKNOWN' -and $_.Count -gt 1 } |
        ForEach-Object {
            [pscustomobject]@{
                basis = 'normalized_name'
                key = [string]$_.Name
                company_ids = @($_.Group | ForEach-Object { [string]$_.company_id } | Sort-Object)
                companies = @($_.Group | ForEach-Object { [string]$_.canonical_name } | Sort-Object)
            }
        })

    return @(@($domainGroups) + @($nameGroups) | Sort-Object basis, key)
}

function New-JobAgentCoverageDimensions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CompanyMetrics
    )

    $verification = @{}
    $inventory = @{}
    $target = @{}
    $industry = @{}
    $sourceType = @{}
    $sourceOrigin = @{}
    foreach ($metric in @($CompanyMetrics)) {
        Add-JobAgentCoverageCount -Counts $verification -Key $metric.verification_status
        Add-JobAgentCoverageCount -Counts $inventory -Key $metric.inventory_state
        Add-JobAgentCoverageCount -Counts $industry -Key $metric.industry
        Add-JobAgentCoverageCount -Counts $sourceType -Key $metric.discovery_type
        Add-JobAgentCoverageCount -Counts $sourceOrigin -Key $metric.discovery_origin
        foreach ($area in @($metric.target_areas)) {
            Add-JobAgentCoverageCount -Counts $target -Key $area
        }
    }

    [pscustomobject]@{
        by_verification_status = ConvertTo-JobAgentCoverageCountsObject -Counts $verification
        by_inventory_state = ConvertTo-JobAgentCoverageCountsObject -Counts $inventory
        by_target_area = ConvertTo-JobAgentCoverageCountsObject -Counts $target
        by_industry = ConvertTo-JobAgentCoverageCountsObject -Counts $industry
        by_discovery_type = ConvertTo-JobAgentCoverageCountsObject -Counts $sourceType
        by_discovery_origin = ConvertTo-JobAgentCoverageCountsObject -Counts $sourceOrigin
    }
}

function Test-JobAgentCoverageWaveCompanyMatch {
    param(
        [Parameter(Mandatory)][object]$Metric,
        [Parameter(Mandatory)][string]$WaveId
    )

    $origin = [string]$Metric.discovery_origin
    $industry = [string]$Metric.industry
    $area = [string]$Metric.target_area
    switch ($WaveId) {
        'A' {
            return [int]$Metric.scan_priority -ge 85 -or $origin -eq 'source-registry:stadt_muenchen_boersennotierte_unternehmen'
        }
        'B' {
            return @('FREISING', 'MUNICH_20KM') -contains $area -or $industry -match 'Airport|Research|Semiconductor'
        }
        'C' {
            return $origin -match 'emm|metropolregion|cluster' -or $industry -match 'Public Sector|Research|University|Hochschule'
        }
        'D' {
            return $origin -match 'ba_jobsuche|eures|make_it_in_germany|yourfirm'
        }
        default {
            return $true
        }
    }
}

function New-JobAgentCoverageWaveCandidate {
    param(
        [Parameter(Mandatory)][object]$Metric,
        [Parameter(Mandatory)][string]$Kind
    )

    [pscustomobject]@{
        kind = $Kind
        company_id = [string]$Metric.company_id
        company = [string]$Metric.company
        target_area = [string]$Metric.target_area
        industry = [string]$Metric.industry
        verification_status = [string]$Metric.verification_status
        review_status = [string]$Metric.inventory_state
        discovery_origin = [string]$Metric.discovery_origin
        next_step = [string]$Metric.next_step
    }
}

function New-JobAgentCoverageHintWaveCandidate {
    param([Parameter(Mandatory)][object]$Hint)

    [pscustomobject]@{
        kind = 'discovery_hint'
        company_id = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'known_company_id' -Default '')
        company = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'employer_name' -Default (Get-JobAgentCoverageProperty -Object $Hint -Name 'company_name' -Default 'UNKNOWN'))
        target_area = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'target_area' -Default 'UNKNOWN')
        industry = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'industry_or_keyword' -Default (Get-JobAgentCoverageProperty -Object $Hint -Name 'sector_hint' -Default 'UNKNOWN'))
        verification_status = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'verification_status' -Default 'UNVERIFIED')
        review_status = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'candidate_status' -Default 'DISCOVERY_HINT')
        discovery_origin = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'source_id' -Default 'UNKNOWN')
        next_step = [string](Get-JobAgentCoverageProperty -Object $Hint -Name 'next_action' -Default 'verify_official_company_website_or_career_url')
    }
}

function New-JobAgentCoverageImportWavePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CompanyMetrics,
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][ValidateRange(1, 100)][int]$MaxCandidatesPerWave = 12
    )

    $waveDefinitions = @(
        [pscustomobject]@{ wave_id = 'A'; title = 'Grosse regionale Arbeitgeber und boersennotierte Unternehmen'; milestone = 'M5-A'; dependency = 'JA-024/JA-026'; priority_score = 100 }
        [pscustomobject]@{ wave_id = 'B'; title = 'Freising, Weihenstephan und Flughafen-Umfeld'; milestone = 'M5-B'; dependency = 'JA-024/JA-026'; priority_score = 92 }
        [pscustomobject]@{ wave_id = 'C'; title = 'EMM-Mitglieder, Branchencluster und oeffentliche Institutionen'; milestone = 'M5-C'; dependency = 'JA-023'; priority_score = 84 }
        [pscustomobject]@{ wave_id = 'D'; title = 'BA, EURES und Make-it-in-Germany-Hints'; milestone = 'M5-D'; dependency = 'JA-025'; priority_score = 76 }
        [pscustomobject]@{ wave_id = 'E'; title = 'Startup-, Scaleup- und manuelle Review-Reste'; milestone = 'M5-E'; dependency = 'JA-027 Coverage-Audit'; priority_score = 68 }
    )

    $assigned = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $waves = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $waveDefinitions) {
        $companyCandidates = foreach ($metric in @($CompanyMetrics)) {
            if ($assigned.Contains([string]$metric.company_id)) {
                continue
            }
            if (Test-JobAgentCoverageWaveCompanyMatch -Metric $metric -WaveId ([string]$definition.wave_id)) {
                New-JobAgentCoverageWaveCandidate -Metric $metric -Kind 'company'
            }
        }
        foreach ($candidate in @($companyCandidates)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$candidate.company_id)) {
                [void]$assigned.Add([string]$candidate.company_id)
            }
        }

        $hintCandidates = @()
        if ($null -ne $HintStore -and $definition.wave_id -eq 'D') {
            $hintCandidates = @($HintStore.hints |
                Where-Object { [string](Get-JobAgentCoverageProperty -Object $_ -Name 'candidate_status' -Default '') -in @('DISCOVERY_HINT', 'REGIONAL_DISCOVERY_HINT') } |
                ForEach-Object { New-JobAgentCoverageHintWaveCandidate -Hint $_ })
        }

        $allCandidates = @(@($companyCandidates) + @($hintCandidates) |
            Sort-Object @{ Expression = { [string]$_.review_status -eq 'CAREER_URL_VERIFIED' }; Ascending = $true }, company |
            Select-Object -First $MaxCandidatesPerWave)
        $waves.Add([pscustomobject]@{
                wave_id = [string]$definition.wave_id
                title = [string]$definition.title
                dependency = [string]$definition.dependency
                priority_score = [int]$definition.priority_score
                milestone = [string]$definition.milestone
                candidates_total = @($allCandidates).Count
                candidates = @($allCandidates)
            })
    }

    [pscustomobject]@{
        contract = 'Importwellen sind operative Kandidatenlisten; unverifizierte Hints bleiben ausserhalb des Firmenbestands, bis offizielle Website oder Karriere-URL belegt ist.'
        waves = @($waves.ToArray())
    }
}

function New-JobAgentCoverageReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][AllowNull()][object]$SourceRegistry = $null,
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][AllowNull()][object]$CandidateVerificationQueue = $null,
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
    $candidateClusters = New-JobAgentCoverageCandidateClusterReport -HintStore $HintStore -Now $Now -MaxReviewItems $MaxPriorityItems
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
            career_url_verified = @($metricsArray | Where-Object { [string]$_.verification_status -eq 'CAREER_URL_VERIFIED' }).Count
            company_domain_verified = @($metricsArray | Where-Object { [string]$_.verification_status -eq 'COMPANY_DOMAIN_VERIFIED' }).Count
            unverified = @($metricsArray | Where-Object { [string]$_.verification_status -eq 'UNVERIFIED' }).Count
            duplicate_groups = @(Get-JobAgentCoverageDuplicateGroups -Document $Document).Count
            discovery_hints_total = if ($null -eq $HintStore) { 0 } else { @($HintStore.hints).Count }
            unverified_discovery_hints = if ($null -eq $HintStore) { 0 } else { @($HintStore.hints | Where-Object { [string](Get-JobAgentCoverageProperty -Object $_ -Name 'verification_status' -Default 'UNVERIFIED') -eq 'UNVERIFIED' }).Count }
            candidate_clusters_total = $candidateClusters.clusters_total
            candidate_conflict_clusters = $candidateClusters.conflict_clusters
            candidate_review_queue_total = $candidateClusters.review_queue_total
            candidate_verification_queue_total = if ($null -eq $CandidateVerificationQueue) { 0 } else { @($CandidateVerificationQueue.queue).Count }
            candidate_verification_ready = if ($null -eq $CandidateVerificationQueue) { 0 } else { @($CandidateVerificationQueue.queue | Where-Object { [string]$_.status -in @('PENDING', 'RETRY_SCHEDULED') }).Count }
            candidate_verification_verified = if ($null -eq $CandidateVerificationQueue) { 0 } else { @($CandidateVerificationQueue.queue | Where-Object { [string]$_.status -eq 'VERIFIED' }).Count }
            candidate_verification_manual_review = if ($null -eq $CandidateVerificationQueue) { 0 } else { @($CandidateVerificationQueue.queue | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count }
            candidate_verification_retry_exhausted = if ($null -eq $CandidateVerificationQueue) { 0 } else { @($CandidateVerificationQueue.queue | Where-Object { [string]$_.status -eq 'RETRY_EXHAUSTED' }).Count }
        }
        dimensions = New-JobAgentCoverageDimensions -CompanyMetrics $metricsArray
        companies = @($metricsArray | Sort-Object company)
        duplicates = @(Get-JobAgentCoverageDuplicateGroups -Document $Document)
        backlog = @(Get-JobAgentCoverageBacklog -CompanyMetrics $metricsArray)
        scan_priority = @(Get-JobAgentCoverageScanPriority -CompanyMetrics $metricsArray -MaxCompanies $MaxPriorityItems)
        source_coverage = if ($null -eq $SourceRegistry) { $null } else { New-JobAgentDiscoverySourceCoverageReport -SourceRegistry $SourceRegistry -Now $Now }
        candidate_clusters = $candidateClusters
        candidate_verification_queue = if ($null -eq $CandidateVerificationQueue) { $null } else { $CandidateVerificationQueue }
        import_waves = New-JobAgentCoverageImportWavePlan -CompanyMetrics $metricsArray -HintStore $HintStore
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentCoverageBacklog',
    'Get-JobAgentCoverageScanPriority',
    'Get-JobAgentCoverageDuplicateGroups',
    'New-JobAgentCoverageCandidateClusterReport',
    'New-JobAgentDiscoverySourceCoverageReport',
    'New-JobAgentCoverageDimensions',
    'New-JobAgentCoverageImportWavePlan',
    'New-JobAgentCoverageReport'
)
