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
        ats = @($Ats | Where-Object { $null -ne $_ })
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

function New-JobAgentCompanyDiscoveryHintSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Muenchen', 'Freising', 'Garching', 'Unterfoehring', 'Ismaning', 'Taufkirchen', 'Neubiberg', 'Pullach', 'Gruenwald')][string]$Location,
        [Parameter(Mandatory)][ValidateRange(1, 100)][int]$RadiusKm,
        [Parameter(Mandatory)][ValidateSet('Head IT', 'Leiter IT', 'Director IT', 'CIO', 'IT Operations', 'IT Security', 'Digitalisierung', 'Enterprise Applications')][string]$Keyword
    )

    [pscustomobject]@{
        location = $Location
        radius_km = $RadiusKm
        keyword = $Keyword
    }
}

function Get-JobAgentCompanyDiscoveryHintSearchMatrix {
    [CmdletBinding()]
    param()

    $locations = @('Muenchen', 'Freising', 'Garching', 'Unterfoehring', 'Ismaning', 'Taufkirchen', 'Neubiberg', 'Pullach', 'Gruenwald')
    $keywords = @('Head IT', 'Leiter IT', 'Director IT', 'CIO', 'IT Operations', 'IT Security', 'Digitalisierung', 'Enterprise Applications')
    foreach ($location in $locations) {
        $radius = if ($location -eq 'Muenchen') { 20 } else { 25 }
        foreach ($keyword in $keywords) {
            New-JobAgentCompanyDiscoveryHintSearch -Location $location -RadiusKm $radius -Keyword $keyword
        }
    }
}

function Get-JobAgentCompanyDiscoveryHintTargetArea {
    param([Parameter(Mandatory)][string]$Location)

    switch ($Location) {
        'Muenchen' { return 'MUNICH' }
        'Freising' { return 'FREISING' }
        default { return 'MUNICH_20KM' }
    }
}

function New-JobAgentCompanyDiscoveryHint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EmployerName,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$IndustryOrKeyword,
        [Parameter(Mandatory)][string]$ObservedUrl,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][object]$Search,
        [Parameter()][datetime]$ObservedAt = [datetime]::UtcNow,
        [Parameter()][AllowNull()][string]$KnownCompanyId = $null,
        [Parameter()][AllowNull()][string]$KnownCompanyDomain = $null
    )

    if ([string]::IsNullOrWhiteSpace($EmployerName)) {
        throw 'EmployerName darf nicht leer sein.'
    }
    if ([string]::IsNullOrWhiteSpace($ObservedUrl) -or $ObservedUrl -notmatch '^https?://') {
        throw "Ungueltige beobachtete Hint-URL: $ObservedUrl"
    }
    if ($SourceId -notmatch '^source-registry:[a-z0-9][a-z0-9._-]*$') {
        throw "Ungueltige SourceId: $SourceId"
    }

    $normalizedName = ConvertTo-JobAgentCompanyNameKey -Name $EmployerName
    $searchLocation = [string]$Search.location
    [pscustomobject]@{
        hint_id = 'hint:' + (ConvertTo-JobAgentAsciiSlug -Value ($SourceId.Substring(16) + '-' + $normalizedName + '-' + [string]$Search.keyword + '-' + $searchLocation))
        employer_name = $EmployerName
        normalized_name = $normalizedName
        location = $Location
        target_area = Get-JobAgentCompanyDiscoveryHintTargetArea -Location $searchLocation
        industry_or_keyword = $IndustryOrKeyword
        source_id = $SourceId
        observed_url = $ObservedUrl
        observed_at = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        search_parameters = [pscustomobject]@{
            location = $searchLocation
            radius_km = [int]$Search.radius_km
            keyword = [string]$Search.keyword
        }
        verification_status = 'UNVERIFIED'
        candidate_status = 'DISCOVERY_HINT'
        known_company_id = if ([string]::IsNullOrWhiteSpace($KnownCompanyId)) { $null } else { $KnownCompanyId }
        known_company_domain = if ([string]::IsNullOrWhiteSpace($KnownCompanyDomain)) { $null } else { $KnownCompanyDomain }
        next_action = 'verify_official_company_website_or_career_url'
    }
}

function Find-JobAgentKnownCompanyForHint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Companies,
        [Parameter(Mandatory)][string]$EmployerName
    )

    $nameKey = ConvertTo-JobAgentCompanyNameKey -Name $EmployerName
    foreach ($company in @($Companies)) {
        $keys = Get-JobAgentCompanyIdentityKeys -Company $company
        if ($keys.Contains('name:' + $nameKey)) {
            return $company
        }
    }
    return $null
}

function Get-JobAgentCompanyCandidateProperty {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Names,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            return $Object.$name
        }
    }
    return $Default
}

function ConvertTo-JobAgentCompanyCandidateDate {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter(Mandatory)][datetime]$Fallback
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $Fallback.ToUniversalTime()
    }
    return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
}

function Get-JobAgentCompanyCandidateTargetBasis {
    param([Parameter(Mandatory)][object]$Candidate)

    $status = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('candidate_status') -Default '')
    $area = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('target_area_match', 'target_area') -Default 'UNKNOWN')
    if ($area -in @('TARGET_AREA_UNCERTAIN', 'UNKNOWN')) {
        return 'TARGET_UNCERTAIN'
    }
    if ($area -eq 'OUT_OF_SCOPE') {
        return 'OUT_OF_SCOPE'
    }
    if ($area -eq 'REMOTE_WITH_TARGET_REFERENCE') {
        return 'REMOTE_WITH_TARGET_REFERENCE'
    }
    if ($status -eq 'REGISTER_DISCOVERY_HINT') {
        return 'REGISTER_SEAT_IN_TARGET'
    }
    if ($status -eq 'REGIONAL_DISCOVERY_HINT') {
        return 'BRANCH_HINT_IN_TARGET'
    }
    return 'JOB_LOCATION_IN_TARGET'
}

function ConvertTo-JobAgentCompanyCandidateRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter()][datetime]$ObservedAt = [datetime]::UtcNow
    )

    $name = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('employer_name', 'company_name', 'register_name', 'canonical_name') -Default '')
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'Kandidat enthaelt keinen Firmennamen.'
    }
    $normalizedName = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('normalized_name') -Default '')
    if ([string]::IsNullOrWhiteSpace($normalizedName)) {
        $normalizedName = ConvertTo-JobAgentCompanyNameKey -Name $name
    }

    $candidateId = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('candidate_id', 'hint_id', 'company_id') -Default '')
    if ([string]::IsNullOrWhiteSpace($candidateId)) {
        $candidateId = 'candidate:' + (ConvertTo-JobAgentAsciiSlug -Value $name)
    }

    $observed = ConvertTo-JobAgentCompanyCandidateDate -Value (Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('observed_at', 'created_at') -Default $null) -Fallback $ObservedAt
    $domain = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('known_company_domain', 'canonical_domain') -Default '')
    $dedupeKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($key in @((Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('dedupe_keys') -Default @()))) {
        if (-not [string]::IsNullOrWhiteSpace([string]$key)) {
            $dedupeKeys.Add([string]$key)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($domain)) {
        $dedupeKeys.Add('domain:' + (ConvertTo-JobAgentCanonicalDomain -UrlOrDomain $domain))
    }
    if (-not [string]::IsNullOrWhiteSpace($normalizedName)) {
        $dedupeKeys.Add('name:' + $normalizedName)
    }

    $registerNumber = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('register_number') -Default '')
    $registerCourt = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('register_court') -Default '')
    if (-not [string]::IsNullOrWhiteSpace($registerNumber) -and $registerNumber -ne 'UNKNOWN' -and -not [string]::IsNullOrWhiteSpace($registerCourt)) {
        $dedupeKeys.Add('register:' + (ConvertTo-JobAgentAsciiSlug -Value ($registerCourt + '-' + $registerNumber)))
    }

    [pscustomobject]@{
        candidate_id = $candidateId
        employer_name = $name
        normalized_name = $normalizedName
        candidate_status = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('candidate_status') -Default 'DISCOVERY_HINT')
        source_id = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('source_id') -Default 'UNKNOWN')
        dedupe_keys = @($dedupeKeys.ToArray() | Sort-Object -Unique)
        strong_identity_keys = @($dedupeKeys.ToArray() | Where-Object { [string]$_ -match '^(domain|register|company_id):' } | Sort-Object -Unique)
        target_area = [string](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('target_area_match', 'target_area') -Default 'UNKNOWN')
        target_area_basis = Get-JobAgentCompanyCandidateTargetBasis -Candidate $Candidate
        observed_at = $observed.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        confidence_score = [int](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('confidence_score', 'priority_score') -Default 50)
        is_staffing_agency = [bool](Get-JobAgentCompanyCandidateProperty -Object $Candidate -Names @('is_staffing_agency') -Default $false)
    }
}

function New-JobAgentCompanyCandidateClusterId {
    param([Parameter(Mandatory)][string]$Basis)

    return 'identity-cluster:' + (ConvertTo-JobAgentAsciiSlug -Value $Basis)
}

function Join-JobAgentCompanyCandidateCluster {
    param(
        [Parameter(Mandatory)][object]$Cluster,
        [Parameter(Mandatory)][object]$Candidate
    )

    $Cluster.candidates.Add($Candidate)
    foreach ($key in @($Candidate.dedupe_keys)) {
        [void]$Cluster.dedupe_keys.Add([string]$key)
    }
    foreach ($basis in @($Candidate.target_area_basis)) {
        [void]$Cluster.target_area_basis.Add([string]$basis)
    }
    if ([bool]$Candidate.is_staffing_agency) {
        [void]$Cluster.conflict_flags.Add('STAFFING_AGENCY_REVIEW')
    }
    if ([string]$Candidate.target_area_basis -eq 'TARGET_UNCERTAIN') {
        [void]$Cluster.conflict_flags.Add('TARGET_AREA_UNCERTAIN')
    }
    if ([string]$Candidate.target_area_basis -eq 'OUT_OF_SCOPE') {
        [void]$Cluster.conflict_flags.Add('OUT_OF_SCOPE_HINT')
    }
}

function Resolve-JobAgentCompanyCandidateClusters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Candidates,
        [Parameter()][datetime]$ObservedAt = [datetime]::UtcNow
    )

    $records = @($Candidates | ForEach-Object { ConvertTo-JobAgentCompanyCandidateRecord -Candidate $_ -ObservedAt $ObservedAt })
    $clusters = New-Object System.Collections.Generic.List[object]
    $strongKeyToCluster = @{}
    foreach ($record in $records) {
        $strongKeys = @($record.strong_identity_keys)
        $cluster = $null
        foreach ($key in $strongKeys) {
            if ($strongKeyToCluster.ContainsKey([string]$key)) {
                $cluster = $strongKeyToCluster[[string]$key]
                break
            }
        }
        if ($null -eq $cluster) {
            $basis = if ($strongKeys.Count -gt 0) { [string]$strongKeys[0] } else { [string]$record.candidate_id }
            $cluster = [pscustomobject]@{
                identity_cluster_id = New-JobAgentCompanyCandidateClusterId -Basis $basis
                candidates = [System.Collections.Generic.List[object]]::new()
                dedupe_keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                target_area_basis = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                conflict_flags = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            }
            $clusters.Add($cluster)
        }
        Join-JobAgentCompanyCandidateCluster -Cluster $cluster -Candidate $record
        foreach ($key in $strongKeys) {
            $strongKeyToCluster[[string]$key] = $cluster
        }
    }

    $nameGroups = @($records | Group-Object normalized_name | Where-Object { $_.Count -gt 1 })
    foreach ($group in $nameGroups) {
        $candidateIds = @($group.Group | ForEach-Object { [string]$_.candidate_id })
        $relatedClusters = @($clusters | Where-Object {
                @($_.candidates.ToArray() | Where-Object { $candidateIds -contains [string]$_.candidate_id }).Count -gt 0
            })
        $clusterIds = @($relatedClusters | ForEach-Object { [string]$_.identity_cluster_id } | Sort-Object -Unique)
        if ($clusterIds.Count -gt 1) {
            foreach ($cluster in @($relatedClusters)) {
                [void]$cluster.conflict_flags.Add('NAME_MATCH_WITHOUT_STRONG_IDENTITY')
            }
        }
    }

    $clusterResults = foreach ($cluster in @($clusters.ToArray())) {
        $items = @($cluster.candidates.ToArray())
        $firstSeen = @($items | ForEach-Object { ConvertTo-JobAgentCompanyCandidateDate -Value $_.observed_at -Fallback $ObservedAt } | Sort-Object | Select-Object -First 1)[0]
        $lastSeen = @($items | ForEach-Object { ConvertTo-JobAgentCompanyCandidateDate -Value $_.observed_at -Fallback $ObservedAt } | Sort-Object -Descending | Select-Object -First 1)[0]
        $flags = @($cluster.conflict_flags | Sort-Object)
        $reviewReason = if ($flags.Count -gt 0) {
            ($flags -join ',')
        }
        elseif (@($items | Where-Object { @($_.strong_identity_keys).Count -eq 0 }).Count -gt 0) {
            'OFFICIAL_VERIFICATION_REQUIRED'
        }
        else {
            'READY_FOR_OFFICIAL_VERIFICATION'
        }
        [pscustomobject]@{
            identity_cluster_id = [string]$cluster.identity_cluster_id
            canonical_name = [string](@($items | Sort-Object @{ Expression = { -[int]$_.confidence_score }; Ascending = $true }, employer_name | Select-Object -First 1)[0].employer_name)
            candidate_ids = @($items | ForEach-Object { [string]$_.candidate_id } | Sort-Object)
            dedupe_keys = @($cluster.dedupe_keys | Sort-Object)
            conflict_flags = $flags
            target_area_basis = @($cluster.target_area_basis | Sort-Object)
            source_count = @($items.source_id | Sort-Object -Unique).Count
            first_seen_at = $firstSeen.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            last_seen_at = $lastSeen.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            review_queue_reason = $reviewReason
            candidates = $items
        }
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-clusters/v1'
        generated_at = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        candidates_total = $records.Count
        clusters_total = @($clusterResults).Count
        conflict_clusters = @($clusterResults | Where-Object { @($_.conflict_flags).Count -gt 0 }).Count
        review_queue_total = @($clusterResults | Where-Object { [string]$_.review_queue_reason -ne 'READY_FOR_OFFICIAL_VERIFICATION' }).Count
        clusters = @($clusterResults | Sort-Object canonical_name, identity_cluster_id)
    }
}

function New-JobAgentCompanyDiscoveryHintReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Hints,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$SearchMatrix,
        [Parameter()][datetime]$GeneratedAt = [datetime]::UtcNow
    )

    $sourceCounts = [ordered]@{}
    foreach ($hint in @($Hints)) {
        $sourceId = [string]$hint.source_id
        if (-not $sourceCounts.Contains($sourceId)) {
            $sourceCounts[$sourceId] = 0
        }
        $sourceCounts[$sourceId]++
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = $GeneratedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
        search_matrix_count = @($SearchMatrix).Count
        hints_total = @($Hints).Count
        known_company_hints = @($Hints | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.known_company_id) }).Count
        unverified_hints = @($Hints | Where-Object { [string]$_.verification_status -eq 'UNVERIFIED' }).Count
        source_counts = [pscustomobject]$sourceCounts
        hints = @($Hints | Sort-Object employer_name, source_id)
    }
}

function Test-JobAgentDiscoverySourcePrimaryEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Source
    )

    $sourceClass = [string]$Source.source_class
    $evidenceLevel = [string]$Source.evidence_level
    $reviewRequired = [bool]$Source.review_required
    return @('OFFICIAL_COMPANY', 'OFFICIAL_ATS') -contains $sourceClass -and $evidenceLevel -eq 'PRIMARY_OFFICIAL' -and -not $reviewRequired
}

function Assert-JobAgentDiscoverySource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Source
    )

    $requiredFields = @(
        'source_id',
        'source_class',
        'source_url',
        'operator',
        'allowed_use',
        'forbidden_use',
        'rate_limit_policy',
        'robots_or_terms_note',
        'expected_fields',
        'evidence_level',
        'freshness_policy',
        'retention_policy',
        'import_mode',
        'review_required',
        'legal_risk'
    )
    foreach ($field in $requiredFields) {
        if ($Source.PSObject.Properties.Name -notcontains $field) {
            throw "Discovery-Quelle fehlt Pflichtfeld $field."
        }
    }

    foreach ($field in @('source_id', 'source_class', 'source_url', 'operator', 'allowed_use', 'forbidden_use', 'rate_limit_policy', 'robots_or_terms_note', 'evidence_level', 'freshness_policy', 'retention_policy', 'import_mode', 'legal_risk')) {
        if ([string]::IsNullOrWhiteSpace([string]$Source.$field)) {
            throw "Discovery-Quelle $($Source.source_id) hat leeres Pflichtfeld $field."
        }
    }
    if (@($Source.expected_fields).Count -lt 1) {
        throw "Discovery-Quelle $($Source.source_id) hat keine expected_fields."
    }

    $sourceClass = [string]$Source.source_class
    if (@('JOB_BOARD_DISCOVERY', 'OPEN_REGISTER_DUMP', 'REGIONAL_DIRECTORY', 'PUBLIC_INSTITUTION_DIRECTORY', 'MANUAL_REVIEW') -contains $sourceClass) {
        if ([bool]$Source.review_required -ne $true) {
            throw "Discovery-Quelle $($Source.source_id) muss review_required=true setzen."
        }
        if ([string]$Source.evidence_level -eq 'PRIMARY_OFFICIAL') {
            throw "Discovery-Quelle $($Source.source_id) darf kein Primaerbeleg sein."
        }
    }

    if ($sourceClass -eq 'JOB_BOARD_DISCOVERY' -and [string]$Source.evidence_level -ne 'DISCOVERY_HINT') {
        throw "Jobboerse $($Source.source_id) darf nur Discovery-Hinweise erzeugen."
    }

    if ($sourceClass -eq 'REJECTED') {
        if ([string]$Source.import_mode -ne 'REJECT' -or [string]$Source.evidence_level -ne 'NOT_IMPORTABLE' -or [string]$Source.legal_risk -ne 'BLOCKED') {
            throw "Abgelehnte Quelle $($Source.source_id) ist nicht fail-closed."
        }
        return
    }

    if (([string]$Source.import_mode -eq 'REJECT') -or ([string]$Source.evidence_level -eq 'NOT_IMPORTABLE')) {
        throw "Nicht abgelehnte Quelle $($Source.source_id) ist als nicht importierbar markiert."
    }
}

function Assert-JobAgentDiscoverySourceRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Registry
    )

    if ([string]$Registry.schema_version -ne 'jobagent/discovery-source/v2') {
        throw 'Discovery-Source-Registry hat falsche Schema-Version.'
    }
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($source in @($Registry.items)) {
        Assert-JobAgentDiscoverySource -Source $source
        if (-not $ids.Add([string]$source.source_id)) {
            throw "Doppelte Discovery-Quelle: $($source.source_id)"
        }
    }
}

Export-ModuleMember -Function @(
    'Add-JobAgentCompanySeedInventory',
    'Assert-JobAgentDiscoverySource',
    'Assert-JobAgentDiscoverySourceRegistry',
    'ConvertTo-JobAgentCanonicalDomain',
    'ConvertTo-JobAgentCompanyDiscoverySeed',
    'ConvertTo-JobAgentCompanyNameKey',
    'Find-JobAgentCompanyDuplicate',
    'Find-JobAgentKnownCompanyForHint',
    'Get-JobAgentCompanySeedInventory',
    'Get-JobAgentCompanyDiscoveryHintSearchMatrix',
    'Import-JobAgentCompanyDiscoveryInventory',
    'Merge-JobAgentCompanySeed',
    'ConvertTo-JobAgentCompanyCandidateRecord',
    'New-JobAgentCompanyDiscoveryHint',
    'New-JobAgentCompanyDiscoveryHintReport',
    'New-JobAgentCompanyDiscoveryHintSearch',
    'New-JobAgentDiscoverySource',
    'New-JobAgentCompanySeed',
    'New-JobAgentTargetLocation',
    'Resolve-JobAgentCompanyCandidateClusters',
    'Test-JobAgentDiscoverySourcePrimaryEvidence'
)
