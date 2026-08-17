#requires -Version 7.4

Set-StrictMode -Version 3.0

$script:AggregatorDomains = @(
    'stepstone.de',
    'indeed.com',
    'indeed.de',
    'linkedin.com',
    'xing.com',
    'kununu.com',
    'glassdoor.com',
    'glassdoor.de'
)

$script:DiscardQueryParameters = @(
    'fbclid',
    'gclid',
    'msclkid',
    'session',
    'sessionid',
    'sid',
    'ref',
    'referrer',
    'source',
    'utm_campaign',
    'utm_content',
    'utm_medium',
    'utm_source',
    'utm_term'
)

function ConvertTo-JobAgentSourceSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $slug = $Value.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Slug-Wert darf nicht leer sein.'
    }
    return $slug
}

function Get-JobAgentUrlHost {
    param(
        [Parameter(Mandatory)][string]$Url
    )

    if (-not [Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        throw "URL ist nicht absolut oder ungueltig: $Url"
    }

    return ([Uri]$Url).Host.ToLowerInvariant() -replace '^www\.', ''
}

function Test-JobAgentDomainMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Host,
        [Parameter(Mandatory)][string]$Domain
    )

    $normalizedHost = $Host.Trim().ToLowerInvariant() -replace '^www\.', ''
    $normalizedDomain = $Domain.Trim().ToLowerInvariant() -replace '^www\.', ''
    return ($normalizedHost -eq $normalizedDomain) -or $normalizedHost.EndsWith('.' + $normalizedDomain, [StringComparison]::OrdinalIgnoreCase)
}

function Test-JobAgentAggregatorUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url
    )

    $host = Get-JobAgentUrlHost -Url $Url
    foreach ($domain in $script:AggregatorDomains) {
        if (Test-JobAgentDomainMatch -Host $host -Domain $domain) {
            return $true
        }
    }
    return $false
}

function ConvertTo-JobAgentCanonicalUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url
    )

    if (-not [Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        throw "URL ist nicht absolut oder ungueltig: $Url"
    }

    $uri = [Uri]$Url
    if (@('http', 'https') -notcontains $uri.Scheme.ToLowerInvariant()) {
        throw "URL-Schema wird nicht unterstuetzt: $($uri.Scheme)"
    }

    $builder = [UriBuilder]::new($uri)
    $builder.Scheme = $uri.Scheme.ToLowerInvariant()
    $builder.Host = $uri.Host.ToLowerInvariant() -replace '^www\.', ''
    $builder.Fragment = ''

    $path = [Net.WebUtility]::UrlDecode($builder.Path)
    $path = [regex]::Replace($path, '/+', '/')
    if (($path.Length -gt 1) -and $path.EndsWith('/')) {
        $path = $path.TrimEnd('/')
    }
    $builder.Path = $path

    $kept = New-Object System.Collections.Generic.List[string]
    $query = $uri.Query.TrimStart('?')
    if (-not [string]::IsNullOrWhiteSpace($query)) {
        foreach ($part in ($query -split '&' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $name = [Net.WebUtility]::UrlDecode(($part -split '=', 2)[0]).ToLowerInvariant()
            if (($script:DiscardQueryParameters -contains $name) -or $name.StartsWith('utm_', [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            $kept.Add($part)
        }
    }
    $builder.Query = (($kept.ToArray() | Sort-Object) -join '&')

    return $builder.Uri.AbsoluteUri
}

function Get-JobAgentOfficialSourceEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][string]$Url
    )

    $canonicalUrl = ConvertTo-JobAgentCanonicalUrl -Url $Url
    if (Test-JobAgentAggregatorUrl -Url $canonicalUrl) {
        return [pscustomobject]@{
            is_official = $false
            status = 'INVALID'
            canonical_url = $canonicalUrl
            verification_basis = 'AGGREGATOR_REJECTED'
            reason = 'Aggregatoren, Jobboersen und soziale Netzwerke duerfen keine Primaerquelle sein.'
        }
    }

    $host = Get-JobAgentUrlHost -Url $canonicalUrl
    $companyDomain = ([string]$Company.canonical_domain).ToLowerInvariant() -replace '^www\.', ''
    if (-not [string]::IsNullOrWhiteSpace($companyDomain) -and (Test-JobAgentDomainMatch -Host $host -Domain $companyDomain)) {
        $basis = 'COMPANY_DOMAIN'
        if (-not [string]::IsNullOrWhiteSpace([string]$Company.career_url)) {
            $canonicalCareer = ConvertTo-JobAgentCanonicalUrl -Url ([string]$Company.career_url)
            if ($canonicalUrl.StartsWith($canonicalCareer, [StringComparison]::OrdinalIgnoreCase)) {
                $basis = 'CAREER_URL'
            }
        }
        return [pscustomobject]@{
            is_official = $true
            status = 'VALID'
            canonical_url = $canonicalUrl
            verification_basis = $basis
            reason = 'URL gehoert zur Firmen- oder Karriere-Domain.'
        }
    }

    foreach ($ats in @($Company.ats)) {
        if (($ats.PSObject.Properties.Name -contains 'official_domain') -and -not [string]::IsNullOrWhiteSpace([string]$ats.official_domain)) {
            if (Test-JobAgentDomainMatch -Host $host -Domain ([string]$ats.official_domain)) {
                return [pscustomobject]@{
                    is_official = $true
                    status = 'VALID'
                    canonical_url = $canonicalUrl
                    verification_basis = 'COMPANY_LINKED_ATS'
                    reason = 'URL gehoert zu einer firmengebundenen ATS-Domain.'
                }
            }
        }
    }

    [pscustomobject]@{
        is_official = $false
        status = 'UNVERIFIED'
        canonical_url = $canonicalUrl
        verification_basis = 'UNVERIFIED'
        reason = 'URL passt weder zur Firmendomain noch zu einer firmengebundenen ATS-Domain.'
    }
}

function New-JobAgentVerifiedJobSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][string]$Url,
        [Parameter()][ValidateSet('COMPANY_WEBSITE', 'CAREER_PAGE', 'OFFICIAL_ATS', 'JOB_DETAIL')][string]$SourceType = 'JOB_DETAIL',
        [Parameter()][datetime]$VerifiedAt = [datetime]::UtcNow
    )

    $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $Url
    if ($evaluation.is_official -ne $true) {
        throw "Nicht-offizielle JobSource: $($evaluation.status) $($evaluation.canonical_url)"
    }

    [pscustomobject]@{
        source_id = 'source:' + (ConvertTo-JobAgentSourceSlug -Value (([string]$Company.company_id).Substring(8) + '_' + $SourceType + '_' + $evaluation.verification_basis))
        company_id = $Company.company_id
        source_type = $SourceType
        url = $Url
        canonical_url = $evaluation.canonical_url
        is_official = $true
        verified_at = $VerifiedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        verification_basis = $evaluation.verification_basis
    }
}

function Resolve-JobAgentOfficialJobUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][string]$PrimaryUrl,
        [Parameter()][string[]]$AlternativeUrls = @()
    )

    $primary = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $PrimaryUrl
    $validAlternatives = New-Object System.Collections.Generic.List[string]
    foreach ($alternative in @($AlternativeUrls)) {
        if ([string]::IsNullOrWhiteSpace($alternative)) {
            continue
        }
        $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $alternative
        if ($evaluation.is_official -eq $true -and $evaluation.canonical_url -ne $primary.canonical_url) {
            $validAlternatives.Add([string]$evaluation.canonical_url)
        }
    }

    [pscustomobject]@{
        status = $primary.status
        is_official = $primary.is_official
        official_url = if ($primary.is_official -eq $true) { $primary.canonical_url } else { $null }
        rejected_url = if ($primary.is_official -eq $true) { $null } else { $primary.canonical_url }
        alternative_official_urls = @($validAlternatives.ToArray() | Sort-Object -Unique)
        verification_basis = $primary.verification_basis
        reason = $primary.reason
    }
}

Export-ModuleMember -Function @(
    'ConvertTo-JobAgentCanonicalUrl',
    'Get-JobAgentOfficialSourceEvaluation',
    'New-JobAgentVerifiedJobSource',
    'Resolve-JobAgentOfficialJobUrl',
    'Test-JobAgentAggregatorUrl',
    'Test-JobAgentDomainMatch'
)
