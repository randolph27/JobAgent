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

function ConvertTo-JobAgentCoverageIso {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    $date = if ($Value -is [datetime]) { $Value.ToUniversalTime() } else { ConvertTo-JobAgentCoverageDate -Value $Value }
    if ($null -eq $date) {
        return $null
    }
    return $date.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-JobAgentCoveragePolicyDays {
    param(
        [Parameter()][AllowEmptyString()][string]$Kind,
        [Parameter()][ValidateRange(1, 3650)][int]$DefaultDays = 30
    )

    switch ($Kind) {
        'JOB_BOARD_DISCOVERY' { return 7 }
        'DISCOVERY_HINT' { return 7 }
        'REGISTER_DISCOVERY_HINT' { return 30 }
        'OPEN_REGISTER_DUMP' { return 30 }
        'OFFICIAL_REGISTER' { return 30 }
        'REGIONAL_DIRECTORY' { return 90 }
        'PUBLIC_INSTITUTION_DIRECTORY' { return 90 }
        'REGIONAL_DISCOVERY_HINT' { return 90 }
        'OFFICIAL_COMPANY' { return 30 }
        'OFFICIAL_ATS' { return 30 }
        'CAREER_URL_VERIFIED' { return 30 }
        'COMPANY_DOMAIN_VERIFIED' { return 90 }
        'UNVERIFIED' { return 14 }
        'REJECTED' { return 3650 }
        default { return $DefaultDays }
    }
}

function New-JobAgentCoverageFreshnessRecord {
    param(
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter()][AllowNull()][object]$LastImportedAt,
        [Parameter()][AllowNull()][object]$LastVerifiedAt,
        [Parameter()][AllowNull()][object]$NextRefreshAt,
        [Parameter()][ValidateRange(1, 3650)][int]$ExpiresAfterDays,
        [Parameter()][AllowEmptyString()][string]$RefreshReason = 'scheduled_refresh'
    )

    $lastImported = if ($LastImportedAt -is [datetime]) { $LastImportedAt.ToUniversalTime() } else { ConvertTo-JobAgentCoverageDate -Value $LastImportedAt }
    $lastVerified = if ($LastVerifiedAt -is [datetime]) { $LastVerifiedAt.ToUniversalTime() } else { ConvertTo-JobAgentCoverageDate -Value $LastVerifiedAt }
    $nextRefresh = if ($NextRefreshAt -is [datetime]) { $NextRefreshAt.ToUniversalTime() } else { ConvertTo-JobAgentCoverageDate -Value $NextRefreshAt }
    $basis = if ($null -ne $lastVerified) { $lastVerified } else { $lastImported }
    $expiresAt = if ($null -eq $basis) { $null } else { $basis.AddDays($ExpiresAfterDays) }
    $effectiveNext = if ($null -ne $nextRefresh) {
        if ($null -ne $expiresAt -and $expiresAt -lt $nextRefresh) { $expiresAt } else { $nextRefresh }
    }
    else {
        $expiresAt
    }
    $nowUtc = $Now.ToUniversalTime()
    $status = if ($null -eq $basis) {
        'UNKNOWN'
    }
    elseif ($null -ne $expiresAt -and $expiresAt -lt $nowUtc) {
        'EXPIRED'
    }
    elseif ($null -ne $effectiveNext -and $effectiveNext -le $nowUtc) {
        'REFRESH_DUE'
    }
    else {
        'FRESH'
    }

    [pscustomobject]@{
        last_imported_at = ConvertTo-JobAgentCoverageIso -Value $lastImported
        last_verified_at = ConvertTo-JobAgentCoverageIso -Value $lastVerified
        expires_at = ConvertTo-JobAgentCoverageIso -Value $expiresAt
        next_refresh_at = ConvertTo-JobAgentCoverageIso -Value $effectiveNext
        refresh_reason = $RefreshReason
        staleness_status = $status
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

function Test-JobAgentCoverageHttpUrl {
    param([Parameter()][AllowNull()][object]$Url)

    if ($null -eq $Url -or [string]::IsNullOrWhiteSpace([string]$Url)) {
        return $false
    }
    $uri = $null
    if (-not [System.Uri]::TryCreate(([string]$Url).Trim(), [System.UriKind]::Absolute, [ref]$uri)) {
        return $false
    }
    return @('http', 'https') -contains $uri.Scheme
}

function New-JobAgentCoverageLinkObject {
    param(
        [Parameter(Mandatory)][string]$LinkType,
        [Parameter(Mandatory)][string]$Label,
        [Parameter()][AllowNull()][object]$Url,
        [Parameter(Mandatory)][string]$SourceField,
        [Parameter()][AllowEmptyString()][string]$SourceId = '',
        [Parameter(Mandatory)][string]$VerificationStatus,
        [Parameter(Mandatory)][bool]$IsPrimary,
        [Parameter(Mandatory)][bool]$ReviewOnly,
        [Parameter(Mandatory)][string]$Reason
    )

    $urlText = if ($null -eq $Url) { '' } else { ([string]$Url).Trim() }
    $hasValidUrl = Test-JobAgentCoverageHttpUrl -Url $urlText
    [pscustomobject]@{
        link_type = $LinkType
        label = $Label
        url = if ($hasValidUrl) { $urlText } else { $null }
        source_id = if ([string]::IsNullOrWhiteSpace($SourceId)) { $null } else { $SourceId }
        source_field = $SourceField
        verification_status = $VerificationStatus
        is_primary = $IsPrimary
        is_clickable = ($hasValidUrl -and -not $ReviewOnly -and $VerificationStatus -ne 'UNVERIFIED')
        review_only = $ReviewOnly
        reason = $Reason
    }
}

function Get-JobAgentCoverageCompanyLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowEmptyCollection()][object[]]$JobSources = @()
    )

    $links = [System.Collections.Generic.List[object]]::new()
    $companyStatus = [string](Get-JobAgentCoverageProperty -Object $Company -Name 'verification_status' -Default 'UNVERIFIED')
    $discoverySource = Get-JobAgentCoverageProperty -Object $Company -Name 'discovery_source'
    $discoveryType = [string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'type' -Default '')
    $requiresReview = $companyStatus -eq 'UNVERIFIED' -or @('DISCOVERY_HINT', 'MANUAL_REVIEW') -contains $discoveryType
    $careerUrl = Get-JobAgentCoverageProperty -Object $Company -Name 'career_url'
    $websiteUrl = Get-JobAgentCoverageProperty -Object $Company -Name 'official_website_url'

    if (Test-JobAgentCoverageHttpUrl -Url $careerUrl) {
        $links.Add((New-JobAgentCoverageLinkObject -LinkType 'career' -Label 'Karriere' -Url $careerUrl -SourceField 'company.career_url' -VerificationStatus $(if ($requiresReview) { 'UNVERIFIED' } else { 'VERIFIED' }) -IsPrimary $true -ReviewOnly $requiresReview -Reason $(if ($requiresReview) { 'Karriere-URL ist noch nicht als offizielle Anbieterquelle verifiziert.' } else { 'Karriere-URL aus Firmeninventar.' })))
    }
    elseif (Test-JobAgentCoverageHttpUrl -Url $websiteUrl) {
        $links.Add((New-JobAgentCoverageLinkObject -LinkType 'website' -Label 'Website' -Url $websiteUrl -SourceField 'company.official_website_url' -VerificationStatus $(if ($requiresReview) { 'UNVERIFIED' } else { 'VERIFIED' }) -IsPrimary $true -ReviewOnly $requiresReview -Reason $(if ($requiresReview) { 'Website ist noch nicht als offizielle Anbieterquelle verifiziert.' } else { 'Offizielle Website aus Firmeninventar; Karriere-URL fehlt.' })))
    }

    foreach ($source in @($JobSources | Where-Object { $null -ne $_ })) {
        $isOfficial = [bool](Get-JobAgentCoverageProperty -Object $source -Name 'is_official' -Default $false)
        if (-not $isOfficial) {
            continue
        }
        $sourceType = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_type' -Default '')
        $basis = [string](Get-JobAgentCoverageProperty -Object $source -Name 'verification_basis' -Default '')
        $canonicalUrl = Get-JobAgentCoverageProperty -Object $source -Name 'canonical_url'
        if (-not (Test-JobAgentCoverageHttpUrl -Url $canonicalUrl)) {
            continue
        }
        if ($sourceType -eq 'CAREER_PAGE' -and -not (Test-JobAgentCoverageHttpUrl -Url $careerUrl)) {
            $links.Add((New-JobAgentCoverageLinkObject -LinkType 'career' -Label 'Karriere' -Url $canonicalUrl -SourceField 'job_sources.canonical_url' -SourceId ([string]$source.source_id) -VerificationStatus 'VERIFIED' -IsPrimary ($links.Count -eq 0) -ReviewOnly $false -Reason 'Offizielle JobSource fuer Karriere-Seite.'))
            continue
        }
        if ($sourceType -eq 'OFFICIAL_ATS' -or $basis -eq 'COMPANY_LINKED_ATS') {
            $links.Add((New-JobAgentCoverageLinkObject -LinkType 'ats' -Label 'ATS' -Url $canonicalUrl -SourceField 'job_sources.canonical_url' -SourceId ([string]$source.source_id) -VerificationStatus 'VERIFIED' -IsPrimary ($links.Count -eq 0) -ReviewOnly $false -Reason 'Offiziell belegte ATS-Quelle.'))
        }
    }

    $discoveryUrl = Get-JobAgentCoverageProperty -Object $discoverySource -Name 'url'
    if (@('DISCOVERY_HINT', 'MANUAL_REVIEW') -contains $discoveryType -and (Test-JobAgentCoverageHttpUrl -Url $discoveryUrl)) {
        $links.Add((New-JobAgentCoverageLinkObject -LinkType 'review_hint' -Label 'Review-Hinweis' -Url $discoveryUrl -SourceField 'company.discovery_source.url' -SourceId ([string](Get-JobAgentCoverageProperty -Object $discoverySource -Name 'discovery_origin' -Default '')) -VerificationStatus 'UNVERIFIED' -IsPrimary ($links.Count -eq 0) -ReviewOnly $true -Reason 'Unverifizierter Discovery-Hinweis; nicht als offizielle Anbieterquelle verwenden.'))
    }

    $officialLinks = @($links.ToArray() | Where-Object { [bool]$_.is_clickable })
    if ($officialLinks.Count -eq 0) {
        $links.Add((New-JobAgentCoverageLinkObject -LinkType 'missing' -Label 'Kein offizieller Link' -Url $null -SourceField 'coverage.fail_closed' -VerificationStatus 'MISSING' -IsPrimary ($links.Count -eq 0) -ReviewOnly $false -Reason 'Keine verifizierte Karriere-, Website- oder ATS-URL vorhanden.'))
    }

    $rank = @{ career = 0; website = 1; ats = 2; review_hint = 3; missing = 4 }
    return @($links.ToArray() | Sort-Object -Property { if ($rank.ContainsKey([string]$_.link_type)) { $rank[[string]$_.link_type] } else { 9 } }, label, url)
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

function Get-JobAgentCoverageSourcesByCompany {
    param([Parameter(Mandatory)][object]$Document)

    $map = @{}
    foreach ($source in @($Document.job_sources)) {
        $companyId = [string](Get-JobAgentCoverageProperty -Object $source -Name 'company_id' -Default '')
        if ([string]::IsNullOrWhiteSpace($companyId)) {
            continue
        }
        if (-not $map.ContainsKey($companyId)) {
            $map[$companyId] = [System.Collections.Generic.List[object]]::new()
        }
        $map[$companyId].Add($source)
    }
    return $map
}

function Get-JobAgentCoverageCompanyMetric {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowNull()][object]$LatestAttempt,
        [Parameter()][AllowEmptyCollection()][object[]]$Jobs = @(),
        [Parameter()][AllowEmptyCollection()][object[]]$JobSources = @(),
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
    $lastImportedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'last_imported_at')
    if ($null -eq $lastImportedAt) {
        $lastImportedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $discoverySource -Name 'observed_at')
    }
    if ($null -eq $lastImportedAt) {
        $lastImportedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'created_at')
    }
    $lastVerifiedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'last_verified_at')
    if ($null -eq $lastVerifiedAt) {
        $lastVerifiedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'career_verification_reviewed_at')
    }
    if ($null -eq $lastVerifiedAt) {
        $lastVerifiedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'career_verification_checked_at')
    }
    if ($null -eq $lastVerifiedAt -and $verificationStatus -in @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED')) {
        $lastVerifiedAt = $lastImportedAt
    }
    $nextScanAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $Company -Name 'next_scan_at')
    $policyKey = if ($verificationStatus -eq 'UNVERIFIED') { $verificationStatus } elseif ($discoveryType -in @('DISCOVERY_HINT', 'MANUAL_REVIEW')) { $discoveryType } else { $verificationStatus }
    $freshness = New-JobAgentCoverageFreshnessRecord `
        -Now $Now `
        -LastImportedAt $lastImportedAt `
        -LastVerifiedAt $lastVerifiedAt `
        -NextRefreshAt $nextScanAt `
        -ExpiresAfterDays (Get-JobAgentCoveragePolicyDays -Kind $policyKey -DefaultDays $StaleAfterDays) `
        -RefreshReason $(if ($verificationStatus -eq 'UNVERIFIED' -or $discoveryType -in @('DISCOVERY_HINT', 'MANUAL_REVIEW')) { 'official_verification_required' } elseif ($latestScanFailed) { 'last_scan_failed' } elseif ($null -eq $lastSuccessfulScanAt) { 'initial_scan_required' } else { 'scheduled_company_rotation' })
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
    $links = @(Get-JobAgentCoverageCompanyLinks -Company $Company -JobSources $JobSources)
    $primaryLink = @($links | Where-Object { [bool]$_.is_primary } | Select-Object -First 1)

    [pscustomobject]@{
        company_id = $companyId
        company = [string](Get-JobAgentCoverageProperty -Object $Company -Name 'canonical_name' -Default $companyId)
        links = @($links)
        primary_link = if ($primaryLink.Count -eq 1) { $primaryLink[0] } else { $null }
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
        last_imported_at = $freshness.last_imported_at
        last_verified_at = $freshness.last_verified_at
        expires_at = $freshness.expires_at
        next_refresh_at = $freshness.next_refresh_at
        refresh_reason = $freshness.refresh_reason
        staleness_status = $freshness.staleness_status
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

    return @($items.ToArray() | Sort-Object -Property { '{0:D4}|{1}' -f (1000 - [int]$_.priority_score), [string]$_.company })
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

    return @($items | Sort-Object -Property { '{0:D4}|{1}' -f (1000 - [int]$_.priority_score), [string]$_.company } | Select-Object -First $MaxCompanies)
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
    $freshnessItems = [System.Collections.Generic.List[object]]::new()
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
        $lastImportedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $source -Name 'last_imported_at')
        if ($null -eq $lastImportedAt) {
            $lastImportedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $SourceRegistry -Name 'generated_at')
        }
        $freshness = New-JobAgentCoverageFreshnessRecord `
            -Now $Now `
            -LastImportedAt $lastImportedAt `
            -LastVerifiedAt (ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $source -Name 'last_verified_at')) `
            -NextRefreshAt (ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $source -Name 'next_refresh_at')) `
            -ExpiresAfterDays (Get-JobAgentCoveragePolicyDays -Kind $sourceClass) `
            -RefreshReason $(if ($sourceClass -eq 'REJECTED') { 'blocked_source_not_refreshed' } elseif (Test-JobAgentCoverageManualReviewSource -Source $source) { 'review_required_before_import' } else { 'source_registry_refresh' })
        $freshnessItems.Add([pscustomobject]@{
                source_id = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_id' -Default 'UNKNOWN')
                source_class = $sourceClass
                import_mode = $mode
                last_imported_at = $freshness.last_imported_at
                last_verified_at = $freshness.last_verified_at
                expires_at = $freshness.expires_at
                next_refresh_at = $freshness.next_refresh_at
                refresh_reason = $freshness.refresh_reason
                staleness_status = $freshness.staleness_status
            })
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
        refresh_due_sources = @($freshnessItems.ToArray() | Where-Object { [string]$_.staleness_status -in @('REFRESH_DUE', 'EXPIRED', 'UNKNOWN') }).Count
        rejected_source_ids = @($rejectedSources | ForEach-Object { [string]$_.source_id } | Sort-Object)
        manual_review_source_ids = @($manualReviewSources | ForEach-Object { [string]$_.source_id } | Sort-Object)
        verification_gap_source_ids = @($verificationGaps | ForEach-Object { [string]$_.source_id } | Sort-Object)
        freshness = @($freshnessItems.ToArray() | Sort-Object staleness_status, source_class, source_id)
    }
}

function Get-JobAgentCoverageLatestScanRunId {
    param([Parameter(Mandatory)][object]$Document)

    $latestRun = @($Document.scan_runs |
        Where-Object { $null -ne $_ } |
        Sort-Object -Property {
            $finishedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $_ -Name 'finished_at')
            if ($null -ne $finishedAt) {
                return $finishedAt
            }
            $startedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $_ -Name 'started_at')
            if ($null -ne $startedAt) {
                return $startedAt
            }
            return [datetime]::MinValue
        } |
        Select-Object -Last 1)
    if ($latestRun.Count -eq 0) {
        return $null
    }
    return [string]$latestRun[0].scan_run_id
}

function New-JobAgentCoverageSourceInventoryRecord {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourceGroup,
        [Parameter(Mandatory)][string]$SourceType,
        [Parameter()][AllowEmptyString()][string]$Url = '',
        [Parameter()][AllowEmptyString()][string]$CompanyId = '',
        [Parameter()][bool]$IsOfficial = $false,
        [Parameter()][bool]$IsVerified = $false,
        [Parameter()][bool]$IsBlocked = $false,
        [Parameter()][AllowEmptyString()][string]$VerificationStatus = 'UNVERIFIED',
        [Parameter()][AllowNull()][object]$LatestAttempt = $null,
        [Parameter()][bool]$IsStale = $true
    )

    $attemptStatus = [string](Get-JobAgentCoverageProperty -Object $LatestAttempt -Name 'status' -Default 'NEVER_SCANNED')
    $retryRecommendation = [string](Get-JobAgentCoverageProperty -Object $LatestAttempt -Name 'retry_recommendation' -Default 'NONE')
    [pscustomobject]@{
        source_id = $SourceId
        source_group = $SourceGroup
        source_type = $SourceType
        company_id = if ([string]::IsNullOrWhiteSpace($CompanyId)) { $null } else { $CompanyId }
        url = if ([string]::IsNullOrWhiteSpace($Url)) { $null } else { $Url.Trim() }
        is_official = $IsOfficial
        is_verified = $IsVerified
        is_blocked = $IsBlocked
        verification_status = $VerificationStatus
        latest_attempt_status = $attemptStatus
        retry_recommendation = $retryRecommendation
        was_attempted_latest_run = $null -ne $LatestAttempt
        scan_succeeded_latest_run = $attemptStatus -eq 'SUCCESS'
        scan_failed_latest_run = $attemptStatus -eq 'FAILED'
        retry_open = $retryRecommendation -in @('RETRY_NEXT_RUN', 'MANUAL_REVIEW') -or $attemptStatus -eq 'FAILED'
        is_stale = $IsStale
    }
}

function New-JobAgentSourceInventoryReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][AllowNull()][object]$SourceRegistry = $null,
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][AllowEmptyString()][string]$LatestScanRunId = '',
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7
    )

    $effectiveScanRunId = if ([string]::IsNullOrWhiteSpace($LatestScanRunId)) { Get-JobAgentCoverageLatestScanRunId -Document $Document } else { $LatestScanRunId }
    $attemptsBySource = @{}
    foreach ($attempt in @($Document.scan_attempts | Where-Object { [string]::IsNullOrWhiteSpace($effectiveScanRunId) -or [string]$_.scan_run_id -eq $effectiveScanRunId })) {
        $sourceId = [string](Get-JobAgentCoverageProperty -Object $attempt -Name 'source_id' -Default '')
        if ([string]::IsNullOrWhiteSpace($sourceId)) {
            continue
        }
        $startedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $attempt -Name 'started_at')
        $currentStartedAt = if ($attemptsBySource.ContainsKey($sourceId)) { ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $attemptsBySource[$sourceId] -Name 'started_at') } else { $null }
        if (-not $attemptsBySource.ContainsKey($sourceId) -or $null -eq $currentStartedAt -or ($null -ne $startedAt -and $startedAt -gt $currentStartedAt)) {
            $attemptsBySource[$sourceId] = $attempt
        }
    }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($source in @($Document.job_sources)) {
        $sourceId = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_id' -Default 'UNKNOWN')
        $sourceType = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_type' -Default 'UNKNOWN')
        $verifiedAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $source -Name 'verified_at')
        $isOfficial = [bool](Get-JobAgentCoverageProperty -Object $source -Name 'is_official' -Default $false)
        $hasVerifiedEvidence = @((Get-JobAgentCoverageProperty -Object $source -Name 'verification_evidence' -Default @()) | Where-Object {
                [string](Get-JobAgentCoverageProperty -Object $_ -Name 'status' -Default '') -eq 'VERIFIED'
            }).Count -gt 0
        $isVerified = $isOfficial -and $null -ne $verifiedAt -and $hasVerifiedEvidence
        $latestAttempt = if ($attemptsBySource.ContainsKey($sourceId)) { $attemptsBySource[$sourceId] } else { $null }
        $lastAttemptAt = ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $latestAttempt -Name 'finished_at')
        $records.Add((New-JobAgentCoverageSourceInventoryRecord `
                    -SourceId $sourceId `
                    -SourceGroup 'job_source' `
                    -SourceType $sourceType `
                    -Url ([string](Get-JobAgentCoverageProperty -Object $source -Name 'canonical_url' -Default (Get-JobAgentCoverageProperty -Object $source -Name 'url' -Default ''))) `
                    -CompanyId ([string](Get-JobAgentCoverageProperty -Object $source -Name 'company_id' -Default '')) `
                    -IsOfficial $isOfficial `
                    -IsVerified $isVerified `
                    -VerificationStatus $(if ($isVerified) { 'VERIFIED' } else { 'UNVERIFIED' }) `
                    -LatestAttempt $latestAttempt `
                    -IsStale ($null -eq $lastAttemptAt -or $lastAttemptAt -lt $Now.ToUniversalTime().AddDays(-$StaleAfterDays))))
    }

    foreach ($source in @(if ($null -eq $SourceRegistry) { @() } else { $SourceRegistry.items })) {
        $sourceClass = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_class' -Default 'UNKNOWN')
        $evidenceLevel = [string](Get-JobAgentCoverageProperty -Object $source -Name 'evidence_level' -Default 'UNKNOWN')
        $sourceId = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_id' -Default 'UNKNOWN')
        $freshness = New-JobAgentCoverageFreshnessRecord `
            -Now $Now `
            -LastImportedAt (Get-JobAgentCoverageProperty -Object $source -Name 'last_imported_at') `
            -LastVerifiedAt (Get-JobAgentCoverageProperty -Object $source -Name 'last_verified_at') `
            -NextRefreshAt (Get-JobAgentCoverageProperty -Object $source -Name 'next_refresh_at') `
            -ExpiresAfterDays (Get-JobAgentCoveragePolicyDays -Kind $sourceClass) `
            -RefreshReason 'source_registry_refresh'
        $records.Add((New-JobAgentCoverageSourceInventoryRecord `
                    -SourceId $sourceId `
                    -SourceGroup 'source_registry' `
                    -SourceType $sourceClass `
                    -Url ([string](Get-JobAgentCoverageProperty -Object $source -Name 'source_url' -Default '')) `
                    -IsOfficial ($sourceClass -in @('OFFICIAL_COMPANY', 'OFFICIAL_ATS') -and $evidenceLevel -eq 'PRIMARY_OFFICIAL') `
                    -IsVerified ($evidenceLevel -eq 'PRIMARY_OFFICIAL' -and -not (Test-JobAgentCoverageManualReviewSource -Source $source)) `
                    -IsBlocked (Test-JobAgentCoverageRejectedSource -Source $source) `
                    -VerificationStatus $(if ($evidenceLevel -eq 'PRIMARY_OFFICIAL') { 'VERIFIED' } elseif (Test-JobAgentCoverageRejectedSource -Source $source) { 'BLOCKED' } else { 'UNVERIFIED' }) `
                    -IsStale ([string]$freshness.staleness_status -in @('REFRESH_DUE', 'EXPIRED', 'UNKNOWN'))))
    }

    foreach ($hint in @(if ($null -eq $HintStore) { @() } else { $HintStore.hints })) {
        $hintId = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'hint_id' -Default ([string](Get-JobAgentCoverageProperty -Object $hint -Name 'candidate_id' -Default 'UNKNOWN')))
        $records.Add((New-JobAgentCoverageSourceInventoryRecord `
                    -SourceId $hintId `
                    -SourceGroup 'discovery_hint' `
                    -SourceType ([string](Get-JobAgentCoverageProperty -Object $hint -Name 'candidate_status' -Default 'DISCOVERY_HINT')) `
                    -Url ([string](Get-JobAgentCoverageProperty -Object $hint -Name 'observed_url' -Default '')) `
                    -IsOfficial $false `
                    -IsVerified $false `
                    -VerificationStatus ([string](Get-JobAgentCoverageProperty -Object $hint -Name 'verification_status' -Default 'UNVERIFIED')) `
                    -IsStale $true))
    }

    $items = @($records.ToArray())
    $urlGroups = @($items | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.url) } | Group-Object -Property url | Where-Object Count -gt 1)
    $groupCounts = @{}
    foreach ($group in @($items | Group-Object source_group)) {
        $groupCounts[[string]$group.Name] = [int]$group.Count
    }
    $typeCounts = @{}
    foreach ($group in @($items | Group-Object source_type)) {
        $typeCounts[[string]$group.Name] = [int]$group.Count
    }
    [pscustomobject]@{
        schema_version = 'jobagent/source-inventory/v1'
        generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        latest_scan_run_id = if ([string]::IsNullOrWhiteSpace($effectiveScanRunId)) { $null } else { $effectiveScanRunId }
        sources_total = $items.Count
        official_sources = @($items | Where-Object is_official).Count
        career_sources = @($items | Where-Object { [string]$_.source_type -in @('CAREER_PAGE', 'OFFICIAL_COMPANY') }).Count
        ats_sources = @($items | Where-Object { [string]$_.source_type -in @('OFFICIAL_ATS') }).Count
        discovery_sources = @($items | Where-Object { [string]$_.source_group -in @('source_registry', 'discovery_hint') -and -not [bool]$_.is_official }).Count
        discovery_hints = @($items | Where-Object { [string]$_.source_group -eq 'discovery_hint' }).Count
        verified_sources = @($items | Where-Object is_verified).Count
        unverified_sources = @($items | Where-Object { -not [bool]$_.is_verified -and -not [bool]$_.is_blocked }).Count
        blocked_sources = @($items | Where-Object is_blocked).Count
        retry_open_sources = @($items | Where-Object retry_open).Count
        attempted_latest_run = @($items | Where-Object was_attempted_latest_run).Count
        scan_succeeded_latest_run = @($items | Where-Object scan_succeeded_latest_run).Count
        scan_failed_latest_run = @($items | Where-Object scan_failed_latest_run).Count
        never_scanned_sources = @($items | Where-Object { -not [bool]$_.was_attempted_latest_run -and [string]$_.source_group -eq 'job_source' }).Count
        stale_sources = @($items | Where-Object is_stale).Count
        duplicate_url_groups = $urlGroups.Count
        by_group = ConvertTo-JobAgentCoverageCountsObject -Counts $groupCounts
        by_type = ConvertTo-JobAgentCoverageCountsObject -Counts $typeCounts
        items = @($items | Sort-Object source_group, source_type, source_id)
    }
}

function New-JobAgentCoverageCandidateFreshnessReport {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxItems = 25
    )

    $hints = if ($null -eq $HintStore) { @() } else { @($HintStore.hints) }
    $items = foreach ($hint in @($hints)) {
        $status = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'candidate_status' -Default 'DISCOVERY_HINT')
        $freshness = New-JobAgentCoverageFreshnessRecord `
            -Now $Now `
            -LastImportedAt (ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $hint -Name 'observed_at')) `
            -LastVerifiedAt (ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $hint -Name 'last_verified_at')) `
            -NextRefreshAt (ConvertTo-JobAgentCoverageDate -Value (Get-JobAgentCoverageProperty -Object $hint -Name 'next_refresh_at')) `
            -ExpiresAfterDays (Get-JobAgentCoveragePolicyDays -Kind $status) `
            -RefreshReason 'candidate_official_verification_or_refresh'
        [pscustomobject]@{
            candidate_id = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'hint_id' -Default (Get-JobAgentCoverageProperty -Object $hint -Name 'candidate_id' -Default 'UNKNOWN'))
            company = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'employer_name' -Default (Get-JobAgentCoverageProperty -Object $hint -Name 'company_name' -Default 'UNKNOWN'))
            source_id = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'source_id' -Default 'UNKNOWN')
            candidate_status = $status
            target_area = [string](Get-JobAgentCoverageProperty -Object $hint -Name 'target_area' -Default 'UNKNOWN')
            last_imported_at = $freshness.last_imported_at
            last_verified_at = $freshness.last_verified_at
            expires_at = $freshness.expires_at
            next_refresh_at = $freshness.next_refresh_at
            refresh_reason = $freshness.refresh_reason
            staleness_status = $freshness.staleness_status
        }
    }
    $itemsArray = @($items)
    [pscustomobject]@{
        schema_version = 'jobagent/candidate-freshness/v1'
        candidates_total = $itemsArray.Count
        refresh_due_total = @($itemsArray | Where-Object { [string]$_.staleness_status -in @('REFRESH_DUE', 'EXPIRED', 'UNKNOWN') }).Count
        by_staleness_status = ConvertTo-JobAgentCoverageCountsObject -Counts (Get-JobAgentCoverageCountsByProperty -Items $itemsArray -PropertyName 'staleness_status')
        items = @($itemsArray | Sort-Object staleness_status, company, candidate_id | Select-Object -First $MaxItems)
    }
}

function Get-JobAgentCoverageCountsByProperty {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $counts = @{}
    foreach ($item in @($Items)) {
        Add-JobAgentCoverageCount -Counts $counts -Key (Get-JobAgentCoverageProperty -Object $item -Name $PropertyName -Default 'UNKNOWN')
    }
    return $counts
}

function New-JobAgentCoverageCandidateVerificationDecisionReport {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$CandidateVerificationQueue = $null,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxItems = 25
    )

    $entries = if ($null -eq $CandidateVerificationQueue) { @() } else { @($CandidateVerificationQueue.queue) }
    $decisionItems = foreach ($entry in @($entries)) {
        $status = [string]$entry.status
        [pscustomobject]@{
            candidate_id = [string]$entry.candidate_id
            identity_cluster_id = [string]$entry.identity_cluster_id
            canonical_name = [string]$entry.canonical_name
            queue_status = $status
            decision = if ($status -eq 'VERIFIED') { 'PRODUCTIVE_UPSERT_ALLOWED' } elseif ($status -eq 'PENDING') { 'PENDING_VERIFICATION' } elseif ($status -eq 'RETRY_SCHEDULED') { 'RETRY_DEFERRED' } else { 'FAIL_CLOSED_REVIEW_OR_REJECT' }
            reason = if (-not [string]::IsNullOrWhiteSpace([string]$entry.review_reason)) { [string]$entry.review_reason } else { [string]$entry.last_reason }
            retry_count = [int]$entry.retry_count
            next_attempt_at = $entry.next_attempt_at
            last_status = $entry.last_status
        }
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-decision-report/v1'
        queue_total = @($entries).Count
        productive_upsert_allowed_total = @($decisionItems | Where-Object { [string]$_.decision -eq 'PRODUCTIVE_UPSERT_ALLOWED' }).Count
        pending_total = @($decisionItems | Where-Object { [string]$_.decision -eq 'PENDING_VERIFICATION' }).Count
        retry_deferred_total = @($decisionItems | Where-Object { [string]$_.decision -eq 'RETRY_DEFERRED' }).Count
        fail_closed_total = @($decisionItems | Where-Object { [string]$_.decision -eq 'FAIL_CLOSED_REVIEW_OR_REJECT' }).Count
        review_items = @($decisionItems | Where-Object { [string]$_.queue_status -eq 'MANUAL_REVIEW_REQUIRED' } | Sort-Object canonical_name, candidate_id | Select-Object -First $MaxItems)
        reject_items = @($decisionItems | Where-Object { [string]$_.queue_status -in @('RETRY_SCHEDULED', 'RETRY_EXHAUSTED') } | Sort-Object canonical_name, candidate_id | Select-Object -First $MaxItems)
        items = @($decisionItems | Sort-Object decision, canonical_name, candidate_id | Select-Object -First $MaxItems)
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
    $staleness = @{}
    $refreshReason = @{}
    foreach ($metric in @($CompanyMetrics)) {
        Add-JobAgentCoverageCount -Counts $verification -Key $metric.verification_status
        Add-JobAgentCoverageCount -Counts $inventory -Key $metric.inventory_state
        Add-JobAgentCoverageCount -Counts $industry -Key $metric.industry
        Add-JobAgentCoverageCount -Counts $sourceType -Key $metric.discovery_type
        Add-JobAgentCoverageCount -Counts $sourceOrigin -Key $metric.discovery_origin
        Add-JobAgentCoverageCount -Counts $staleness -Key $metric.staleness_status
        Add-JobAgentCoverageCount -Counts $refreshReason -Key $metric.refresh_reason
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
        by_staleness_status = ConvertTo-JobAgentCoverageCountsObject -Counts $staleness
        by_refresh_reason = ConvertTo-JobAgentCoverageCountsObject -Counts $refreshReason
    }
}

function Get-JobAgentCoverageCandidateSourceEvidence {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter()][AllowNull()][object]$Source = $null
    )

    $evidenceUrl = foreach ($name in @('observed_url', 'posting_url', 'source_page')) {
        $value = Get-JobAgentCoverageProperty -Object $Candidate -Name $name
        if (Test-JobAgentCoverageHttpUrl -Url $value) {
            [string]$value
            break
        }
    }
    [pscustomobject]@{
        source_id = [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'source_id' -Default 'UNKNOWN')
        source_class = if ($null -eq $Source) { [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'source_class' -Default 'UNKNOWN') } else { [string](Get-JobAgentCoverageProperty -Object $Source -Name 'source_class' -Default 'UNKNOWN') }
        evidence_level = if ($null -eq $Source) { [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'officialness_level' -Default 'DISCOVERY_HINT') } else { [string](Get-JobAgentCoverageProperty -Object $Source -Name 'evidence_level' -Default 'DISCOVERY_HINT') }
        observed_url = $evidenceUrl
        observed_at = [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'observed_at' -Default $null)
        record_hash = [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'source_record_hash' -Default (Get-JobAgentCoverageProperty -Object (Get-JobAgentCoverageProperty -Object $Candidate -Name 'source_snapshot') -Name 'record_hash' -Default $null))
        allowed_use = if ($null -eq $Source) { $null } else { [string](Get-JobAgentCoverageProperty -Object $Source -Name 'allowed_use' -Default $null) }
        rate_limit_policy = if ($null -eq $Source) { $null } else { [string](Get-JobAgentCoverageProperty -Object $Source -Name 'rate_limit_policy' -Default $null) }
    }
}

function Get-JobAgentCoverageCandidateReviewAction {
    param(
        [Parameter(Mandatory)][object]$Cluster,
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][string[]]$ReasonCodes,
        [Parameter(Mandatory)][string]$FreshnessStatus
    )

    if ($ReasonCodes -contains 'DUPLICATE_CLUSTER_REVIEW' -or $ReasonCodes -contains 'NAME_CONFLICT_REVIEW') {
        return 'REJECT_DUPLICATE'
    }
    if ($ReasonCodes -contains 'TARGET_AREA_UNCERTAIN' -or $ReasonCodes -contains 'OUT_OF_SCOPE_HINT') {
        return 'CHECK_LOCATION'
    }
    if ($ReasonCodes -contains 'STAFFING_AGENCY_REVIEW') {
        return 'MANUAL_DECISION'
    }
    if ($FreshnessStatus -in @('EXPIRED', 'REFRESH_DUE')) {
        return 'WAIT_FOR_REFRESH'
    }
    return 'VERIFY_OFFICIAL_SITE'
}

function New-JobAgentCoverageCandidateReviewQueueEntry {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$Cluster,
        [Parameter()][AllowNull()][object]$Source = $null,
        [Parameter()][AllowNull()][object]$Previous = $null,
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 30
    )

    $candidateId = [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'candidate_id' -Default (Get-JobAgentCoverageProperty -Object $Candidate -Name 'hint_id' -Default 'UNKNOWN'))
    $sourceClass = if ($null -eq $Source) { [string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'source_class' -Default 'DISCOVERY_HINT') } else { [string](Get-JobAgentCoverageProperty -Object $Source -Name 'source_class' -Default 'DISCOVERY_HINT') }
    $freshness = New-JobAgentCoverageFreshnessRecord -Now $Now -LastImportedAt (Get-JobAgentCoverageProperty -Object $Candidate -Name 'observed_at') -LastVerifiedAt $null -NextRefreshAt $null -ExpiresAfterDays (Get-JobAgentCoveragePolicyDays -Kind $sourceClass -DefaultDays $StaleAfterDays) -RefreshReason 'candidate_source_refresh'
    $reasonCodes = [System.Collections.Generic.List[string]]::new()
    foreach ($flag in @($Cluster.conflict_flags)) { if (-not [string]::IsNullOrWhiteSpace([string]$flag)) { $reasonCodes.Add([string]$flag) } }
    if (@($Cluster.candidate_ids).Count -gt 1) { $reasonCodes.Add('DUPLICATE_CLUSTER_REVIEW') }
    if ([string]$Cluster.review_queue_reason -eq 'OFFICIAL_VERIFICATION_REQUIRED' -or [string]$Cluster.review_queue_reason -eq 'READY_FOR_OFFICIAL_VERIFICATION') { $reasonCodes.Add('OFFICIAL_VERIFICATION_REQUIRED') }
    if ([string]$freshness.staleness_status -in @('EXPIRED', 'REFRESH_DUE')) { $reasonCodes.Add('CANDIDATE_REFRESH_DUE') }
    if ([string](Get-JobAgentCoverageProperty -Object $Candidate -Name 'known_company_id' -Default '') -ne '') { $reasonCodes.Add('KNOWN_COMPANY_HINT') }
    $reasonArray = @($reasonCodes.ToArray() | Sort-Object -Unique)
    $nextAction = Get-JobAgentCoverageCandidateReviewAction -Cluster $Cluster -Candidate $Candidate -ReasonCodes $reasonArray -FreshnessStatus ([string]$freshness.staleness_status)
    $basePriority = [int](Get-JobAgentCoverageProperty -Object $Candidate -Name 'confidence_score' -Default (Get-JobAgentCoverageProperty -Object $Candidate -Name 'priority_score' -Default 50))
    $areaBonus = if (@($Cluster.target_area_basis) -contains 'JOB_LOCATION_IN_TARGET') { 12 } elseif (@($Cluster.target_area_basis) -contains 'REGISTER_SEAT_IN_TARGET') { 10 } elseif (@($Cluster.target_area_basis) -contains 'BRANCH_HINT_IN_TARGET') { 8 } else { -20 }
    $sourceBonus = switch ($sourceClass) {
        'OPEN_REGISTER_DUMP' { 10; break }
        'REGIONAL_DIRECTORY' { 8; break }
        'PUBLIC_INSTITUTION_DIRECTORY' { 8; break }
        'JOB_BOARD_DISCOVERY' { 4; break }
        default { 0 }
    }
    $riskPenalty = if ($reasonArray -contains 'STAFFING_AGENCY_REVIEW') { 25 } elseif ($reasonArray -contains 'TARGET_AREA_UNCERTAIN') { 18 } elseif ($reasonArray -contains 'DUPLICATE_CLUSTER_REVIEW') { 8 } else { 0 }
    $priority = [Math]::Max(0, [Math]::Min(100, $basePriority + $areaBonus + $sourceBonus + ([int]$Cluster.source_count * 3) - $riskPenalty))
    $status = if ($nextAction -eq 'VERIFY_OFFICIAL_SITE') { 'PENDING' } elseif ($nextAction -eq 'WAIT_FOR_REFRESH') { 'RETRY_SCHEDULED' } else { 'MANUAL_REVIEW_REQUIRED' }
    if ($null -ne $Previous -and [string](Get-JobAgentCoverageProperty -Object $Previous -Name 'status' -Default '') -in @('VERIFIED', 'RETRY_EXHAUSTED')) {
        $status = [string]$Previous.status
    }

    [pscustomobject]@{
        identity_cluster_id = [string]$Cluster.identity_cluster_id
        candidate_id = $candidateId
        candidate_ids = @($Cluster.candidate_ids)
        canonical_name = [string]$Cluster.canonical_name
        source_count = [int]$Cluster.source_count
        priority_score = $priority
        next_action = $nextAction
        reason_codes = $reasonArray
        target_area_basis = @($Cluster.target_area_basis)
        status = $status
        review_reason = if ($reasonArray.Count -gt 0) { $reasonArray -join ',' } else { [string]$Cluster.review_queue_reason }
        retry_count = if ($null -eq $Previous) { 0 } else { [int](Get-JobAgentCoverageProperty -Object $Previous -Name 'retry_count' -Default 0) }
        last_attempt_at = if ($null -eq $Previous) { $null } else { Get-JobAgentCoverageProperty -Object $Previous -Name 'last_attempt_at' -Default $null }
        next_attempt_at = if ($status -eq 'PENDING') { $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture) } else { Get-JobAgentCoverageProperty -Object $Previous -Name 'next_attempt_at' -Default $null }
        last_status = if ($null -eq $Previous) { $null } else { Get-JobAgentCoverageProperty -Object $Previous -Name 'last_status' -Default $null }
        last_reason = if ($null -eq $Previous) { $null } else { Get-JobAgentCoverageProperty -Object $Previous -Name 'last_reason' -Default $null }
        freshness_status = [string]$freshness.staleness_status
        risk_level = if ($reasonArray -contains 'STAFFING_AGENCY_REVIEW' -or $reasonArray -contains 'TARGET_AREA_UNCERTAIN') { 'HIGH' } elseif ($reasonArray -contains 'DUPLICATE_CLUSTER_REVIEW') { 'MEDIUM' } else { 'LOW' }
        source_evidence = Get-JobAgentCoverageCandidateSourceEvidence -Candidate $Candidate -Source $Source
        dedupe_context = [pscustomobject]@{
            dedupe_keys = @($Cluster.dedupe_keys)
            conflict_flags = @($Cluster.conflict_flags)
            cluster_candidate_count = @($Cluster.candidate_ids).Count
        }
    }
}

function New-JobAgentCoverageCandidateReviewQueue {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][AllowNull()][object]$SourceRegistry = $null,
        [Parameter()][AllowNull()][object]$PreviousQueue = $null,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 30,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxItems = 250
    )

    if ($null -eq $HintStore) {
        return [pscustomobject]@{
            schema_version = 'jobagent/company-candidate-verification-queue/v1'
            queue_type = 'review'
            generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            clusters_total = 0
            candidates_total = 0
            ready_total = 0
            action_counts = [pscustomobject]@{}
            queue = @()
        }
    }

    $sourceById = @{}
    if ($null -ne $SourceRegistry) {
        foreach ($source in @($SourceRegistry.items)) {
            $sourceId = [string](Get-JobAgentCoverageProperty -Object $source -Name 'source_id' -Default '')
            if (-not [string]::IsNullOrWhiteSpace($sourceId)) { $sourceById[$sourceId] = $source }
        }
    }
    $previousByCandidate = @{}
    if ($null -ne $PreviousQueue) {
        foreach ($entry in @($PreviousQueue.queue)) {
            $candidateId = [string](Get-JobAgentCoverageProperty -Object $entry -Name 'candidate_id' -Default '')
            if (-not [string]::IsNullOrWhiteSpace($candidateId)) { $previousByCandidate[$candidateId] = $entry }
        }
    }

    $clusterReport = Resolve-JobAgentCompanyCandidateClusters -Candidates @($HintStore.hints) -ObservedAt $Now
    $candidateById = @{}
    foreach ($candidate in @($HintStore.hints)) {
        $candidateId = [string](Get-JobAgentCoverageProperty -Object $candidate -Name 'hint_id' -Default (Get-JobAgentCoverageProperty -Object $candidate -Name 'candidate_id' -Default ''))
        if (-not [string]::IsNullOrWhiteSpace($candidateId)) { $candidateById[$candidateId] = $candidate }
    }
    $entries = foreach ($cluster in @($clusterReport.clusters)) {
        $primaryCandidateId = [string](@($cluster.candidate_ids | Sort-Object)[0])
        $candidate = if ($candidateById.ContainsKey($primaryCandidateId)) { $candidateById[$primaryCandidateId] } else { $cluster.candidates[0] }
        $sourceId = [string](Get-JobAgentCoverageProperty -Object $candidate -Name 'source_id' -Default '')
        $source = if ($sourceById.ContainsKey($sourceId)) { $sourceById[$sourceId] } else { $null }
        $previous = if ($previousByCandidate.ContainsKey($primaryCandidateId)) { $previousByCandidate[$primaryCandidateId] } else { $null }
        New-JobAgentCoverageCandidateReviewQueueEntry -Candidate $candidate -Cluster $cluster -Source $source -Previous $previous -Now $Now -StaleAfterDays $StaleAfterDays
    }
    $sortedEntries = @($entries | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, next_action, canonical_name, candidate_id | Select-Object -First $MaxItems)
    $actionCounts = @{}
    foreach ($entry in $sortedEntries) { Add-JobAgentCoverageCount -Counts $actionCounts -Key $entry.next_action }
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        queue_type = 'review'
        generated_at = $Now.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        clusters_total = [int]$clusterReport.clusters_total
        candidates_total = [int]$clusterReport.candidates_total
        ready_total = @($sortedEntries | Where-Object { [string]$_.status -eq 'PENDING' }).Count
        action_counts = ConvertTo-JobAgentCoverageCountsObject -Counts $actionCounts
        queue = $sortedEntries
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

function Get-JobAgentCoverageWaveCandidateSortKey {
    param([Parameter(Mandatory)][object]$Candidate)

    $rank = if ([string]$Candidate.review_status -eq 'CAREER_URL_VERIFIED') { '0' } else { '1' }
    return '{0}|{1}' -f $rank, [string]$Candidate.company
}

function New-JobAgentCoverageImportWavePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CompanyMetrics,
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][AllowNull()][object]$WaveConfig = $null,
        [Parameter()][ValidateRange(1, 100)][int]$MaxCandidatesPerWave = 12
    )

    $waveDefinitions = if ($null -ne $WaveConfig -and @($WaveConfig.waves).Count -gt 0) {
        @($WaveConfig.waves | ForEach-Object {
                [pscustomobject]@{
                    wave_id = [string]$_.wave_id
                    title = [string]$_.title
                    milestone = 'M5-' + [string]$_.wave_id
                    dependency = 'JA-023 bis JA-028'
                    priority_score = switch ([string]$_.wave_id) {
                        'A' { 100; break }
                        'B' { 92; break }
                        'C' { 84; break }
                        'D' { 76; break }
                        default { 60 }
                    }
                    target_size = [int](Get-JobAgentCoverageProperty -Object $_ -Name 'target_size' -Default 0)
                    allowed_verification_statuses = @($_.allowed_verification_statuses | ForEach-Object { [string]$_ })
                    productive_upsert_allowed = [bool](Get-JobAgentCoverageProperty -Object $_ -Name 'productive_upsert_allowed' -Default $true)
                }
            })
    }
    else {
        @(
            [pscustomobject]@{ wave_id = 'A'; title = 'Grosse regionale Arbeitgeber und boersennotierte Unternehmen'; milestone = 'M5-A'; dependency = 'JA-024/JA-026'; priority_score = 100; target_size = 250; allowed_verification_statuses = @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED'); productive_upsert_allowed = $true }
            [pscustomobject]@{ wave_id = 'B'; title = 'Freising, Weihenstephan und Flughafen-Umfeld'; milestone = 'M5-B'; dependency = 'JA-024/JA-026'; priority_score = 92; target_size = 750; allowed_verification_statuses = @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED'); productive_upsert_allowed = $true }
            [pscustomobject]@{ wave_id = 'C'; title = 'EMM-Mitglieder, Branchencluster und oeffentliche Institutionen'; milestone = 'M5-C'; dependency = 'JA-023'; priority_score = 84; target_size = 1500; allowed_verification_statuses = @('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED'); productive_upsert_allowed = $true }
            [pscustomobject]@{ wave_id = 'D'; title = 'BA, EURES und Make-it-in-Germany-Hints'; milestone = 'M5-D'; dependency = 'JA-025'; priority_score = 76; target_size = 0; allowed_verification_statuses = @(); productive_upsert_allowed = $false }
            [pscustomobject]@{ wave_id = 'E'; title = 'Startup-, Scaleup- und manuelle Review-Reste'; milestone = 'M5-E'; dependency = 'JA-027 Coverage-Audit'; priority_score = 68; target_size = 0; allowed_verification_statuses = @(); productive_upsert_allowed = $false }
        )
    }

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
            Sort-Object -Property { Get-JobAgentCoverageWaveCandidateSortKey -Candidate $_ } |
            Select-Object -First $MaxCandidatesPerWave)
        $waves.Add([pscustomobject]@{
                wave_id = [string]$definition.wave_id
                title = [string]$definition.title
                dependency = [string]$definition.dependency
                priority_score = [int]$definition.priority_score
                milestone = [string]$definition.milestone
                target_size = [int]$definition.target_size
                productive_upsert_allowed = [bool]$definition.productive_upsert_allowed
                candidates_total = @($allCandidates).Count
                candidates = @($allCandidates)
            })
    }

    [pscustomobject]@{
        contract = 'Importwellen sind operative Kandidatenlisten; unverifizierte Hints bleiben ausserhalb des Firmenbestands, bis offizielle Website oder Karriere-URL belegt ist.'
        waves = @($waves.ToArray())
    }
}

function New-JobAgentCoverageImportWaveMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ImportWavePlan,
        [Parameter()][AllowEmptyCollection()][object[]]$GateHistory = @()
    )

    $waves = foreach ($wave in @($ImportWavePlan.waves)) {
        $candidates = @($wave.candidates)
        $companyCandidates = @($candidates | Where-Object { [string]$_.kind -eq 'company' })
        $hintCandidates = @($candidates | Where-Object { [string]$_.kind -ne 'company' })
        $verifiedCandidates = @($companyCandidates | Where-Object { [string]$_.verification_status -in @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') })
        $reviewCandidates = @($candidates | Where-Object {
                [string]$_.review_status -in @('MANUAL_REVIEW_REQUIRED', 'DISCOVERY_HINT', 'REGISTER_DISCOVERY_HINT', 'REGIONAL_DISCOVERY_HINT') -or
                [string]$_.verification_status -eq 'UNVERIFIED'
            })
        $scannableCandidates = @($companyCandidates | Where-Object { [string]$_.verification_status -in @('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') })
        $latestGate = @($GateHistory |
            Where-Object { [string]$_.wave_id -eq [string]$wave.wave_id } |
            Sort-Object ts |
            Select-Object -Last 1)
        $gateMetrics = if ($latestGate.Count -eq 1) { Get-JobAgentCoverageProperty -Object $latestGate[0] -Name 'metrics' } else { $null }
        $targetSize = [int](Get-JobAgentCoverageProperty -Object $wave -Name 'target_size' -Default 0)
        $acceptedTotal = if ($null -ne $gateMetrics) { [int](Get-JobAgentCoverageProperty -Object $gateMetrics -Name 'added' -Default 0) } else { $verifiedCandidates.Count }
        $rejectedTotal = if ($null -ne $gateMetrics) { [int](Get-JobAgentCoverageProperty -Object $gateMetrics -Name 'deduplicated' -Default 0) + [int](Get-JobAgentCoverageProperty -Object $gateMetrics -Name 'manual_review_required' -Default 0) } else { $reviewCandidates.Count }
        $denominator = [math]::Max(1, $acceptedTotal + $rejectedTotal)

        [pscustomobject]@{
            wave_id = [string]$wave.wave_id
            title = [string]$wave.title
            target_size = $targetSize
            candidates_total = $candidates.Count
            companies_total = $companyCandidates.Count
            verified_total = $verifiedCandidates.Count
            hint_only_total = $hintCandidates.Count
            review_total = $reviewCandidates.Count
            scannable_total = $scannableCandidates.Count
            accepted_total = $acceptedTotal
            rejected_total = $rejectedTotal
            acceptance_rate = [Math]::Round([double]$acceptedTotal / [double]$denominator, 4)
            duplicate_rate = if ($null -eq $gateMetrics) { 0.0 } else { [double](Get-JobAgentCoverageProperty -Object $gateMetrics -Name 'duplicate_rate' -Default 0.0) }
            verification_rate = [Math]::Round([double]$verifiedCandidates.Count / [double][math]::Max(1, $companyCandidates.Count), 4)
            scan_readiness_rate = [Math]::Round([double]$scannableCandidates.Count / [double][math]::Max(1, $companyCandidates.Count), 4)
            coverage_delta = if ($null -eq $gateMetrics) { 0 } else { [int](Get-JobAgentCoverageProperty -Object $gateMetrics -Name 'coverage_delta' -Default 0) }
            latest_gate_status = if ($latestGate.Count -eq 1) { [string]$latestGate[0].status } else { 'not-run' }
            latest_backup_path = if ($latestGate.Count -eq 1) { [string]$latestGate[0].backup_path } else { $null }
            latest_reject_reasons = if ($latestGate.Count -eq 1) { @($latestGate[0].violations | ForEach-Object { [string]$_ }) } else { @() }
            remaining_to_target = if ($targetSize -le 0) { 0 } else { [math]::Max(0, $targetSize - $acceptedTotal) }
        }
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-import-wave-metrics/v1'
        waves_total = @($waves).Count
        target_size_total = (@($waves) | Measure-Object -Property target_size -Sum).Sum
        candidates_total = (@($waves) | Measure-Object -Property candidates_total -Sum).Sum
        verified_total = (@($waves) | Measure-Object -Property verified_total -Sum).Sum
        hint_only_total = (@($waves) | Measure-Object -Property hint_only_total -Sum).Sum
        review_total = (@($waves) | Measure-Object -Property review_total -Sum).Sum
        scannable_total = (@($waves) | Measure-Object -Property scannable_total -Sum).Sum
        waves = @($waves)
    }
}

function New-JobAgentCoverageReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][AllowNull()][object]$SourceRegistry = $null,
        [Parameter()][AllowNull()][object]$HintStore = $null,
        [Parameter()][AllowNull()][object]$CandidateVerificationQueue = $null,
        [Parameter()][AllowNull()][object]$WaveConfig = $null,
        [Parameter()][AllowEmptyCollection()][object[]]$WaveGateHistory = @(),
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxPriorityItems = 25
    )

    $latestAttempts = Get-JobAgentCoverageLatestAttemptMap -Document $Document
    $jobsByCompany = Get-JobAgentCoverageJobsByCompany -Document $Document
    $sourcesByCompany = Get-JobAgentCoverageSourcesByCompany -Document $Document
    $metrics = foreach ($company in @($Document.companies)) {
        $companyId = [string]$company.company_id
        $latestAttempt = if ($latestAttempts.ContainsKey($companyId)) { $latestAttempts[$companyId] } else { $null }
        $jobs = if ($jobsByCompany.ContainsKey($companyId)) { @($jobsByCompany[$companyId].ToArray()) } else { @() }
        $jobSources = if ($sourcesByCompany.ContainsKey($companyId)) { @($sourcesByCompany[$companyId].ToArray()) } else { @() }
        Get-JobAgentCoverageCompanyMetric -Company $company -LatestAttempt $latestAttempt -Jobs $jobs -JobSources $jobSources -Now $Now -StaleAfterDays $StaleAfterDays
    }

    $metricsArray = @($metrics)
    $candidateClusters = New-JobAgentCoverageCandidateClusterReport -HintStore $HintStore -Now $Now -MaxReviewItems $MaxPriorityItems
    $candidateFreshness = New-JobAgentCoverageCandidateFreshnessReport -HintStore $HintStore -Now $Now -MaxItems $MaxPriorityItems
    $candidateReviewQueue = New-JobAgentCoverageCandidateReviewQueue -HintStore $HintStore -SourceRegistry $SourceRegistry -PreviousQueue $CandidateVerificationQueue -Now $Now -StaleAfterDays $StaleAfterDays -MaxItems $MaxPriorityItems
    $candidateVerificationDecisionReport = New-JobAgentCoverageCandidateVerificationDecisionReport -CandidateVerificationQueue $CandidateVerificationQueue -MaxItems $MaxPriorityItems
    $importWavePlan = New-JobAgentCoverageImportWavePlan -CompanyMetrics $metricsArray -HintStore $HintStore -WaveConfig $WaveConfig
    $sourceInventory = New-JobAgentSourceInventoryReport -Document $Document -SourceRegistry $SourceRegistry -HintStore $HintStore -Now $Now -StaleAfterDays $StaleAfterDays
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
            company_refresh_due = @($metricsArray | Where-Object { [string]$_.staleness_status -in @('REFRESH_DUE', 'EXPIRED', 'UNKNOWN') }).Count
            company_fresh = @($metricsArray | Where-Object { [string]$_.staleness_status -eq 'FRESH' }).Count
            candidate_refresh_due = $candidateFreshness.refresh_due_total
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
            candidate_verification_queue_total = @($candidateReviewQueue.queue).Count
            candidate_verification_ready = @($candidateReviewQueue.queue | Where-Object { [string]$_.status -in @('PENDING', 'RETRY_SCHEDULED') }).Count
            candidate_verification_verified = @($candidateReviewQueue.queue | Where-Object { [string]$_.status -eq 'VERIFIED' }).Count
            candidate_verification_manual_review = @($candidateReviewQueue.queue | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count
            candidate_verification_retry_exhausted = @($candidateReviewQueue.queue | Where-Object { [string]$_.status -eq 'RETRY_EXHAUSTED' }).Count
            sources_total = $sourceInventory.sources_total
            official_sources = $sourceInventory.official_sources
            career_sources = $sourceInventory.career_sources
            ats_sources = $sourceInventory.ats_sources
            discovery_sources = $sourceInventory.discovery_sources
            verified_sources = $sourceInventory.verified_sources
            unverified_sources = $sourceInventory.unverified_sources
            blocked_sources = $sourceInventory.blocked_sources
            retry_open_sources = $sourceInventory.retry_open_sources
            sources_attempted_latest_run = $sourceInventory.attempted_latest_run
            sources_succeeded_latest_run = $sourceInventory.scan_succeeded_latest_run
            sources_failed_latest_run = $sourceInventory.scan_failed_latest_run
            never_scanned_sources = $sourceInventory.never_scanned_sources
            stale_sources = $sourceInventory.stale_sources
        }
        dimensions = New-JobAgentCoverageDimensions -CompanyMetrics $metricsArray
        companies = @($metricsArray | Sort-Object company)
        duplicates = @(Get-JobAgentCoverageDuplicateGroups -Document $Document)
        backlog = @(Get-JobAgentCoverageBacklog -CompanyMetrics $metricsArray)
        scan_priority = @(Get-JobAgentCoverageScanPriority -CompanyMetrics $metricsArray -MaxCompanies $MaxPriorityItems)
        source_coverage = if ($null -eq $SourceRegistry) { $null } else { New-JobAgentDiscoverySourceCoverageReport -SourceRegistry $SourceRegistry -Now $Now }
        source_inventory = $sourceInventory
        candidate_clusters = $candidateClusters
        candidate_freshness = $candidateFreshness
        candidate_verification_queue = $candidateReviewQueue
        candidate_verification_decision_report = $candidateVerificationDecisionReport
        import_waves = $importWavePlan
        import_wave_metrics = New-JobAgentCoverageImportWaveMetrics -ImportWavePlan $importWavePlan -GateHistory $WaveGateHistory
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentCoverageBacklog',
    'Get-JobAgentCoverageCompanyLinks',
    'Get-JobAgentCoverageScanPriority',
    'Get-JobAgentCoverageDuplicateGroups',
    'New-JobAgentCoverageCandidateClusterReport',
    'New-JobAgentCoverageCandidateFreshnessReport',
    'New-JobAgentCoverageCandidateReviewQueue',
    'New-JobAgentCoverageCandidateVerificationDecisionReport',
    'New-JobAgentDiscoverySourceCoverageReport',
    'New-JobAgentCoverageDimensions',
    'New-JobAgentCoverageImportWavePlan',
    'New-JobAgentCoverageImportWaveMetrics',
    'New-JobAgentSourceInventoryReport',
    'New-JobAgentCoverageReport'
)
