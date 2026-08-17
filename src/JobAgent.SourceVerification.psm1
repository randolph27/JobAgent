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

function New-JobAgentVerificationEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('VERIFIED', 'UNVERIFIED', 'REJECTED')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('COMPANY_DOMAIN', 'CAREER_URL', 'ATS_VERIFIED_BY_URL', 'COMPANY_LINKED_ATS', 'AGGREGATOR_REJECTED', 'UNVERIFIED')][string]$EvidenceType,
        [Parameter(Mandatory)][string]$Url,
        [Parameter()][AllowNull()][string]$BasisUrl,
        [Parameter()][string[]]$RedirectChain = @(),
        [Parameter(Mandatory)][string]$Reason
    )

    if (-not [Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        throw "Evidence-URL ist nicht absolut oder ungueltig: $Url"
    }

    $canonicalUrl = ConvertTo-JobAgentCanonicalUrl -Url $Url
    $canonicalBasisUrl = $null
    if (-not [string]::IsNullOrWhiteSpace($BasisUrl)) {
        $canonicalBasisUrl = ConvertTo-JobAgentCanonicalUrl -Url $BasisUrl
    }

    $canonicalRedirectChain = @(
        $RedirectChain |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object { ConvertTo-JobAgentCanonicalUrl -Url ([string]$_) } |
            Sort-Object -Unique
    )

    [pscustomobject]@{
        status = $Status
        evidence_type = $EvidenceType
        url = $canonicalUrl
        basis_url = $canonicalBasisUrl
        redirect_chain = $canonicalRedirectChain
        observed_at = $null
        reason = $Reason
    }
}

function Complete-JobAgentVerificationEvidence {
    [CmdletBinding()]
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Evidence = @(),
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    $observedAtText = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    $completed = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Evidence)) {
        if ($null -eq $item) {
            continue
        }
        $completed.Add([pscustomobject]@{
                status = [string]$item.status
                evidence_type = [string]$item.evidence_type
                url = [string]$item.url
                basis_url = if ($item.PSObject.Properties.Name -contains 'basis_url') { $item.basis_url } else { $null }
                redirect_chain = @($item.redirect_chain)
                observed_at = if (($item.PSObject.Properties.Name -contains 'observed_at') -and -not [string]::IsNullOrWhiteSpace([string]$item.observed_at)) { [string]$item.observed_at } else { $observedAtText }
                reason = [string]$item.reason
            })
    }
    return $completed.ToArray()
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
        [Parameter(Mandatory)][string]$Url,
        [Parameter()][bool]$AllowAtsEvidence = $true
    )

    $canonicalUrl = ConvertTo-JobAgentCanonicalUrl -Url $Url
    if (Test-JobAgentAggregatorUrl -Url $canonicalUrl) {
        return [pscustomobject]@{
            is_official = $false
            status = 'INVALID'
            canonical_url = $canonicalUrl
            verification_basis = 'AGGREGATOR_REJECTED'
            verification_evidence = @(
                New-JobAgentVerificationEvidence `
                    -Status 'REJECTED' `
                    -EvidenceType 'AGGREGATOR_REJECTED' `
                    -Url $canonicalUrl `
                    -Reason 'Aggregatoren, Jobboersen und soziale Netzwerke duerfen keine Primaerquelle sein.'
            )
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
        $evidence = if ($basis -eq 'CAREER_URL') {
            @(
                New-JobAgentVerificationEvidence `
                    -Status 'VERIFIED' `
                    -EvidenceType 'CAREER_URL' `
                    -Url $canonicalUrl `
                    -BasisUrl ([string]$Company.career_url) `
                    -Reason 'URL liegt auf der gepflegten offiziellen Karriere-URL oder darunter.'
            )
        }
        else {
            @(
                New-JobAgentVerificationEvidence `
                    -Status 'VERIFIED' `
                    -EvidenceType 'COMPANY_DOMAIN' `
                    -Url $canonicalUrl `
                    -BasisUrl ([string]$Company.official_website_url) `
                    -Reason 'URL liegt auf der offiziellen Firmendomain.'
            )
        }
        return [pscustomobject]@{
            is_official = $true
            status = 'VALID'
            canonical_url = $canonicalUrl
            verification_basis = $basis
            verification_evidence = $evidence
            reason = 'URL gehoert zur Firmen- oder Karriere-Domain.'
        }
    }

    foreach ($ats in @($Company.ats)) {
        if (-not $AllowAtsEvidence) {
            continue
        }
        if (($ats.PSObject.Properties.Name -contains 'official_domain') -and -not [string]::IsNullOrWhiteSpace([string]$ats.official_domain)) {
            if (Test-JobAgentDomainMatch -Host $host -Domain ([string]$ats.official_domain)) {
                $verifiedByUrl = if ($ats.PSObject.Properties.Name -contains 'verified_by_url') { [string]$ats.verified_by_url } else { $null }
                if ([string]::IsNullOrWhiteSpace($verifiedByUrl)) {
                    return [pscustomobject]@{
                        is_official = $false
                        status = 'UNVERIFIED'
                        canonical_url = $canonicalUrl
                        verification_basis = 'UNVERIFIED'
                        verification_evidence = @(
                            New-JobAgentVerificationEvidence `
                                -Status 'UNVERIFIED' `
                                -EvidenceType 'UNVERIFIED' `
                                -Url $canonicalUrl `
                                -Reason 'ATS-Domain passt, aber es fehlt ein offizieller Firmenbeleg in verified_by_url.'
                        )
                        reason = 'ATS-Domain passt, aber es fehlt ein offizieller Firmenbeleg in verified_by_url.'
                    }
                }

                $atsProof = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $verifiedByUrl -AllowAtsEvidence $false
                if ($atsProof.is_official -ne $true) {
                    return [pscustomobject]@{
                        is_official = $false
                        status = 'UNVERIFIED'
                        canonical_url = $canonicalUrl
                        verification_basis = 'UNVERIFIED'
                        verification_evidence = @(
                            New-JobAgentVerificationEvidence `
                                -Status 'UNVERIFIED' `
                                -EvidenceType 'UNVERIFIED' `
                                -Url $canonicalUrl `
                                -BasisUrl $verifiedByUrl `
                                -Reason 'verified_by_url ist selbst keine offizielle Firmen- oder Karriere-URL.'
                        )
                        reason = 'verified_by_url ist selbst keine offizielle Firmen- oder Karriere-URL.'
                    }
                }

                return [pscustomobject]@{
                    is_official = $true
                    status = 'VALID'
                    canonical_url = $canonicalUrl
                    verification_basis = 'COMPANY_LINKED_ATS'
                    verification_evidence = @(
                        (New-JobAgentVerificationEvidence `
                            -Status 'VERIFIED' `
                            -EvidenceType 'COMPANY_LINKED_ATS' `
                            -Url $canonicalUrl `
                            -BasisUrl $verifiedByUrl `
                            -Reason 'URL gehoert zu einer gepflegten ATS-Domain fuer dieses Unternehmen.'),
                        (New-JobAgentVerificationEvidence `
                            -Status 'VERIFIED' `
                            -EvidenceType 'ATS_VERIFIED_BY_URL' `
                            -Url $verifiedByUrl `
                            -BasisUrl $atsProof.canonical_url `
                            -Reason 'Die ATS-Domain ist ueber eine offizielle Firmen- oder Karriere-URL belegt.')
                    )
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
        verification_evidence = @(
            New-JobAgentVerificationEvidence `
                -Status 'UNVERIFIED' `
                -EvidenceType 'UNVERIFIED' `
                -Url $canonicalUrl `
                -Reason 'URL passt weder zur Firmendomain noch zu einer firmengebundenen ATS-Domain mit offiziellem Beleg.'
        )
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
        verification_evidence = @(Complete-JobAgentVerificationEvidence -Evidence @($evaluation.verification_evidence) -ObservedAt $VerifiedAt)
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
    'Complete-JobAgentVerificationEvidence',
    'Get-JobAgentOfficialSourceEvaluation',
    'New-JobAgentVerifiedJobSource',
    'Resolve-JobAgentOfficialJobUrl',
    'Test-JobAgentAggregatorUrl',
    'Test-JobAgentDomainMatch'
)
