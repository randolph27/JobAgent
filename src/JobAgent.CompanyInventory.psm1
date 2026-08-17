#requires -Version 7.4

Set-StrictMode -Version 3.0

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
        [Parameter()][object[]]$Ats = @(),
        [Parameter()][datetime]$CreatedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$NextScanAt = ([datetime]::UtcNow.Date.AddDays(1))
    )

    $domain = ConvertTo-JobAgentCanonicalDomain -UrlOrDomain $OfficialWebsiteUrl
    $id = 'company:' + (ConvertTo-JobAgentAsciiSlug -Value $CanonicalName)
    $career = if ([string]::IsNullOrWhiteSpace($CareerUrl)) { $null } else { $CareerUrl }
    $verificationStatus = if ($null -eq $career) { 'COMPANY_DOMAIN_VERIFIED' } else { 'CAREER_URL_VERIFIED' }

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
        discovery_source = [pscustomobject]@{
            type = 'OFFICIAL_WEBSITE'
            url = $DiscoverySourceUrl
            observed_at = $CreatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        }
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

    $Existing.canonical_name = $Seed.canonical_name
    $Existing.canonical_domain = $Seed.canonical_domain
    $Existing.official_website_url = $Seed.official_website_url
    $Existing.career_url = $Seed.career_url
    $Existing.aliases = @($aliases)
    $Existing.locations = @($Seed.locations)
    $Existing.industry = $Seed.industry
    $Existing.ats = @($Seed.ats)
    $Existing.scan_priority = $Seed.scan_priority
    $Existing.next_scan_at = $Seed.next_scan_at
    $Existing.verification_status = $Seed.verification_status
    $Existing.discovery_source = $Seed.discovery_source
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

Export-ModuleMember -Function @(
    'Add-JobAgentCompanySeedInventory',
    'ConvertTo-JobAgentCanonicalDomain',
    'ConvertTo-JobAgentCompanyNameKey',
    'Find-JobAgentCompanyDuplicate',
    'Get-JobAgentCompanySeedInventory',
    'Merge-JobAgentCompanySeed',
    'New-JobAgentCompanySeed',
    'New-JobAgentTargetLocation'
)
