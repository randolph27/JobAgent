#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentAsciiSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $normalized = $Value.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $slug = [regex]::Replace($normalized, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Slug-Wert darf nicht leer sein.'
    }
    return $slug
}

function ConvertTo-JobAgentCompanyNameKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $value = $Name.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $value = [regex]::Replace($value, '\b(gmbh\s+and\s+co\.?\s+kg|gmbh\s+und\s+co\.?\s+kg|gmbh|ag|se|kg|kgaa|inc|ltd|llc)\b', ' ')
    $value = [regex]::Replace($value, '[^a-z0-9]+', ' ').Trim()
    return [regex]::Replace($value, '\s+', ' ')
}

function ConvertTo-JobAgentCanonicalDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$UrlOrDomain
    )

    $value = $UrlOrDomain.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Domain darf nicht leer sein.'
    }

    if ($value -match '^https?://') {
        $uri = [Uri]$value
        $value = $uri.Host
    }
    $value = $value -replace '^www\.', ''
    if ($value -notmatch '^[a-z0-9.-]+\.[a-z]{2,}$') {
        throw "Ungueltige Domain: $UrlOrDomain"
    }
    return $value
}

function New-JobAgentTargetLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$City,
        [Parameter(Mandatory)][ValidateSet('MUNICH', 'MUNICH_20KM', 'FREISING', 'REMOTE_WITH_TARGET_REFERENCE', 'UNKNOWN', 'OUT_OF_SCOPE')][string]$TargetArea
    )

    [pscustomobject]@{
        label = $Label
        city = $City
        region = 'Bayern'
        country = 'DE'
        target_area = $TargetArea
    }
}

function New-JobAgentDiscoverySource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('OFFICIAL_WEBSITE', 'MANUAL_REVIEW', 'DISCOVERY_HINT')][string]$Type,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][datetime]$ObservedAt,
        [Parameter()][AllowNull()][string]$VerificationUrl = $null,
        [Parameter()][string]$DiscoveryOrigin = 'seed.manual',
        [Parameter()][ValidateSet('MUNICH', 'MUNICH_20KM', 'FREISING', 'REMOTE_WITH_TARGET_REFERENCE', 'UNKNOWN', 'OUT_OF_SCOPE')][string]$TargetArea = 'UNKNOWN',
        [Parameter()][string]$IndustryHint = 'UNKNOWN',
        [Parameter()][string]$EvidenceNote = 'Offizielle Firmenquelle wurde manuell gepflegt.'
    )

    [pscustomobject]@{
        type = $Type
        url = $Url
        observed_at = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        verification_url = if ([string]::IsNullOrWhiteSpace($VerificationUrl)) { $null } else { $VerificationUrl }
        discovery_origin = $DiscoveryOrigin
        target_area = $TargetArea
        industry_hint = $IndustryHint
        evidence_note = $EvidenceNote
    }
}

function New-JobAgentCompanySeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CanonicalName,
        [Parameter(Mandatory)][string]$OfficialWebsiteUrl,
        [Parameter()][AllowNull()][string]$CareerUrl,
        [Parameter()][string[]]$Aliases = @(),
        [Parameter(Mandatory)][object[]]$Locations,
        [Parameter(Mandatory)][string]$Industry,
        [Parameter(Mandatory)][ValidateRange(1, 100)][int]$ScanPriority,
        [Parameter(Mandatory)][string]$DiscoverySourceUrl,
        [Parameter()][ValidateSet('OFFICIAL_WEBSITE', 'MANUAL_REVIEW', 'DISCOVERY_HINT')][string]$DiscoverySourceType = 'OFFICIAL_WEBSITE',
        [Parameter()][string]$DiscoveryOrigin = 'seed.manual',
        [Parameter()][string]$DiscoveryEvidenceNote = 'Offizielle Firmenquelle wurde manuell gepflegt.',
        [Parameter()][AllowNull()][string]$DiscoveryVerificationUrl,
        [Parameter()][ValidateSet('COMPANY_DOMAIN_VERIFIED', 'CAREER_URL_VERIFIED', 'UNVERIFIED')][string]$VerificationStatus,
        [Parameter()][object[]]$Ats = @(),
        [Parameter()][datetime]$CreatedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$NextScanAt = ([datetime]::UtcNow.Date.AddDays(1))
    )

    $domain = ConvertTo-JobAgentCanonicalDomain -UrlOrDomain $OfficialWebsiteUrl
    $id = 'company:' + (ConvertTo-JobAgentAsciiSlug -Value $CanonicalName)
    $career = if ([string]::IsNullOrWhiteSpace($CareerUrl)) { $null } else { $CareerUrl }
    $verificationStatus = if ($PSBoundParameters.ContainsKey('VerificationStatus')) {
        $VerificationStatus
    }
    elseif ($null -eq $career) {
        'COMPANY_DOMAIN_VERIFIED'
    }
    else {
        'CAREER_URL_VERIFIED'
    }
    $discoveryVerificationUrl = if ($PSBoundParameters.ContainsKey('DiscoveryVerificationUrl')) {
        if ([string]::IsNullOrWhiteSpace($DiscoveryVerificationUrl)) { $null } else { $DiscoveryVerificationUrl }
    }
    elseif ($null -eq $career) {
        $OfficialWebsiteUrl
    }
    else {
        $career
    }
    $targetArea = @($Locations | ForEach-Object { [string]$_.target_area } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)

    [pscustomobject]@{
        company_id = $id
        canonical_name = $CanonicalName
        canonical_domain = $domain
        official_website_url = $OfficialWebsiteUrl
        career_url = $career
        aliases = @($Aliases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        locations = @($Locations)
        industry = $Industry
        ats = @($Ats)
        scan_status = 'PENDING'
        scan_priority = $ScanPriority
        next_scan_at = $NextScanAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        verification_status = $verificationStatus
        discovery_source = New-JobAgentDiscoverySource `
            -Type $DiscoverySourceType `
            -Url $DiscoverySourceUrl `
            -ObservedAt $CreatedAt `
            -VerificationUrl $discoveryVerificationUrl `
            -DiscoveryOrigin $DiscoveryOrigin `
            -TargetArea $(if ($targetArea.Count -gt 0) { [string]$targetArea[0] } else { 'UNKNOWN' }) `
            -IndustryHint $Industry `
            -EvidenceNote $DiscoveryEvidenceNote
        created_at = $CreatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        updated_at = $CreatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        last_successful_scan_at = $null
    }
}

function Get-JobAgentCompanySeedInventory {
    [CmdletBinding()]
    param(
        [Parameter()][datetime]$CreatedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$NextScanAt = ([datetime]::UtcNow.Date.AddDays(1))
    )

    $munich = New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH'
    $freising = New-JobAgentTargetLocation -Label 'Freising' -City 'Freising' -TargetArea 'FREISING'
    $munichAirport = New-JobAgentTargetLocation -Label 'Flughafen Muenchen / Freising' -City 'Freising' -TargetArea 'FREISING'

    @(
        New-JobAgentCompanySeed -CanonicalName 'BMW Group' -OfficialWebsiteUrl 'https://www.bmwgroup.com/' -CareerUrl 'https://www.bmwgroup.jobs/de/en.html' -Aliases @('Bayerische Motoren Werke', 'BMW AG') -Locations @($munich) -Industry 'Automotive' -ScanPriority 95 -DiscoverySourceUrl 'https://www.bmwgroup.jobs/de/en.html' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Siemens AG' -OfficialWebsiteUrl 'https://www.siemens.com/' -CareerUrl 'https://jobs.siemens.com/' -Aliases @('Siemens') -Locations @($munich) -Industry 'Industrial Technology' -ScanPriority 94 -DiscoverySourceUrl 'https://jobs.siemens.com/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Allianz SE' -OfficialWebsiteUrl 'https://www.allianz.com/' -CareerUrl 'https://careers.allianz.com/' -Aliases @('Allianz') -Locations @($munich) -Industry 'Insurance' -ScanPriority 92 -DiscoverySourceUrl 'https://careers.allianz.com/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Munich Re' -OfficialWebsiteUrl 'https://www.munichre.com/' -CareerUrl 'https://careers.munichre.com/' -Aliases @('Muenchener Rueck', 'Muenchener Rueckversicherungs-Gesellschaft') -Locations @($munich) -Industry 'Insurance' -ScanPriority 91 -DiscoverySourceUrl 'https://careers.munichre.com/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Rohde & Schwarz GmbH & Co. KG' -OfficialWebsiteUrl 'https://www.rohde-schwarz.com/' -CareerUrl 'https://www.rohde-schwarz.com/us/career/jobs/career-jobboard_251573.html' -Aliases @('Rohde Schwarz', 'R&S') -Locations @($munich) -Industry 'Electronics' -ScanPriority 89 -DiscoverySourceUrl 'https://www.rohde-schwarz.com/us/career/jobs/career-jobboard_251573.html' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Infineon Technologies AG' -OfficialWebsiteUrl 'https://www.infineon.com/' -CareerUrl 'https://www.infineon.com/careers' -Aliases @('Infineon') -Locations @($munich) -Industry 'Semiconductors' -ScanPriority 88 -DiscoverySourceUrl 'https://www.infineon.com/careers' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Giesecke+Devrient GmbH' -OfficialWebsiteUrl 'https://www.gi-de.com/' -CareerUrl 'https://careers.gi-de.com/' -Aliases @('Giesecke Devrient', 'G+D') -Locations @($munich) -Industry 'Security Technology' -ScanPriority 86 -DiscoverySourceUrl 'https://careers.gi-de.com/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'MTU Aero Engines AG' -OfficialWebsiteUrl 'https://www.mtu.de/' -CareerUrl 'https://www.mtu.de/careers/' -Aliases @('MTU Aero Engines', 'MTU') -Locations @($munich) -Industry 'Aerospace' -ScanPriority 84 -DiscoverySourceUrl 'https://www.mtu.de/careers/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Flughafen Muenchen GmbH' -OfficialWebsiteUrl 'https://www.munich-airport.com/' -CareerUrl 'https://www.munich-airport.com/careers-263141' -Aliases @('Munich Airport', 'FMG') -Locations @($munichAirport) -Industry 'Airport Operations' -ScanPriority 83 -DiscoverySourceUrl 'https://www.munich-airport.com/careers-263141' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Stadtwerke Muenchen GmbH' -OfficialWebsiteUrl 'https://www.swm.de/' -CareerUrl 'https://www.swm.de/karriere' -Aliases @('SWM', 'Stadtwerke Munchen') -Locations @($munich) -Industry 'Utilities' -ScanPriority 82 -DiscoverySourceUrl 'https://www.swm.de/karriere' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Landeshauptstadt Muenchen' -OfficialWebsiteUrl 'https://stadt.muenchen.de/' -CareerUrl 'https://stadt.muenchen.de/rathaus/karriere.html' -Aliases @('Stadt Muenchen', 'LHM') -Locations @($munich) -Industry 'Public Sector' -ScanPriority 80 -DiscoverySourceUrl 'https://stadt.muenchen.de/rathaus/karriere.html' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
        New-JobAgentCompanySeed -CanonicalName 'Texas Instruments Deutschland GmbH' -OfficialWebsiteUrl 'https://www.ti.com/' -CareerUrl 'https://careers.ti.com/' -Aliases @('Texas Instruments', 'TI') -Locations @($freising) -Industry 'Semiconductors' -ScanPriority 76 -DiscoverySourceUrl 'https://careers.ti.com/' -CreatedAt $CreatedAt -NextScanAt $NextScanAt
    )
}

function Merge-JobAgentCompanyLocations {
    param(
        [Parameter()][object[]]$Existing = @(),
        [Parameter()][object[]]$Seed = @()
    )

    $map = [ordered]@{}
    foreach ($location in @($Existing) + @($Seed)) {
        if ($null -eq $location) {
            continue
        }
        $key = '{0}|{1}|{2}' -f ([string]$location.label), ([string]$location.city), ([string]$location.target_area)
        if (-not $map.Contains($key)) {
            $map[$key] = $location
        }
    }
    return @($map.Values)
}

function Merge-JobAgentCompanyAtsBindings {
    param(
        [Parameter()][object[]]$Existing = @(),
        [Parameter()][object[]]$Seed = @()
    )

    $map = [ordered]@{}
    foreach ($binding in @($Existing) + @($Seed)) {
        if ($null -eq $binding) {
            continue
        }
        $key = '{0}|{1}' -f ([string]$binding.system), ([string]$binding.official_domain)
        if (-not $map.Contains($key)) {
            $map[$key] = $binding
        }
    }
    return @($map.Values)
}

function Get-JobAgentVerificationStatusRank {
    param([Parameter(Mandatory)][string]$Status)

    switch ($Status) {
        'CAREER_URL_VERIFIED' { return 3 }
        'COMPANY_DOMAIN_VERIFIED' { return 2 }
        'UNVERIFIED' { return 1 }
        default { return 0 }
    }
}

function Get-JobAgentPreferredDiscoverySource {
    param(
        [Parameter(Mandatory)][object]$Existing,
        [Parameter(Mandatory)][object]$Seed,
        [Parameter(Mandatory)][string]$VerificationStatus
    )

    if ((Get-JobAgentVerificationStatusRank -Status $VerificationStatus) -ge (Get-JobAgentVerificationStatusRank -Status ([string]$Existing.verification_status))) {
        return $Seed.discovery_source
    }
    return $Existing.discovery_source
}

function Get-JobAgentCompanyIdentityKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company
    )

    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [void]$keys.Add('id:' + [string]$Company.company_id)
    [void]$keys.Add('domain:' + (ConvertTo-JobAgentCanonicalDomain -UrlOrDomain ([string]$Company.canonical_domain)))
    [void]$keys.Add('name:' + (ConvertTo-JobAgentCompanyNameKey -Name ([string]$Company.canonical_name)))
    foreach ($alias in @($Company.aliases)) {
        $aliasKey = ConvertTo-JobAgentCompanyNameKey -Name ([string]$alias)
        if (-not [string]::IsNullOrWhiteSpace($aliasKey)) {
            [void]$keys.Add('name:' + $aliasKey)
        }
    }
    return $keys
}

function Find-JobAgentCompanyDuplicate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Companies,
        [Parameter(Mandatory)][object]$Candidate
    )

    $candidateKeys = Get-JobAgentCompanyIdentityKeys -Company $Candidate
    foreach ($company in @($Companies)) {
        $existingKeys = Get-JobAgentCompanyIdentityKeys -Company $company
        foreach ($key in $candidateKeys) {
            if ($existingKeys.Contains($key)) {
                return [pscustomobject]@{
                    company = $company
                    matched_key = $key
                }
            }
        }
    }
    return $null
}

function Merge-JobAgentCompanySeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Existing,
        [Parameter(Mandatory)][object]$Seed
    )

    $aliases = @($Existing.aliases) + @($Seed.aliases) + @($Existing.canonical_name) + @($Seed.canonical_name) |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Sort-Object -Unique

    $preferredVerificationStatus = if ((Get-JobAgentVerificationStatusRank -Status ([string]$Seed.verification_status)) -ge (Get-JobAgentVerificationStatusRank -Status ([string]$Existing.verification_status))) {
        [string]$Seed.verification_status
    }
    else {
        [string]$Existing.verification_status
    }
    $existingNextScanAt = if ([string]::IsNullOrWhiteSpace([string]$Existing.next_scan_at)) { $null } else { [datetime]::Parse([string]$Existing.next_scan_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
    $seedNextScanAt = if ([string]::IsNullOrWhiteSpace([string]$Seed.next_scan_at)) { $null } else { [datetime]::Parse([string]$Seed.next_scan_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime() }
    $mergedNextScanAt = if ($null -eq $existingNextScanAt) { $seedNextScanAt } elseif ($null -eq $seedNextScanAt) { $existingNextScanAt } elseif ($seedNextScanAt -lt $existingNextScanAt) { $seedNextScanAt } else { $existingNextScanAt }

    $Existing.canonical_name = if ((Get-JobAgentVerificationStatusRank -Status ([string]$Seed.verification_status)) -ge (Get-JobAgentVerificationStatusRank -Status ([string]$Existing.verification_status))) { $Seed.canonical_name } else { $Existing.canonical_name }
    $Existing.canonical_domain = if ((Get-JobAgentVerificationStatusRank -Status ([string]$Seed.verification_status)) -ge (Get-JobAgentVerificationStatusRank -Status ([string]$Existing.verification_status))) { $Seed.canonical_domain } else { $Existing.canonical_domain }
    $Existing.official_website_url = if (-not [string]::IsNullOrWhiteSpace([string]$Seed.official_website_url)) { $Seed.official_website_url } else { $Existing.official_website_url }
    $Existing.career_url = if (-not [string]::IsNullOrWhiteSpace([string]$Seed.career_url)) { $Seed.career_url } else { $Existing.career_url }
    $Existing.aliases = @($aliases)
    $Existing.locations = @(Merge-JobAgentCompanyLocations -Existing @($Existing.locations) -Seed @($Seed.locations))
    if ([string]::IsNullOrWhiteSpace([string]$Existing.industry) -or [string]$Existing.industry -eq 'UNKNOWN') {
        $Existing.industry = $Seed.industry
    }
    $Existing.ats = @(Merge-JobAgentCompanyAtsBindings -Existing @($Existing.ats) -Seed @($Seed.ats))
    $Existing.scan_priority = [Math]::Max([int]$Existing.scan_priority, [int]$Seed.scan_priority)
    if ($null -ne $mergedNextScanAt) {
        $Existing.next_scan_at = $mergedNextScanAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    }
    $Existing.verification_status = $preferredVerificationStatus
    $Existing.discovery_source = Get-JobAgentPreferredDiscoverySource -Existing $Existing -Seed $Seed -VerificationStatus $preferredVerificationStatus
    $Existing.updated_at = $Seed.updated_at
    if ($null -eq $Existing.last_successful_scan_at) {
        $Existing.last_successful_scan_at = $Seed.last_successful_scan_at
    }
    return $Existing
}

function New-JobAgentCompanyCareerSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][string]$VerifiedAt
    )

    if ($null -eq $Company.career_url) {
        return $null
    }

    [pscustomobject]@{
        source_id = 'source:' + (ConvertTo-JobAgentAsciiSlug -Value ([string]$Company.company_id).Substring(8)) + '_career'
        company_id = $Company.company_id
        source_type = 'CAREER_PAGE'
        url = $Company.career_url
        canonical_url = $Company.career_url
        is_official = $true
        verified_at = $VerifiedAt
        verification_basis = 'CAREER_URL'
        verification_evidence = @(
            Complete-JobAgentVerificationEvidence -ObservedAt ([datetime]::Parse($VerifiedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)) -Evidence @(
                [pscustomobject]@{
                    status = 'VERIFIED'
                    evidence_type = 'CAREER_URL'
                    url = [string]$Company.career_url
                    basis_url = [string]$Company.official_website_url
                    redirect_chain = @()
                    observed_at = $VerifiedAt
                    reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.'
                }
            )
        )
    }
}

function Add-JobAgentCompanySeedInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][object[]]$Seeds = @(Get-JobAgentCompanySeedInventory),
        [Parameter()][datetime]$SeededAt = [datetime]::UtcNow
    )

    $companies = New-Object System.Collections.Generic.List[object]
    foreach ($company in @($Document.companies)) {
        $companies.Add($company)
    }
    $sources = New-Object System.Collections.Generic.List[object]
    foreach ($source in @($Document.job_sources)) {
        $sources.Add($source)
    }

    $added = New-Object System.Collections.Generic.List[string]
    $updated = New-Object System.Collections.Generic.List[string]
    $deduplicated = New-Object System.Collections.Generic.List[object]
    foreach ($seed in @($Seeds)) {
        $match = Find-JobAgentCompanyDuplicate -Companies $companies.ToArray() -Candidate $seed
        if ($null -eq $match) {
            $companies.Add($seed)
            $added.Add([string]$seed.company_id)
            $companyForSource = $seed
        }
        else {
            $companyForSource = Merge-JobAgentCompanySeed -Existing $match.company -Seed $seed
            $updated.Add([string]$companyForSource.company_id)
            $deduplicated.Add([pscustomobject]@{
                company_id = $companyForSource.company_id
                seed_company_id = $seed.company_id
                matched_key = $match.matched_key
            })
        }

        $source = New-JobAgentCompanyCareerSource -Company $companyForSource -VerifiedAt ($SeededAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture))
        if ($null -ne $source) {
            $existingSource = $sources | Where-Object { $_.source_id -eq $source.source_id } | Select-Object -First 1
            if ($null -eq $existingSource) {
                $sources.Add($source)
            }
            else {
                $index = $sources.IndexOf($existingSource)
                $sources[$index] = $source
            }
        }
    }

    $Document.companies = @($companies.ToArray() | Sort-Object -Property scan_priority, canonical_name -Descending)
    $Document.job_sources = @($sources.ToArray() | Sort-Object -Property company_id, source_id)
    [pscustomobject]@{
        document = $Document
        added = $added.ToArray()
        updated = $updated.ToArray()
        deduplicated = $deduplicated.ToArray()
    }
}

function ConvertTo-JobAgentCompanyDiscoverySeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DiscoveryItem,
        [Parameter()][datetime]$ImportedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$NextScanAt = ([datetime]::UtcNow.Date.AddDays(1))
    )

    foreach ($property in @('canonical_name', 'official_website_url', 'locations', 'industry', 'scan_priority')) {
        if ($DiscoveryItem.PSObject.Properties.Name -notcontains $property) {
            throw "Discovery-Eintrag fehlt Pflichtfeld $property."
        }
    }

    $discoveryType = if ($DiscoveryItem.PSObject.Properties.Name -contains 'discovery_type' -and -not [string]::IsNullOrWhiteSpace([string]$DiscoveryItem.discovery_type)) {
        [string]$DiscoveryItem.discovery_type
    }
    else {
        'OFFICIAL_WEBSITE'
    }
    if (@('OFFICIAL_WEBSITE', 'MANUAL_REVIEW', 'DISCOVERY_HINT') -notcontains $discoveryType) {
        throw "Ungueltiger discovery_type: $discoveryType"
    }

    $careerUrl = if ($DiscoveryItem.PSObject.Properties.Name -contains 'career_url' -and -not [string]::IsNullOrWhiteSpace([string]$DiscoveryItem.career_url)) {
        [string]$DiscoveryItem.career_url
    }
    else {
        $null
    }
    $discoveryUrl = if ($DiscoveryItem.PSObject.Properties.Name -contains 'discovery_url' -and -not [string]::IsNullOrWhiteSpace([string]$DiscoveryItem.discovery_url)) {
        [string]$DiscoveryItem.discovery_url
    }
    elseif ($null -ne $careerUrl) {
        $careerUrl
    }
    else {
        [string]$DiscoveryItem.official_website_url
    }
    if (($discoveryType -ne 'OFFICIAL_WEBSITE') -and [string]::IsNullOrWhiteSpace($discoveryUrl)) {
        throw 'Discovery-Hinweise und Manual-Review-Eintraege benoetigen discovery_url.'
    }

    $verificationStatus = if ($null -ne $careerUrl) {
        'CAREER_URL_VERIFIED'
    }
    elseif ($discoveryType -eq 'OFFICIAL_WEBSITE') {
        'COMPANY_DOMAIN_VERIFIED'
    }
    else {
        'UNVERIFIED'
    }
    $verificationUrl = if ($verificationStatus -eq 'CAREER_URL_VERIFIED') {
        $careerUrl
    }
    elseif ($verificationStatus -eq 'COMPANY_DOMAIN_VERIFIED') {
        [string]$DiscoveryItem.official_website_url
    }
    else {
        $null
    }

    return New-JobAgentCompanySeed `
        -CanonicalName ([string]$DiscoveryItem.canonical_name) `
        -OfficialWebsiteUrl ([string]$DiscoveryItem.official_website_url) `
        -CareerUrl $careerUrl `
        -Aliases @($DiscoveryItem.aliases) `
        -Locations @($DiscoveryItem.locations) `
        -Industry ([string]$DiscoveryItem.industry) `
        -ScanPriority ([int]$DiscoveryItem.scan_priority) `
        -DiscoverySourceUrl $discoveryUrl `
        -DiscoverySourceType $discoveryType `
        -DiscoveryOrigin $(if ($DiscoveryItem.PSObject.Properties.Name -contains 'discovery_origin' -and -not [string]::IsNullOrWhiteSpace([string]$DiscoveryItem.discovery_origin)) { [string]$DiscoveryItem.discovery_origin } else { 'seed.discovery' }) `
        -DiscoveryEvidenceNote $(if ($DiscoveryItem.PSObject.Properties.Name -contains 'evidence_note' -and -not [string]::IsNullOrWhiteSpace([string]$DiscoveryItem.evidence_note)) { [string]$DiscoveryItem.evidence_note } else { 'Discovery-Feed importiert; offizielle Quelle muss nachvollziehbar bleiben.' }) `
        -DiscoveryVerificationUrl $verificationUrl `
        -VerificationStatus $verificationStatus `
        -Ats $(if ($DiscoveryItem.PSObject.Properties.Name -contains 'ats') { @($DiscoveryItem.ats) } else { @() }) `
        -CreatedAt $ImportedAt `
        -NextScanAt $NextScanAt
}

function Import-JobAgentCompanyDiscoveryInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$DiscoveryItems,
        [Parameter()][datetime]$ImportedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$NextScanAt = ([datetime]::UtcNow.Date.AddDays(1))
    )

    $seeds = foreach ($item in @($DiscoveryItems)) {
        ConvertTo-JobAgentCompanyDiscoverySeed -DiscoveryItem $item -ImportedAt $ImportedAt -NextScanAt $NextScanAt
    }
    $result = Add-JobAgentCompanySeedInventory -Document $Document -Seeds $seeds -SeededAt $ImportedAt
    $manualReviewRequired = @($result.document.companies | Where-Object {
            ($_.verification_status -eq 'UNVERIFIED') -or (@('MANUAL_REVIEW', 'DISCOVERY_HINT') -contains [string]$_.discovery_source.type)
        } | ForEach-Object { [string]$_.company_id } | Sort-Object -Unique)
    $result | Add-Member -NotePropertyName imported -NotePropertyValue @($seeds | ForEach-Object { [string]$_.company_id }) -Force
    $result | Add-Member -NotePropertyName manual_review_required -NotePropertyValue $manualReviewRequired -Force
    return $result
}

Export-ModuleMember -Function @(
    'Add-JobAgentCompanySeedInventory',
    'ConvertTo-JobAgentCanonicalDomain',
    'ConvertTo-JobAgentCompanyDiscoverySeed',
    'ConvertTo-JobAgentCompanyNameKey',
    'Find-JobAgentCompanyDuplicate',
    'Get-JobAgentCompanySeedInventory',
    'Import-JobAgentCompanyDiscoveryInventory',
    'Merge-JobAgentCompanySeed',
    'New-JobAgentDiscoverySource',
    'New-JobAgentCompanySeed',
    'New-JobAgentTargetLocation'
)
