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

$script:CareerLinkPatterns = @(
    'karriere',
    'career',
    'careers',
    'jobs',
    'stellen',
    'stellenangebote',
    'jobboerse',
    'bewerbung',
    'workday',
    'successfactors',
    'greenhouse',
    'smartrecruiters',
    'personio',
    'recruitee',
    'lever',
    'softgarden',
    'ashbyhq',
    'join.com'
)

$script:AtsDomainBindings = @(
    @{ system = 'Workday'; domain = 'myworkdayjobs.com' },
    @{ system = 'Workday'; domain = 'myworkdayjobs.de' },
    @{ system = 'SAP SuccessFactors'; domain = 'successfactors.eu' },
    @{ system = 'SAP SuccessFactors'; domain = 'successfactors.com' },
    @{ system = 'SAP SuccessFactors'; domain = 'sapsf.eu' },
    @{ system = 'Greenhouse'; domain = 'greenhouse.io' },
    @{ system = 'Greenhouse'; domain = 'boards.greenhouse.io' },
    @{ system = 'SmartRecruiters'; domain = 'smartrecruiters.com' },
    @{ system = 'Personio'; domain = 'jobs.personio.de' },
    @{ system = 'Personio'; domain = 'personio.de' },
    @{ system = 'Recruitee'; domain = 'recruitee.com' },
    @{ system = 'Lever'; domain = 'jobs.lever.co' },
    @{ system = 'Softgarden'; domain = 'softgarden.io' },
    @{ system = 'Ashby'; domain = 'ashbyhq.com' },
    @{ system = 'Join'; domain = 'join.com' }
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

function Get-JobAgentAtsBindingForUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url
    )

    $host = Get-JobAgentUrlHost -Url $Url
    foreach ($binding in $script:AtsDomainBindings) {
        if (Test-JobAgentDomainMatch -Host $host -Domain ([string]$binding.domain)) {
            return [pscustomobject]@{
                system = [string]$binding.system
                official_domain = [string]$binding.domain
            }
        }
    }
    return $null
}

function New-JobAgentCompanyCareerVerificationPolicy {
    [CmdletBinding()]
    param(
        [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
        [Parameter()][ValidateRange(1, 20)][int]$MaxFetchesPerCompany = 6,
        [Parameter()][ValidateRange(1, 20)][int]$MaxCandidatesPerCompany = 10,
        [Parameter()][string]$UserAgent = 'JobAgent/0.1 (+company-career-verification; fail-closed)'
    )

    [pscustomobject]@{
        timeout_seconds = $TimeoutSeconds
        max_fetches_per_company = $MaxFetchesPerCompany
        max_candidates_per_company = $MaxCandidatesPerCompany
        user_agent = $UserAgent
        policy = 'official-site-linked-career-or-ats-only'
    }
}

function Invoke-JobAgentCompanyVerificationHttpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][object]$Policy
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -Method Get `
            -TimeoutSec ([int]$Policy.timeout_seconds) `
            -UserAgent ([string]$Policy.user_agent) `
            -MaximumRedirection 5 `
            -ErrorAction Stop

        [pscustomobject]@{
            ok = $true
            url = $Url
            final_url = if ($response.BaseResponse.PSObject.Properties.Name -contains 'ResponseUri' -and $response.BaseResponse.ResponseUri) { [string]$response.BaseResponse.ResponseUri.AbsoluteUri } else { $Url }
            status_code = [int]$response.StatusCode
            content = [string]$response.Content
            content_type = [string]$response.Headers['Content-Type']
            error = $null
        }
    }
    catch {
        $statusCode = $null
        if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        [pscustomobject]@{
            ok = $false
            url = $Url
            final_url = $Url
            status_code = $statusCode
            content = ''
            content_type = ''
            error = $_.Exception.Message
        }
    }
}

function Get-JobAgentCompanyVerificationRedirectChain {
    param(
        [Parameter(Mandatory)][object]$Fetch
    )

    $chain = New-Object System.Collections.Generic.List[string]
    foreach ($property in @('url', 'final_url')) {
        if (($Fetch.PSObject.Properties.Name -contains $property) -and -not [string]::IsNullOrWhiteSpace([string]$Fetch.$property)) {
            $canonical = ConvertTo-JobAgentCanonicalUrl -Url ([string]$Fetch.$property)
            if (-not $chain.Contains($canonical)) {
                $chain.Add($canonical)
            }
        }
    }
    return $chain.ToArray()
}

function ConvertTo-JobAgentCompanyVerificationPlainText {
    param(
        [Parameter()][AllowEmptyString()][string]$Html,
        [Parameter()][ValidateRange(1, 400)][int]$MaxLength = 160
    )

    $text = [regex]::Replace($Html, '<(script|style)\b.*?</\1>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $text = [regex]::Replace($text, '<[^>]+>', ' ')
    $text = [Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength)
    }
    return $text
}

function Test-JobAgentCompanyCareerLinkText {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $normalized = $Value.ToLowerInvariant()
    foreach ($pattern in $script:CareerLinkPatterns) {
        if ($normalized.Contains($pattern)) {
            return $true
        }
    }
    return $false
}

function Get-JobAgentCompanyCareerCandidateLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 50)][int]$MaxCandidates = 10
    )

    $baseUri = [Uri]$BaseUrl
    $links = New-Object System.Collections.Generic.List[object]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $matches = [regex]::Matches($Html, '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($match in $matches) {
        if ($links.Count -ge $MaxCandidates) {
            break
        }
        $hrefMatch = [regex]::Match($match.Groups['attrs'].Value, 'href\s*=\s*["''](?<href>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $hrefMatch.Success) {
            continue
        }
        $href = [Net.WebUtility]::HtmlDecode($hrefMatch.Groups['href'].Value)
        if ($href -match '^(mailto:|tel:|javascript:|#)') {
            continue
        }
        $absolute = [Uri]::new($baseUri, $href).AbsoluteUri
        $text = ConvertTo-JobAgentCompanyVerificationPlainText -Html $match.Groups['text'].Value
        if (-not (Test-JobAgentCompanyCareerLinkText -Value ($text + ' ' + $absolute))) {
            continue
        }
        $canonical = ConvertTo-JobAgentCanonicalUrl -Url $absolute
        if (Test-JobAgentAggregatorUrl -Url $canonical) {
            continue
        }
        $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $canonical -AllowAtsEvidence:$false
        $atsBinding = Get-JobAgentAtsBindingForUrl -Url $canonical
        $isCompanyDomain = $evaluation.is_official -eq $true
        $isAts = $null -ne $atsBinding
        if ((-not $isCompanyDomain) -and (-not $isAts)) {
            continue
        }
        if ($seen.Add($canonical)) {
            $links.Add([pscustomobject]@{
                    url = $canonical
                    link_text = $text
                    source_url = ConvertTo-JobAgentCanonicalUrl -Url $BaseUrl
                    is_company_domain = $isCompanyDomain
                    ats = $atsBinding
                })
        }
    }
    return $links.ToArray()
}

function New-JobAgentCompanyCareerVerificationResult {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][string]$Status,
        [Parameter()][AllowNull()][string]$CareerUrl,
        [Parameter()][AllowNull()][object]$AtsBinding,
        [Parameter()][AllowNull()][object]$Evidence,
        [Parameter(Mandatory)][object[]]$Fetches,
        [Parameter(Mandatory)][string]$Reason
    )

    [pscustomobject]@{
        company_id = [string]$Company.company_id
        status = $Status
        career_url = $CareerUrl
        ats = $AtsBinding
        verification_evidence = if ($null -eq $Evidence) { @() } else { @($Evidence) }
        fetches = @($Fetches)
        reason = $Reason
    }
}

function Resolve-JobAgentCompanyCareerVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][object]$Policy = (New-JobAgentCompanyCareerVerificationPolicy),
        [Parameter()][scriptblock]$Fetcher
    )

    $fetches = New-Object System.Collections.Generic.List[object]
    $urlsToFetch = New-Object System.Collections.Generic.List[string]
    $seenFetchUrls = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($url in @($Company.official_website_url, $Company.career_url)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$url)) {
            $canonical = ConvertTo-JobAgentCanonicalUrl -Url ([string]$url)
            if ($seenFetchUrls.Add($canonical)) {
                $urlsToFetch.Add($canonical)
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Company.official_website_url)) {
        $website = [Uri](ConvertTo-JobAgentCanonicalUrl -Url ([string]$Company.official_website_url))
        foreach ($path in @('/sitemap.xml', '/sitemap_index.xml')) {
            $candidate = [Uri]::new($website, $path).AbsoluteUri
            if ($seenFetchUrls.Add($candidate)) {
                $urlsToFetch.Add($candidate)
            }
        }
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $urlsToFetch.Count -and $fetches.Count -lt [int]$Policy.max_fetches_per_company; $index++) {
        $url = [string]$urlsToFetch[$index]
        $fetch = if ($Fetcher) { & $Fetcher $url $Policy } else { Invoke-JobAgentCompanyVerificationHttpRequest -Url $url -Policy $Policy }
        $fetches.Add($fetch)
        if ($fetch.ok -ne $true) {
            continue
        }
        $finalUrl = if ([string]::IsNullOrWhiteSpace([string]$fetch.final_url)) { $url } else { [string]$fetch.final_url }
        foreach ($candidate in @(Get-JobAgentCompanyCareerCandidateLinks -Html ([string]$fetch.content) -BaseUrl $finalUrl -Company $Company -MaxCandidates ([int]$Policy.max_candidates_per_company))) {
            $candidates.Add($candidate)
        }
        foreach ($candidate in @($candidates | Where-Object { $_.is_company_domain -eq $true })) {
            if ($fetches.Count -ge [int]$Policy.max_fetches_per_company) {
                break
            }
            if ($seenFetchUrls.Add([string]$candidate.url)) {
                $candidateFetch = if ($Fetcher) { & $Fetcher ([string]$candidate.url) $Policy } else { Invoke-JobAgentCompanyVerificationHttpRequest -Url ([string]$candidate.url) -Policy $Policy }
                $fetches.Add($candidateFetch)
                if ($candidateFetch.ok -eq $true) {
                    $evidence = New-JobAgentVerificationEvidence `
                        -Status 'VERIFIED' `
                        -EvidenceType 'CAREER_URL' `
                        -Url ([string]$candidateFetch.final_url) `
                        -BasisUrl ([string]$candidate.source_url) `
                        -RedirectChain (Get-JobAgentCompanyVerificationRedirectChain -Fetch $candidateFetch) `
                        -Reason ('Karrierepfad wurde auf der offiziellen Website verlinkt: ' + [string]$candidate.link_text)
                    return New-JobAgentCompanyCareerVerificationResult -Company $Company -Status 'CAREER_URL_VERIFIED' -CareerUrl ([string]$evidence.url) -Evidence $evidence -Fetches $fetches.ToArray() -Reason 'Karriere-URL liegt auf offizieller Firmendomain und wurde per Link/HTTP belegt.'
                }
            }
        }
    }

    $atsCandidate = @($candidates | Where-Object { $null -ne $_.ats } | Select-Object -First 1)
    if ($atsCandidate.Count -gt 0) {
        $ats = [pscustomobject]@{
            system = [string]$atsCandidate[0].ats.system
            official_domain = [string]$atsCandidate[0].ats.official_domain
            verified_by_url = [string]$atsCandidate[0].source_url
        }
        $evidence = New-JobAgentVerificationEvidence `
            -Status 'VERIFIED' `
            -EvidenceType 'COMPANY_LINKED_ATS' `
            -Url ([string]$atsCandidate[0].url) `
            -BasisUrl ([string]$atsCandidate[0].source_url) `
            -RedirectChain @([string]$atsCandidate[0].source_url, [string]$atsCandidate[0].url) `
            -Reason ('ATS-URL wurde von der offiziellen Website verlinkt: ' + [string]$atsCandidate[0].link_text)
        return New-JobAgentCompanyCareerVerificationResult -Company $Company -Status 'ATS_VERIFIED_BY_COMPANY_LINK' -CareerUrl ([string]$atsCandidate[0].url) -AtsBinding $ats -Evidence $evidence -Fetches $fetches.ToArray() -Reason 'ATS-Karriere-URL ist ueber offiziellen Firmenlink belegt.'
    }

    $successfulFetches = @($fetches | Where-Object { $_.ok -eq $true })
    $dynamicOnly = $false
    if ($successfulFetches.Count -gt 0) {
        $plainText = ($successfulFetches | ForEach-Object { ConvertTo-JobAgentCompanyVerificationPlainText -Html ([string]$_.content) -MaxLength 400 }) -join ' '
        $scriptHeavy = @($successfulFetches | Where-Object { ([string]$_.content).ToLowerInvariant() -match '(__next_data__|__nuxt__|id="root"|id=''root''|id="app"|id=''app'')' -and ([string]$_.content).ToLowerInvariant() -notmatch '<a\b' }).Count -gt 0
        $dynamicOnly = $scriptHeavy -or ($plainText.ToLowerInvariant() -match '(enable javascript|javascript is required|requires javascript)')
    }
    $status = if ($dynamicOnly) { 'TECHNICAL_LIMITATION' } elseif ($successfulFetches.Count -gt 0) { 'MANUAL_REVIEW' } else { 'TECHNICAL_LIMITATION' }
    return New-JobAgentCompanyCareerVerificationResult -Company $Company -Status $status -CareerUrl $null -Fetches $fetches.ToArray() -Reason 'Kein offiziell belegter Karriere- oder ATS-Link wurde gefunden.'
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
    'Get-JobAgentAtsBindingForUrl',
    'Get-JobAgentOfficialSourceEvaluation',
    'Get-JobAgentCompanyCareerCandidateLinks',
    'New-JobAgentVerifiedJobSource',
    'New-JobAgentCompanyCareerVerificationPolicy',
    'Resolve-JobAgentOfficialJobUrl',
    'Resolve-JobAgentCompanyCareerVerification',
    'Test-JobAgentAggregatorUrl',
    'Test-JobAgentDomainMatch'
)
