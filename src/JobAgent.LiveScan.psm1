#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentLiveIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-JobAgentLiveStamp {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-JobAgentLiveScanPolicy {
    [CmdletBinding()]
    param(
        [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 20,
        [Parameter()][ValidateRange(0, 5)][int]$MaxRetries = 1,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxCompanies = 25,
        [Parameter()][ValidateRange(1, 100)][int]$MaxResultsPerSource = 100,
        [Parameter()][ValidateRange(1, 100)][int]$MaxDetailFetchesPerSource = 100,
        [Parameter()][ValidateRange(1, 20)][int]$MaxPagesPerSource = 10,
        [Parameter()][ValidateRange(1, 8)][int]$HostConcurrency = 1,
        [Parameter()][ValidateSet('auto', 'dotnet', 'curl', 'wsl-curl')][string]$FetchClient = 'auto',
        [Parameter()][string]$WslDistribution = 'Ubuntu-22.04',
        [Parameter()][string]$UserAgent = 'JobAgent/0.1 (+local-pilot; official-career-source-only)',
        [Parameter()][string[]]$SearchTerms = @('Head of IT', 'Director IT', 'IT Leitung', 'IT-Leitung', 'Leiter IT', 'CIO')
    )

    [pscustomobject]@{
        timeout_seconds = $TimeoutSeconds
        max_retries = $MaxRetries
        max_companies = $MaxCompanies
        max_results_per_source = $MaxResultsPerSource
        max_detail_fetches_per_source = $MaxDetailFetchesPerSource
        max_pages_per_source = $MaxPagesPerSource
        host_concurrency = $HostConcurrency
        fetch_client = $FetchClient
        wsl_distribution = $WslDistribution
        user_agent = $UserAgent
        search_terms = @($SearchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        source_policy = 'official-career-source-only'
        no_go = @('no_job_board_primary_source', 'no_login_bypass', 'no_captcha_bypass', 'no_unverified_job_claims')
    }
}

function Invoke-JobAgentLiveHttpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][object]$Policy
    )

    $started = [datetime]::UtcNow
    $result = Invoke-JobAgentCompanyVerificationHttpRequest -Url $Url -Policy $Policy
    $result | Add-Member -NotePropertyName started_at -NotePropertyValue (ConvertTo-JobAgentLiveIso -Value $started) -Force
    $result | Add-Member -NotePropertyName finished_at -NotePropertyValue (ConvertTo-JobAgentLiveIso -Value ([datetime]::UtcNow)) -Force
    return $result
}

function Invoke-JobAgentLiveFetchWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][object]$Policy,
        [Parameter()][scriptblock]$Fetcher
    )

    $attempts = New-Object System.Collections.Generic.List[object]
    $maxAttempts = 1 + [int]$Policy.max_retries
    for ($index = 1; $index -le $maxAttempts; $index++) {
        $result = if ($Fetcher) {
            & $Fetcher $Url $Policy $index
        }
        else {
            Invoke-JobAgentLiveHttpRequest -Url $Url -Policy $Policy
        }
        $attempts.Add($result)
        if ($result.ok -eq $true) {
            break
        }
    }

    $last = $attempts[$attempts.Count - 1]
    $last | Add-Member -NotePropertyName attempts -NotePropertyValue @($attempts.ToArray()) -Force
    return $last
}

function ConvertTo-JobAgentLivePlainText {
    [CmdletBinding()]
    param(
        [Parameter()][AllowEmptyString()][string]$Html,
        [Parameter()][ValidateRange(1, 2000)][int]$MaxLength = 500
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

function Get-JobAgentLiveTextValue {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [string]) {
        $text = $Value.Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }
        return $text
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            $resolved = Get-JobAgentLiveTextValue -Value $item
            if (-not [string]::IsNullOrWhiteSpace($resolved)) {
                return $resolved
            }
        }
        return $null
    }
    return Get-JobAgentLiveTextValue -Value ([string]$Value)
}

function Get-JobAgentLiveNestedValue {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Path
    )

    if ($Path.Count -eq 0) {
        return $Object
    }

    $current = $Object
    for ($index = 0; $index -lt $Path.Count; $index++) {
        $segment = $Path[$index]
        if ($null -eq $current) {
            return $null
        }
        if ($current -is [System.Collections.IEnumerable] -and -not ($current -is [string])) {
            foreach ($item in $current) {
                $resolved = Get-JobAgentLiveNestedValue -Object $item -Path $Path[$index..($Path.Count - 1)]
                if ($null -ne $resolved) {
                    return $resolved
                }
            }
            return $null
        }
        $propertyNames = @($current.PSObject.Properties | ForEach-Object { $_.Name })
        if ($propertyNames -notcontains $segment) {
            return $null
        }
        $current = $current.$segment
    }
    return $current
}

function Test-JobAgentLiveDetailUrlPattern {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)

    if (-not [Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace((Get-JobAgentLiveUrlJobId -Url $Url))) {
        return $true
    }

    return $Url -match '(?i)(jobid=|job_id=|gh_jid=|/job-details/[^/?#]+|/vacanc(y|ies)/[^/?#]+|/position/[^/?#]+|/posting/[^/?#]+|/requisition/[^/?#]+|lever\.co/[^/?#]+/[^/?#]+|workdayjobs.*/job/|smartrecruiters.*/jobs?/[^/?#]+|recruitee.*/o/[^/?#]+|join\.com.*/jobs?/[^/?#]+|personio.*/job/|softgarden.*/job/|ashbyhq.*/[^/?#]+|greenhouse\.io/[^/?#]+/jobs/[^/?#]+)'
}

function Test-JobAgentLiveExcludedContentUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)

    if (-not [Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        return $true
    }

    $path = ([Uri]$Url).AbsolutePath.ToLowerInvariant()
    return $path -match '(^|/)(news(room)?|stories|story|blog|press|media|event|events|case-stud(y|ies)|insights?|content)(/|$)'
}

function Test-JobAgentLiveCandidateText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter()][string[]]$SearchTerms = @()
    )

    $normalized = $Text.ToLowerInvariant()
    if ($normalized -match '\b(job|career|stelle|stellenangebot|position|head|director|leiter|leitung|manager|cio|it)\b') {
        return $true
    }
    foreach ($term in @($SearchTerms)) {
        if (-not [string]::IsNullOrWhiteSpace($term) -and $normalized.Contains($term.ToLowerInvariant())) {
            return $true
        }
    }
    return $false
}

function Test-JobAgentLiveConcreteJobCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Url,
        [Parameter()][string[]]$SearchTerms = @()
    )

    if (Test-JobAgentLiveExcludedContentUrl -Url $Url) {
        return $false
    }

    if (Test-JobAgentLiveDetailUrlPattern -Url $Url) {
        return $true
    }

    $normalized = $Text.ToLowerInvariant()
    foreach ($term in @($SearchTerms)) {
        if (-not [string]::IsNullOrWhiteSpace($term) -and $normalized.Contains($term.ToLowerInvariant())) {
            return $true
        }
    }

    return $normalized -match '\b(cio|head of it|director it|director information technology|it[- ]?leitung|leiter(in)? it|it[- ]?leiter(in)?|it[- ]?manager(in)?|it lead|lead it)\b'
}

function Test-JobAgentLiveListingSourceLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Url
    )

    try {
        $uri = [Uri]$Url
    }
    catch {
        return $false
    }

    if (Test-JobAgentLiveDetailUrlPattern -Url $Url) {
        return $false
    }

    $normalizedText = $Text.ToLowerInvariant()
    $normalizedUrl = ($uri.Host + $uri.AbsolutePath).ToLowerInvariant()
    return ($normalizedText -match '\b(job portal|jobportal|jobs|stellenangebote|stellenportal|offene stellen|open positions|vacancies|jobboerse|jobbörse)\b') -or
        ($normalizedUrl -match '(^|[./-])jobs?[./-]|/career(s)?/(jobs?|search|openings|vacancies)(/)?$')
}

function New-JobAgentLiveCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$DetailUrl,
        [Parameter(Mandatory)][string]$VerificationBasis,
        [Parameter()][AllowNull()][string]$ExternalJobId,
        [Parameter()][AllowNull()][string]$AtsJobId,
        [Parameter()][AllowNull()][string]$LocationLabel,
        [Parameter()][AllowNull()][string]$Summary,
        [Parameter()][AllowNull()][string]$EmploymentType,
        [Parameter()][ValidateRange(0, 100)][int]$ExtractionConfidence = 60
    )

    return [pscustomobject]@{
        title = $Title
        detail_url = $DetailUrl
        verification_basis = $VerificationBasis
        external_job_id = if ([string]::IsNullOrWhiteSpace($ExternalJobId)) { $null } else { $ExternalJobId }
        ats_job_id = if ([string]::IsNullOrWhiteSpace($AtsJobId)) { $null } else { $AtsJobId }
        location_label = if ([string]::IsNullOrWhiteSpace($LocationLabel)) { 'UNKNOWN' } else { $LocationLabel.Trim() }
        summary = if ([string]::IsNullOrWhiteSpace($Summary)) { $null } else { (ConvertTo-JobAgentLivePlainText -Html $Summary -MaxLength 500) }
        employment_type = if ([string]::IsNullOrWhiteSpace($EmploymentType)) { $null } else { $EmploymentType.Trim() }
        extraction_confidence = $ExtractionConfidence
    }
}

function Get-JobAgentLiveUrlJobId {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)

    try {
        $uri = [Uri]$Url
    }
    catch {
        return $null
    }

    foreach ($queryPair in @($uri.Query.TrimStart('?') -split '&')) {
        if ($queryPair -notmatch '^(?<name>[^=]+)=(?<value>.*)$') {
            continue
        }
        $name = [Uri]::UnescapeDataString($Matches.name)
        $value = [Uri]::UnescapeDataString($Matches.value)
        if ($name -match '^(?i:jobid|job_id|job|req|requisition|posting)$' -and $value -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') {
            return $value
        }
    }

    $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    for ($index = 1; $index -lt $segments.Count; $index++) {
        $prefix = [Uri]::UnescapeDataString($segments[$index - 1])
        $value = [Uri]::UnescapeDataString($segments[$index])
        if ($prefix -match '^(?i:job|jobs|job-details|posting|postings|req|requisition|requisitions)$' -and $value -match '^[A-Za-z0-9][A-Za-z0-9._-]{1,127}$') {
            return $value
        }
    }

    return $null
}

function Test-JobAgentLivePaginationHint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Html)

    return $Html -match '(?is)rel\s*=\s*["'']?next\b|\b(?:next|weiter|page|seite)\s*[=:]\s*\d+|[?&](?:page|offset|start)=\d+'
}

function ConvertTo-JobAgentLiveEvaluationUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)

    if ([Uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) {
        return $Url
    }
    $decoded = [Net.WebUtility]::UrlDecode($Url)
    if ($decoded -notmatch '\s' -and [Uri]::IsWellFormedUriString($decoded, [UriKind]::Absolute)) {
        return $decoded
    }
    return $Url
}

function Resolve-JobAgentLiveHrefUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Uri]$BaseUri,
        [Parameter(Mandatory)][string]$Href
    )

    if ($Href -match '^(?i:https?://)') {
        return ConvertTo-JobAgentLiveEvaluationUrl -Url $Href
    }
    return ConvertTo-JobAgentLiveEvaluationUrl -Url ([Uri]::new($BaseUri, $Href).AbsoluteUri)
}

function Get-JobAgentLiveNextPageUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 20)][int]$MaxPages = 10
    )

    if ([string]::IsNullOrWhiteSpace($Html) -or $MaxPages -le 1) {
        return @()
    }

    $baseUri = [Uri]$BaseUrl
    $urls = New-Object System.Collections.Generic.List[string]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $patterns = @(
        '<link\b(?<attrs>[^>]*)>',
        '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>'
    )

    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Html, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
            if ($urls.Count -ge ($MaxPages - 1)) {
                break
            }

            $attrs = [string]$match.Groups['attrs'].Value
            $text = if ($match.Groups['text'].Success) { ConvertTo-JobAgentLivePlainText -Html ([string]$match.Groups['text'].Value) -MaxLength 80 } else { '' }
            $relMatch = [regex]::Match($attrs, '\brel\s*=\s*["'']?([^"''>\s]+)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $hrefMatch = [regex]::Match($attrs, '\bhref\s*=\s*["''](?<href>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $hrefMatch.Success) {
                continue
            }

            $rel = if ($relMatch.Success) { [string]$relMatch.Groups[1].Value } else { '' }
            $href = [Net.WebUtility]::HtmlDecode($hrefMatch.Groups['href'].Value)
            $isNext = ($rel -match '(?i)\bnext\b') -or ($text -match '(?i)^(next|weiter|naechste|nächste|>)$') -or ($href -match '(?i)([?&](page|p|offset|start)=\d+|/page/\d+)')
            if (-not $isNext -or $href -match '^(mailto:|tel:|javascript:|#)') {
                continue
            }

            $absolute = Resolve-JobAgentLiveHrefUrl -BaseUri $baseUri -Href $href
            try {
                $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $absolute
                if ($evaluation.is_official -eq $true -and $seen.Add($absolute)) {
                    $urls.Add($absolute)
                }
            }
            catch {
                continue
            }
        }
    }

    return $urls.ToArray()
}

function Get-JobAgentLiveEmbeddedSourceUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 20)][int]$MaxUrls = 10
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return @()
    }

    $baseUri = [Uri]$BaseUrl
    $urls = New-Object System.Collections.Generic.List[string]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($Html, '<(?:iframe|frame)\b(?<attrs>[^>]*)>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($urls.Count -ge $MaxUrls) {
            break
        }

        $attrs = [string]$match.Groups['attrs'].Value
        $srcMatch = [regex]::Match($attrs, '\b(?:src|data-src)\s*=\s*["''](?<src>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $srcMatch.Success) {
            continue
        }

        $src = [Net.WebUtility]::HtmlDecode($srcMatch.Groups['src'].Value)
        if ([string]::IsNullOrWhiteSpace($src) -or $src -match '^(mailto:|tel:|javascript:|#|about:)') {
            continue
        }

        try {
            $absolute = Resolve-JobAgentLiveHrefUrl -BaseUri $baseUri -Href $src
            $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $absolute
            if ($evaluation.is_official -eq $true -and $seen.Add([string]$evaluation.canonical_url)) {
                $urls.Add([string]$evaluation.canonical_url)
            }
        }
        catch {
            continue
        }
    }

    return $urls.ToArray()
}

function Get-JobAgentLiveLinkedSourceUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 20)][int]$MaxUrls = 10
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return @()
    }

    $baseUri = [Uri]$BaseUrl
    $urls = New-Object System.Collections.Generic.List[string]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($Html, '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        if ($urls.Count -ge $MaxUrls) {
            break
        }

        $hrefMatch = [regex]::Match($match.Groups['attrs'].Value, '\bhref\s*=\s*["''](?<href>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $hrefMatch.Success) {
            continue
        }

        $href = [Net.WebUtility]::HtmlDecode($hrefMatch.Groups['href'].Value)
        if ([string]::IsNullOrWhiteSpace($href) -or $href -match '^(mailto:|tel:|javascript:|#)') {
            continue
        }

        try {
            $absolute = Resolve-JobAgentLiveHrefUrl -BaseUri $baseUri -Href $href
            $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $absolute
            $text = ConvertTo-JobAgentLivePlainText -Html $match.Groups['text'].Value -MaxLength 120
            if ($evaluation.is_official -eq $true -and (Test-JobAgentLiveListingSourceLink -Text $text -Url ([string]$evaluation.canonical_url)) -and $seen.Add([string]$evaluation.canonical_url)) {
                $urls.Add([string]$evaluation.canonical_url)
            }
        }
        catch {
            continue
        }
    }

    return $urls.ToArray()
}

function Test-JobAgentLiveSuccessFactorsPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl
    )

    try {
        $uri = [Uri]$BaseUrl
    }
    catch {
        return $false
    }

    $hostPath = ($uri.Host + $uri.AbsolutePath).ToLowerInvariant()
    if (($hostPath -match '(^|\.)(jobs|careers)\.' -or $hostPath -match '(^|/)career(s)?(/|$)') -and $Html -match '(?is)\bj2w\.init\s*\(|\bssoCompanyId\b|\bsearchresults\b|\bjobTitle-link\b') {
        return $true
    }
    return $false
}

function Get-JobAgentLiveSuccessFactorsSearchUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 20)][int]$MaxUrls = 10
    )

    if (-not (Test-JobAgentLiveSuccessFactorsPage -Html $Html -BaseUrl $BaseUrl)) {
        return @()
    }

    try {
        $uri = [Uri]$BaseUrl
        $builder = [UriBuilder]::new($uri.Scheme, $uri.Host, $uri.Port, '/search/')
        $builder.Query = 'createNewAlert=false&q=&locationsearch='
        $searchUrl = $builder.Uri.AbsoluteUri
        $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $searchUrl
        if ($evaluation.is_official -eq $true) {
            return @([string]$evaluation.canonical_url)
        }
    }
    catch {
        return @()
    }

    return @()
}

function Get-JobAgentLiveJsonLdNodes {
    param([Parameter()][AllowNull()][object]$Node)

    $nodes = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Node) {
        return @()
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) {
            foreach ($resolved in @(Get-JobAgentLiveJsonLdNodes -Node $item)) {
                $nodes.Add($resolved)
            }
        }
        return $nodes.ToArray()
    }

    $nodes.Add($Node)
    $propertyNames = @($Node.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($propertyName in @('@graph', 'graph', 'itemListElement', 'jobs', 'postings', 'positions', 'results', 'openings', 'data', 'result', 'allGreenhouseJob', 'edges')) {
        if ($propertyNames -contains $propertyName) {
            foreach ($resolved in @(Get-JobAgentLiveJsonLdNodes -Node $Node.$propertyName)) {
                $nodes.Add($resolved)
            }
        }
    }
    foreach ($propertyName in @('item', 'node')) {
        if ($propertyNames -contains $propertyName) {
            foreach ($resolved in @(Get-JobAgentLiveJsonLdNodes -Node $Node.$propertyName)) {
                $nodes.Add($resolved)
            }
        }
    }
    return $nodes.ToArray()
}

function ConvertTo-JobAgentLiveSlug {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $normalized = $Value.ToLowerInvariant()
    $normalized = $normalized.Normalize([Text.NormalizationForm]::FormD)
    $normalized = [regex]::Replace($normalized, '\p{Mn}', '')
    $normalized = [regex]::Replace($normalized, '[^a-z0-9]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return 'job'
    }
    return $normalized
}

function ConvertTo-JobAgentLiveGreenhouseDetailUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$JobId,
        [Parameter(Mandatory)][string]$Title
    )

    if (-not [Uri]::IsWellFormedUriString($BaseUrl, [UriKind]::Absolute)) {
        return $null
    }

    $uri = [Uri]$BaseUrl
    $path = $uri.AbsolutePath.TrimEnd('/')
    if ($path -match '(?i)/page-data/' -or [string]::IsNullOrWhiteSpace($path)) {
        return $null
    }
    if ($path -notmatch '(?i)/jobs$') {
        $path = "$path/jobs"
    }

    $builder = [UriBuilder]::new($uri.Scheme, $uri.Host, $uri.Port, "$path/$JobId-$(ConvertTo-JobAgentLiveSlug -Value $Title)")
    $builder.Query = "gh_jid=$JobId"
    return $builder.Uri.AbsoluteUri
}

function Get-JobAgentLiveGatsbyStaticQueryUrls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter()][ValidateRange(1, 20)][int]$MaxUrls = 10
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return @()
    }

    try {
        $baseUri = [Uri]$BaseUrl
    }
    catch {
        return @()
    }

    $hashes = [Collections.Generic.List[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($Html, '"staticQueryHashes"\s*:\s*\[(?<hashes>.*?)\]', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)) {
        foreach ($hashMatch in [regex]::Matches([string]$match.Groups['hashes'].Value, '"(?<hash>[0-9]{6,})"')) {
            $hash = [string]$hashMatch.Groups['hash'].Value
            if ($seen.Add($hash)) {
                $hashes.Add($hash)
            }
            if ($hashes.Count -ge $MaxUrls) {
                break
            }
        }
        if ($hashes.Count -ge $MaxUrls) {
            break
        }
    }

    foreach ($hashMatch in [regex]::Matches($Html, '/page-data/sq/d/(?<hash>[0-9]{6,})\.json', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        if ($hashes.Count -ge $MaxUrls) {
            break
        }
        $hash = [string]$hashMatch.Groups['hash'].Value
        if ($seen.Add($hash)) {
            $hashes.Add($hash)
        }
    }

    return @($hashes | ForEach-Object {
            ([Uri]::new($baseUri, "/page-data/sq/d/$_.json")).AbsoluteUri
        })
}

function Add-JobAgentLiveSourcePageQueueItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.Generic.Queue[object]]$Queue,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$Seen,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ParseBaseUrl
    )

    if ($Seen.Add($Url)) {
        $Queue.Enqueue([pscustomobject]@{
                url = $Url
                parse_base_url = $ParseBaseUrl
        })
    }
}

function Get-JobAgentLiveStructuredValue {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Node,
        [Parameter(Mandatory)][string[][]]$Paths
    )

    foreach ($path in $Paths) {
        $resolved = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $Node -Path $path)
        if (-not [string]::IsNullOrWhiteSpace($resolved)) {
            return $resolved
        }
    }

    return $null
}

function ConvertFrom-JobAgentLiveJsonLdCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 100)][int]$MaxResults = 10
    )

    $scriptMatches = [regex]::Matches($Html, '<script\b[^>]*type\s*=\s*["'']application/(?:ld\+json|json)["''][^>]*>(?<json>.*?)</script>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $jsonTexts = New-Object System.Collections.Generic.List[string]
    foreach ($match in $scriptMatches) {
        $jsonTexts.Add([Net.WebUtility]::HtmlDecode($match.Groups['json'].Value).Trim())
    }
    $plainContent = $Html.Trim()
    if ($jsonTexts.Count -eq 0 -and ($plainContent.StartsWith('{') -or $plainContent.StartsWith('['))) {
        $jsonTexts.Add($plainContent)
    }
    $candidates = New-Object System.Collections.Generic.List[object]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($jsonText in $jsonTexts) {
        if ($candidates.Count -ge $MaxResults) {
            break
        }

        if ([string]::IsNullOrWhiteSpace($jsonText)) {
            continue
        }

        try {
            $parsed = $jsonText | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        }
        catch {
            continue
        }

        foreach ($node in @(Get-JobAgentLiveJsonLdNodes -Node $parsed)) {
            if ($candidates.Count -ge $MaxResults) {
                break
            }

            $typeText = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('@type'))
            $detailUrlRaw = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('url'),
                @('absolute_url'),
                @('absoluteUrl'),
                @('hosted_url'),
                @('hostedUrl'),
                @('apply_url'),
                @('applyUrl')
            )
            $title = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('title'),
                @('text'),
                @('name')
            )
            if ([string]::IsNullOrWhiteSpace($title)) {
                continue
            }

            $greenhouseJobId = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('gh_Id'),
                @('gh_id'),
                @('ghJid')
            )
            if ([string]::IsNullOrWhiteSpace($detailUrlRaw) -and -not [string]::IsNullOrWhiteSpace($greenhouseJobId)) {
                $detailUrlRaw = ConvertTo-JobAgentLiveGreenhouseDetailUrl -BaseUrl $BaseUrl -JobId $greenhouseJobId -Title $title
            }
            if ([string]::IsNullOrWhiteSpace($detailUrlRaw)) {
                continue
            }

            $detailUrl = ConvertTo-JobAgentLiveEvaluationUrl -Url ([Uri]::new([Uri]$BaseUrl, $detailUrlRaw).AbsoluteUri)
            $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $detailUrl
            if ($evaluation.is_official -ne $true) {
                continue
            }

            $isJobPosting = -not [string]::IsNullOrWhiteSpace($typeText) -and $typeText -match '(?i)\bJobPosting\b'
            if ((-not $isJobPosting) -and (-not (Test-JobAgentLiveConcreteJobCandidate -Text $title -Url ([string]$evaluation.canonical_url)))) {
                continue
            }

            $externalJobId = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('identifier', 'value'),
                @('identifier'),
                @('id'),
                @('jobId'),
                @('job_id'),
                @('gh_Id'),
                @('gh_id'),
                @('ghJid'),
                @('requisition_id'),
                @('requisitionId')
            )
            $locationLabel = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('jobLocation', 'address', 'addressLocality'),
                @('jobLocation', 'name'),
                @('location', 'name'),
                @('categories', 'location'),
                @('workplace', 'location'),
                @('location')
            )
            $employmentType = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('employmentType'),
                @('categories', 'commitment'),
                @('type')
            )
            $summary = Get-JobAgentLiveStructuredValue -Node $node -Paths @(
                @('description'),
                @('descriptionPlain'),
                @('content')
            )
            $confidence = if ($isJobPosting) { 90 } else { 82 }

            if ($seen.Add([string]$evaluation.canonical_url)) {
                $candidates.Add((New-JobAgentLiveCandidate `
                        -Title $title `
                        -DetailUrl ([string]$evaluation.canonical_url) `
                        -VerificationBasis ([string]$evaluation.verification_basis) `
                        -ExternalJobId $externalJobId `
                        -AtsJobId $externalJobId `
                        -LocationLabel $locationLabel `
                        -Summary $summary `
                        -EmploymentType $employmentType `
                        -ExtractionConfidence $confidence))
            }
        }
    }

    return $candidates.ToArray()
}

function ConvertFrom-JobAgentLiveCareerPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][ValidateRange(1, 100)][int]$MaxResults = 10,
        [Parameter()][string[]]$SearchTerms = @()
    )

    $baseUri = [Uri]$BaseUrl
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @(ConvertFrom-JobAgentLiveJsonLdCandidates -Html $Html -BaseUrl $BaseUrl -Company $Company -MaxResults $MaxResults)) {
        if ($candidates.Count -ge $MaxResults) {
            break
        }
        if ($seen.Add([string]$candidate.detail_url)) {
            $candidates.Add($candidate)
        }
    }

    $matches = [regex]::Matches($Html, '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($match in $matches) {
        if ($candidates.Count -ge $MaxResults) {
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
        $absolute = Resolve-JobAgentLiveHrefUrl -BaseUri $baseUri -Href $href
        $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $absolute
        if ($evaluation.is_official -ne $true) {
            continue
        }
        $text = ConvertTo-JobAgentLivePlainText -Html $match.Groups['text'].Value -MaxLength 160
        if (-not (Test-JobAgentLiveConcreteJobCandidate -Text $text -Url ([string]$evaluation.canonical_url) -SearchTerms $SearchTerms)) {
            continue
        }
        if ($seen.Add([string]$evaluation.canonical_url)) {
            $candidates.Add((New-JobAgentLiveCandidate `
                    -Title $(if ([string]::IsNullOrWhiteSpace($text)) { 'UNKNOWN' } else { $text }) `
                    -DetailUrl ([string]$evaluation.canonical_url) `
                    -VerificationBasis ([string]$evaluation.verification_basis) `
                    -ExtractionConfidence 65))
        }
    }
    return $candidates.ToArray()
}

function ConvertTo-JobAgentLiveErrorClass {
    param([Parameter()][AllowNull()][object]$FetchResult)

    if ($null -eq $FetchResult) {
        return 'TECHNICAL_LIMITATION'
    }
    if (($FetchResult.PSObject.Properties.Name -contains 'error_class') -and -not [string]::IsNullOrWhiteSpace([string]$FetchResult.error_class)) {
        switch ([string]$FetchResult.error_class) {
            'TIMEOUT' { return 'TIMEOUT' }
            'BLOCKED' { return 'BLOCKED' }
            default { return 'NOT_REACHABLE' }
        }
    }
    $statusCode = if ($FetchResult.PSObject.Properties.Name -contains 'status_code') { $FetchResult.status_code } else { $null }
    if ($statusCode -eq 408 -or $statusCode -eq 504) {
        return 'TIMEOUT'
    }
    if ($statusCode -eq 401 -or $statusCode -eq 403 -or $statusCode -eq 429) {
        return 'BLOCKED'
    }
    if ($statusCode -ge 500) {
        return 'NOT_REACHABLE'
    }
    return 'NOT_REACHABLE'
}

function Format-JobAgentLiveFetchFailureMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter()][AllowNull()][object]$FetchResult,
        [Parameter()][AllowNull()][string]$Url
    )

    $sourceUrl = if (-not [string]::IsNullOrWhiteSpace($Url)) { $Url } elseif ($null -ne $FetchResult -and $FetchResult.PSObject.Properties.Name -contains 'url') { [string]$FetchResult.url } else { 'UNKNOWN' }
    $errorClass = if ($null -ne $FetchResult -and $FetchResult.PSObject.Properties.Name -contains 'error_class' -and -not [string]::IsNullOrWhiteSpace([string]$FetchResult.error_class)) { [string]$FetchResult.error_class } else { ConvertTo-JobAgentLiveErrorClass -FetchResult $FetchResult }
    $client = if ($null -ne $FetchResult -and $FetchResult.PSObject.Properties.Name -contains 'fetch_client' -and -not [string]::IsNullOrWhiteSpace([string]$FetchResult.fetch_client)) { [string]$FetchResult.fetch_client } else { 'dotnet' }
    $detail = if ($null -ne $FetchResult -and $FetchResult.PSObject.Properties.Name -contains 'error_detail' -and -not [string]::IsNullOrWhiteSpace([string]$FetchResult.error_detail)) { [string]$FetchResult.error_detail } elseif ($null -ne $FetchResult -and $FetchResult.PSObject.Properties.Name -contains 'error') { [string]$FetchResult.error } else { 'UNKNOWN' }
    $normalizedDetail = [regex]::Replace($detail, '\x00', '')
    $normalizedDetail = [regex]::Replace($normalizedDetail, '\s+', ' ').Trim()
    if ($normalizedDetail.Length -gt 300) {
        $normalizedDetail = $normalizedDetail.Substring(0, 300).Trim()
    }
    return "$Prefix[$errorClass][$client]: $sourceUrl`: $normalizedDetail"
}

function Test-JobAgentLiveBlockedContentHint {
    [CmdletBinding()]
    param([Parameter()][AllowEmptyString()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $false
    }

    $text = (ConvertTo-JobAgentLivePlainText -Html $Html -MaxLength 1500).ToLowerInvariant()
    return $text -match '(access denied|forbidden|captcha|security check|verify you are human|unusual traffic|blocked request|bot detection|cloudflare)'
}

function Test-JobAgentLiveDynamicContentHint {
    [CmdletBinding()]
    param([Parameter()][AllowEmptyString()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $false
    }

    $normalized = $Html.ToLowerInvariant()
    $hasAppShell = $normalized -match '(__next_data__|__nuxt__|window\.__initial_state__|data-reactroot|id="app"|id=''app''|id="root"|id=''root''|ng-version=|application/json)'
    $hasScriptHeavyMarkup = $normalized -match '<script\b' -and $normalized -notmatch '<a\b'
    $hasJsRequirement = (ConvertTo-JobAgentLivePlainText -Html $Html -MaxLength 1500).ToLowerInvariant() -match '(enable javascript|javascript is required|requires javascript|client-side rendering)'
    return $hasJsRequirement -or ($hasAppShell -and $hasScriptHeavyMarkup)
}

function Resolve-JobAgentLiveRetryRecommendation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ErrorClass)

    switch ($ErrorClass) {
        'TIMEOUT' { return 'RETRY_NEXT_RUN' }
        'NOT_REACHABLE' { return 'RETRY_NEXT_RUN' }
        'BLOCKED' { return 'MANUAL_REVIEW' }
        'TECHNICAL_LIMITATION' { return 'MANUAL_REVIEW' }
        default { return 'MANUAL_REVIEW' }
    }
}

function Resolve-JobAgentLiveFailureOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Failures,
        [Parameter()][string]$DefaultErrorClass = 'UNCLEAR_SOURCE'
    )

    $errorClasses = @(
        $Failures |
            ForEach-Object { ConvertTo-JobAgentLiveErrorClass -FetchResult $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
    $distinct = @($errorClasses | Select-Object -Unique)
    $resolved = if ($distinct.Count -eq 1) { [string]$distinct[0] } else { $DefaultErrorClass }
    [pscustomobject]@{
        error_class = $resolved
        retry_recommendation = Resolve-JobAgentLiveRetryRecommendation -ErrorClass $resolved
    }
}

function New-JobAgentLiveRawJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$DetailFetch
    )

    $detailTitle = Get-JobAgentLiveDetailTitle -Html ([string]$DetailFetch.content)
    $candidateTitle = [string]$Candidate.title
    $title = if ((Test-JobAgentLiveGenericActionTitle -Title $candidateTitle) -and -not [string]::IsNullOrWhiteSpace($detailTitle)) {
        $detailTitle
    }
    else {
        $candidateTitle
    }
    $summary = ConvertTo-JobAgentLivePlainText -Html ([string]$DetailFetch.content) -MaxLength 500
    if ([string]::IsNullOrWhiteSpace($summary) -and $Candidate.PSObject.Properties.Name -contains 'summary') {
        $summary = [string]$Candidate.summary
    }
    $urlJobId = Get-JobAgentLiveUrlJobId -Url ([string]$Candidate.detail_url)
    $externalId = if (($Candidate.PSObject.Properties.Name -contains 'external_job_id') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.external_job_id)) { [string]$Candidate.external_job_id } elseif (-not [string]::IsNullOrWhiteSpace($urlJobId)) { $urlJobId } else { $null }
    $atsJobId = if (($Candidate.PSObject.Properties.Name -contains 'ats_job_id') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.ats_job_id)) { [string]$Candidate.ats_job_id } else { $externalId }
    $job = New-JobAgentRawJob `
        -Title $title `
        -DetailUrl ([string]$Candidate.detail_url) `
        -ExternalJobId $externalId `
        -AtsJobId $atsJobId `
        -LocationLabel $(if (($Candidate.PSObject.Properties.Name -contains 'location_label') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.location_label)) { [string]$Candidate.location_label } else { 'UNKNOWN' }) `
        -Summary $summary `
        -ExtractionConfidence $(if (($Candidate.PSObject.Properties.Name -contains 'extraction_confidence') -and $null -ne $Candidate.extraction_confidence) { [int]$Candidate.extraction_confidence } else { 60 }) `
        -SourceStatus 'ACTIVE'
    if (($Candidate.PSObject.Properties.Name -contains 'employment_type') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.employment_type)) {
        $job | Add-Member -NotePropertyName employment_type -NotePropertyValue ([string]$Candidate.employment_type) -Force
    }
    $job | Add-Member -NotePropertyName live_verification -NotePropertyValue ([pscustomobject]@{
        detail_http_status = [int]$DetailFetch.status_code
        detail_final_url = [string]$DetailFetch.final_url
        verification_basis = [string]$Candidate.verification_basis
    }) -Force
    return $job
}

function Test-JobAgentLiveGenericActionTitle {
    [CmdletBinding()]
    param([Parameter()][AllowNull()][string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $true
    }

    $normalized = [regex]::Replace($Title.ToLowerInvariant(), '\s+', ' ').Trim()
    return $normalized -match '^(learn more|mehr erfahren|details?|view job|show more|read more|apply|apply now|jetzt bewerben|bewerben)$'
}

function Get-JobAgentLiveDetailTitle {
    [CmdletBinding()]
    param([Parameter()][AllowEmptyString()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $null
    }

    $patterns = @(
        '<h1\b[^>]*>(?<value>.*?)</h1>',
        '<meta\b(?=[^>]*\bproperty\s*=\s*["'']og:title["''])(?=[^>]*\bcontent\s*=\s*["''](?<value>[^"'']+)["''])[^>]*>',
        '<title\b[^>]*>(?<value>.*?)</title>'
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Html, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $match.Success) {
            continue
        }

        $title = ConvertTo-JobAgentLivePlainText -Html ([string]$match.Groups['value'].Value) -MaxLength 180
        $title = [regex]::Replace($title, '\s+[-|]\s+.*$', '').Trim()
        if (-not [string]::IsNullOrWhiteSpace($title) -and -not (Test-JobAgentLiveGenericActionTitle -Title $title)) {
            return $title
        }
    }

    return $null
}

function Invoke-JobAgentLiveHtmlAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter()][object]$Policy = (New-JobAgentLiveScanPolicy),
        [Parameter()][scriptblock]$Fetcher
    )

    $startedAt = [datetime]::UtcNow
    $maxPages = if ($Policy.PSObject.Properties.Name -contains 'max_pages_per_source') { [int]$Policy.max_pages_per_source } else { 1 }
    $sourceFetch = Invoke-JobAgentLiveFetchWithRetry -Url ([string]$AdapterInput.source.canonical_url) -Policy $Policy -Fetcher $Fetcher
    if ($sourceFetch.ok -ne $true) {
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'FAILED' `
            -ErrorClass (ConvertTo-JobAgentLiveErrorClass -FetchResult $sourceFetch) `
            -RetryRecommendation 'RETRY_NEXT_RUN' `
            -RawJobs @() `
            -HttpStatus $sourceFetch.status_code `
            -ArtifactPaths @((Format-JobAgentLiveFetchFailureMessage -Prefix 'source_fetch_failed' -FetchResult $sourceFetch -Url ([string]$AdapterInput.source.canonical_url))) `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    $sourceFetches = New-Object System.Collections.Generic.List[object]
    $sourceFetches.Add($sourceFetch)
    $pageUrlsToFetch = New-Object System.Collections.Generic.Queue[object]
    $seenPageUrls = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [void]$seenPageUrls.Add([string]$sourceFetch.final_url)
    $initialFollowUps = @(
        @(Get-JobAgentLiveSuccessFactorsSearchUrls -Html ([string]$sourceFetch.content) -BaseUrl ([string]$sourceFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
        @(Get-JobAgentLiveEmbeddedSourceUrls -Html ([string]$sourceFetch.content) -BaseUrl ([string]$sourceFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
        @(Get-JobAgentLiveLinkedSourceUrls -Html ([string]$sourceFetch.content) -BaseUrl ([string]$sourceFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
        @(Get-JobAgentLiveNextPageUrls -Html ([string]$sourceFetch.content) -BaseUrl ([string]$sourceFetch.final_url) -Company $AdapterInput.company -MaxPages $maxPages)
    )
    foreach ($nextUrl in $initialFollowUps) {
        Add-JobAgentLiveSourcePageQueueItem -Queue $pageUrlsToFetch -Seen $seenPageUrls -Url $nextUrl -ParseBaseUrl $nextUrl
    }
    foreach ($nextUrl in @(Get-JobAgentLiveGatsbyStaticQueryUrls -Html ([string]$sourceFetch.content) -BaseUrl ([string]$sourceFetch.final_url) -MaxUrls $maxPages)) {
        Add-JobAgentLiveSourcePageQueueItem -Queue $pageUrlsToFetch -Seen $seenPageUrls -Url $nextUrl -ParseBaseUrl ([string]$sourceFetch.final_url)
    }

    while ($pageUrlsToFetch.Count -gt 0 -and $sourceFetches.Count -lt $maxPages) {
        $pageItem = $pageUrlsToFetch.Dequeue()
        $pageUrl = [string]$pageItem.url
        $pageFetch = Invoke-JobAgentLiveFetchWithRetry -Url $pageUrl -Policy $Policy -Fetcher $Fetcher
        $pageFetch | Add-Member -NotePropertyName content_base_url -NotePropertyValue ([string]$pageItem.parse_base_url) -Force
        $sourceFetches.Add($pageFetch)
        if ($pageFetch.ok -ne $true) {
            continue
        }
        $followUps = @(
            @(Get-JobAgentLiveSuccessFactorsSearchUrls -Html ([string]$pageFetch.content) -BaseUrl ([string]$pageFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
            @(Get-JobAgentLiveEmbeddedSourceUrls -Html ([string]$pageFetch.content) -BaseUrl ([string]$pageFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
            @(Get-JobAgentLiveLinkedSourceUrls -Html ([string]$pageFetch.content) -BaseUrl ([string]$pageFetch.final_url) -Company $AdapterInput.company -MaxUrls $maxPages) +
            @(Get-JobAgentLiveNextPageUrls -Html ([string]$pageFetch.content) -BaseUrl ([string]$pageFetch.final_url) -Company $AdapterInput.company -MaxPages $maxPages)
        )
        foreach ($nextUrl in $followUps) {
            Add-JobAgentLiveSourcePageQueueItem -Queue $pageUrlsToFetch -Seen $seenPageUrls -Url $nextUrl -ParseBaseUrl $nextUrl
        }
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    $seenCandidateUrls = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($fetch in @($sourceFetches.ToArray() | Where-Object { $_.ok -eq $true })) {
        $parseBaseUrl = if ($fetch.PSObject.Properties.Name -contains 'content_base_url' -and -not [string]::IsNullOrWhiteSpace([string]$fetch.content_base_url)) { [string]$fetch.content_base_url } else { [string]$fetch.final_url }
        foreach ($candidate in @(ConvertFrom-JobAgentLiveCareerPage `
                    -Html ([string]$fetch.content) `
                    -BaseUrl $parseBaseUrl `
                    -Company $AdapterInput.company `
                    -MaxResults ([int]$Policy.max_results_per_source) `
                    -SearchTerms @($Policy.search_terms))) {
            if ($candidates.Count -ge [int]$Policy.max_results_per_source) {
                break
            }
            if ($seenCandidateUrls.Add([string]$candidate.detail_url)) {
                $candidates.Add($candidate)
            }
        }
        if ($candidates.Count -ge [int]$Policy.max_results_per_source) {
            break
        }
    }
    if ($candidates.Count -eq 0) {
        $blockedByContent = Test-JobAgentLiveBlockedContentHint -Html ([string]$sourceFetch.content)
        $dynamicOnly = if (-not $blockedByContent) { Test-JobAgentLiveDynamicContentHint -Html ([string]$sourceFetch.content) } else { $false }
        $failedPageFetches = @($sourceFetches.ToArray() | Where-Object { $_.ok -ne $true })
        $unprocessedPageHint = ($pageUrlsToFetch.Count -gt 0) -or ($sourceFetches.Count -ge $maxPages -and @($sourceFetches.ToArray() | Where-Object { $_.ok -eq $true -and ((Test-JobAgentLivePaginationHint -Html ([string]$_.content)) -eq $true) }).Count -gt 0)
        if ((-not $blockedByContent) -and (-not $dynamicOnly) -and $failedPageFetches.Count -eq 0 -and (-not $unprocessedPageHint)) {
            return New-JobAgentAdapterResult `
                -AdapterInput $AdapterInput `
                -AdapterName 'live-html-adapter' `
                -Status 'SUCCESS' `
                -ErrorClass 'NONE' `
                -RetryRecommendation 'NONE' `
                -RawJobs @() `
                -HttpStatus $sourceFetch.status_code `
                -ArtifactPaths @('no_verified_job_candidates_complete') `
                -IsComplete $true `
                -StartedAt $startedAt `
                -FinishedAt ([datetime]::UtcNow)
        }
        $errorClass = if ($blockedByContent) { 'BLOCKED' } elseif ($dynamicOnly) { 'TECHNICAL_LIMITATION' } else { 'NO_JOBS_FOUND' }
        $retryRecommendation = Resolve-JobAgentLiveRetryRecommendation -ErrorClass $errorClass
        $artifactPath = if ($blockedByContent) { 'source_blocked_or_challenged' } elseif ($dynamicOnly) { 'dynamic_client_side_only' } else { 'no_verified_job_candidates' }
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass $errorClass `
            -RetryRecommendation $retryRecommendation `
            -RawJobs @() `
            -HttpStatus $sourceFetch.status_code `
            -ArtifactPaths @($artifactPath) `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    $jobs = New-Object System.Collections.Generic.List[object]
    $detailFailures = New-Object System.Collections.Generic.List[object]
    $messages = New-Object System.Collections.Generic.List[string]
    $candidateItems = @($candidates.ToArray())
    $detailBudgetReached = $candidateItems.Count -gt [int]$Policy.max_detail_fetches_per_source
    foreach ($candidate in @($candidateItems | Select-Object -First ([int]$Policy.max_detail_fetches_per_source))) {
        $detailFetch = Invoke-JobAgentLiveFetchWithRetry -Url ([string]$candidate.detail_url) -Policy $Policy -Fetcher $Fetcher
        if ($detailFetch.ok -eq $true) {
            $jobs.Add((New-JobAgentLiveRawJob -Candidate $candidate -DetailFetch $detailFetch))
        }
        else {
            $detailFailures.Add($detailFetch)
            $failureClass = ConvertTo-JobAgentLiveErrorClass -FetchResult $detailFetch
            $messages.Add((Format-JobAgentLiveFetchFailureMessage -Prefix 'detail_fetch_failed' -FetchResult $detailFetch -Url ([string]$candidate.detail_url)))
        }
    }

    if ($jobs.Count -eq 0) {
        $failureOutcome = Resolve-JobAgentLiveFailureOutcome -Failures @($detailFailures.ToArray())
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass ([string]$failureOutcome.error_class) `
            -RetryRecommendation ([string]$failureOutcome.retry_recommendation) `
            -RawJobs @() `
            -HttpStatus $sourceFetch.status_code `
            -ArtifactPaths @($messages.ToArray()) `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    $resultLimited = $candidateItems.Count -ge [int]$Policy.max_results_per_source
    $paginationDetected = ($pageUrlsToFetch.Count -gt 0) -or ($sourceFetches.Count -ge $maxPages -and @($sourceFetches.ToArray() | Where-Object { $_.ok -eq $true -and ((Test-JobAgentLivePaginationHint -Html ([string]$_.content)) -eq $true) }).Count -gt 0)
    if ($detailBudgetReached -or $resultLimited -or $paginationDetected -or $detailFailures.Count -gt 0) {
        $incompleteReasons = New-Object System.Collections.Generic.List[string]
        if ($detailBudgetReached) { $incompleteReasons.Add('detail_fetch_limit_reached') }
        if ($resultLimited) { $incompleteReasons.Add('result_limit_reached') }
        if ($paginationDetected) { $incompleteReasons.Add('pagination_detected') }
        if ($detailFailures.Count -gt 0) { $incompleteReasons.Add('detail_fetch_failed') }
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass 'TECHNICAL_LIMITATION' `
            -RetryRecommendation 'RETRY_NEXT_RUN' `
            -RawJobs @($jobs.ToArray()) `
            -HttpStatus $sourceFetch.status_code `
            -ArtifactPaths @(@($messages.ToArray()) + @($incompleteReasons.ToArray())) `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    New-JobAgentAdapterResult `
        -AdapterInput $AdapterInput `
        -AdapterName 'live-html-adapter' `
        -Status 'SUCCESS' `
        -ErrorClass 'NONE' `
        -RetryRecommendation 'NONE' `
        -RawJobs @($jobs.ToArray()) `
        -HttpStatus $sourceFetch.status_code `
        -ArtifactPaths @($messages.ToArray()) `
        -IsComplete $true `
        -StartedAt $startedAt `
        -FinishedAt ([datetime]::UtcNow)
}

function New-JobAgentLivePilotSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DailyRunResult,
        [Parameter(Mandatory)][object]$Policy,
        [Parameter(Mandatory)][datetime]$StartedAt
    )

    $attempts = @($DailyRunResult.document.scan_attempts | Where-Object { [string]$_.scan_run_id -eq [string]$DailyRunResult.scan_run_id })
    $jobs = @($DailyRunResult.document.jobs | Where-Object { [string]$_.last_seen -ge (ConvertTo-JobAgentLiveIso -Value $StartedAt) })
    $verifiedMatchingJobs = @($jobs | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.official_url) -and
            (@('MATCH', 'POSSIBLE') -contains [string]$_.classification.result)
        })
    [pscustomobject]@{
        schema_version = 'jobagent-live-pilot/v1'
        generated_at = ConvertTo-JobAgentLiveIso -Value ([datetime]::UtcNow)
        scan_run_id = [string]$DailyRunResult.scan_run_id
        status = [string]$DailyRunResult.status
        policy = $Policy
        companies = @($attempts | ForEach-Object { [string]$_.company_id } | Select-Object -Unique)
        attempts = @($attempts | Sort-Object company_id, source_id)
        official_detail_pages_checked = @($jobs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.official_url) } | Sort-Object company_id, title)
        verified_matching_jobs = @($verifiedMatchingJobs | Sort-Object company_id, title)
        report_path = [string]$DailyRunResult.report_path
        markdown_report_path = [string]$DailyRunResult.markdown_report_path
        html_report_path = [string]$DailyRunResult.html_report_path
        note = 'Live-Pilot ist eine separate Lane. verified_matching_jobs enthaelt nur offizielle Detailseiten mit MATCH/POSSIBLE-Klassifikation; verworfene oder unpassende offizielle Detailseiten bleiben separat unter official_detail_pages_checked.'
    }
}

Export-ModuleMember -Function @(
    'ConvertFrom-JobAgentLiveCareerPage',
    'Invoke-JobAgentLiveFetchWithRetry',
    'Invoke-JobAgentLiveHtmlAdapter',
    'New-JobAgentLivePilotSummary',
    'New-JobAgentLiveScanPolicy',
    'Test-JobAgentLiveCandidateText'
)
