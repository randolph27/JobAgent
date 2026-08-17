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
        [Parameter()][ValidateRange(1, 25)][int]$MaxCompanies = 3,
        [Parameter()][ValidateRange(1, 100)][int]$MaxResultsPerSource = 10,
        [Parameter()][ValidateRange(1, 100)][int]$MaxDetailFetchesPerSource = 5,
        [Parameter()][string]$UserAgent = 'JobAgent/0.1 (+local-pilot; official-career-source-only)',
        [Parameter()][string[]]$SearchTerms = @('Head of IT', 'Director IT', 'IT Leitung', 'IT-Leitung', 'Leiter IT', 'CIO')
    )

    [pscustomobject]@{
        timeout_seconds = $TimeoutSeconds
        max_retries = $MaxRetries
        max_companies = $MaxCompanies
        max_results_per_source = $MaxResultsPerSource
        max_detail_fetches_per_source = $MaxDetailFetchesPerSource
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
            started_at = ConvertTo-JobAgentLiveIso -Value $started
            finished_at = ConvertTo-JobAgentLiveIso -Value ([datetime]::UtcNow)
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
            started_at = ConvertTo-JobAgentLiveIso -Value $started
            finished_at = ConvertTo-JobAgentLiveIso -Value ([datetime]::UtcNow)
            error = $_.Exception.Message
        }
    }
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

    return $Url -match '(?i)(/jobs?/|/job-details/|/vacanc(y|ies)/|/position/|/posting/|/requisition/|jobid=|job_id=|gh_jid=|gh_src=|lever\.co|workdayjobs|smartrecruiters|recruitee|join\.com|personio|softgarden|ashbyhq|successfactors|greenhouse\.io)'
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
    foreach ($propertyName in @('@graph', 'graph', 'itemListElement', 'jobs')) {
        if ($propertyNames -contains $propertyName) {
            foreach ($resolved in @(Get-JobAgentLiveJsonLdNodes -Node $Node.$propertyName)) {
                $nodes.Add($resolved)
            }
        }
    }
    if ($propertyNames -contains 'item') {
        foreach ($resolved in @(Get-JobAgentLiveJsonLdNodes -Node $Node.item)) {
            $nodes.Add($resolved)
        }
    }
    return $nodes.ToArray()
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
    $candidates = New-Object System.Collections.Generic.List[object]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($match in $scriptMatches) {
        if ($candidates.Count -ge $MaxResults) {
            break
        }

        $jsonText = [Net.WebUtility]::HtmlDecode($match.Groups['json'].Value).Trim()
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
            if ([string]::IsNullOrWhiteSpace($typeText) -or $typeText -notmatch '(?i)\bJobPosting\b') {
                continue
            }

            $detailUrlRaw = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('url'))
            if ([string]::IsNullOrWhiteSpace($detailUrlRaw)) {
                continue
            }

            $detailUrl = [Uri]::new([Uri]$BaseUrl, $detailUrlRaw).AbsoluteUri
            $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $detailUrl
            if ($evaluation.is_official -ne $true) {
                continue
            }

            $title = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('title'))
            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('name'))
            }
            if ([string]::IsNullOrWhiteSpace($title)) {
                continue
            }

            $externalJobId = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('identifier', 'value'))
            if ([string]::IsNullOrWhiteSpace($externalJobId)) {
                $externalJobId = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('identifier'))
            }
            $locationLabel = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('jobLocation', 'address', 'addressLocality'))
            if ([string]::IsNullOrWhiteSpace($locationLabel)) {
                $locationLabel = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('jobLocation', 'name'))
            }
            $employmentType = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('employmentType'))
            $summary = Get-JobAgentLiveTextValue -Value (Get-JobAgentLiveNestedValue -Object $node -Path @('description'))

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
                        -ExtractionConfidence 90))
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
        $absolute = [Uri]::new($baseUri, $href).AbsoluteUri
        $evaluation = Get-JobAgentOfficialSourceEvaluation -Company $Company -Url $absolute
        if ($evaluation.is_official -ne $true) {
            continue
        }
        $text = ConvertTo-JobAgentLivePlainText -Html $match.Groups['text'].Value -MaxLength 160
        if (-not (Test-JobAgentLiveCandidateText -Text ($text + ' ' + $evaluation.canonical_url) -SearchTerms $SearchTerms) -and -not (Test-JobAgentLiveDetailUrlPattern -Url ([string]$evaluation.canonical_url))) {
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

    $summary = ConvertTo-JobAgentLivePlainText -Html ([string]$DetailFetch.content) -MaxLength 500
    if ([string]::IsNullOrWhiteSpace($summary) -and $Candidate.PSObject.Properties.Name -contains 'summary') {
        $summary = [string]$Candidate.summary
    }
    $idMatch = [regex]::Match([string]$Candidate.detail_url, '(?i)(?:jobid|job_id|job|req|requisition|posting)[=/_-]?(?<id>[A-Za-z0-9._-]{2,})')
    $externalId = if (($Candidate.PSObject.Properties.Name -contains 'external_job_id') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.external_job_id)) { [string]$Candidate.external_job_id } elseif ($idMatch.Success) { $idMatch.Groups['id'].Value } else { $null }
    $atsJobId = if (($Candidate.PSObject.Properties.Name -contains 'ats_job_id') -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.ats_job_id)) { [string]$Candidate.ats_job_id } else { $externalId }
    $job = New-JobAgentRawJob `
        -Title ([string]$Candidate.title) `
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

function Invoke-JobAgentLiveHtmlAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter()][object]$Policy = (New-JobAgentLiveScanPolicy),
        [Parameter()][scriptblock]$Fetcher
    )

    $startedAt = [datetime]::UtcNow
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
            -ArtifactPaths @("source_fetch_failed: $($sourceFetch.error)") `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    $candidates = @(ConvertFrom-JobAgentLiveCareerPage `
            -Html ([string]$sourceFetch.content) `
            -BaseUrl ([string]$sourceFetch.final_url) `
            -Company $AdapterInput.company `
            -MaxResults ([int]$Policy.max_results_per_source) `
            -SearchTerms @($Policy.search_terms))
    if ($candidates.Count -eq 0) {
        $blockedByContent = Test-JobAgentLiveBlockedContentHint -Html ([string]$sourceFetch.content)
        $dynamicOnly = if (-not $blockedByContent) { Test-JobAgentLiveDynamicContentHint -Html ([string]$sourceFetch.content) } else { $false }
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
    foreach ($candidate in @($candidates | Select-Object -First ([int]$Policy.max_detail_fetches_per_source))) {
        $detailFetch = Invoke-JobAgentLiveFetchWithRetry -Url ([string]$candidate.detail_url) -Policy $Policy -Fetcher $Fetcher
        if ($detailFetch.ok -eq $true) {
            $jobs.Add((New-JobAgentLiveRawJob -Candidate $candidate -DetailFetch $detailFetch))
        }
        else {
            $detailFailures.Add($detailFetch)
            $failureClass = ConvertTo-JobAgentLiveErrorClass -FetchResult $detailFetch
            $messages.Add("detail_fetch_failed[$failureClass]: $($candidate.detail_url): $($detailFetch.error)")
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

    New-JobAgentAdapterResult `
        -AdapterInput $AdapterInput `
        -AdapterName 'live-html-adapter' `
        -Status 'SUCCESS' `
        -ErrorClass 'NONE' `
        -RetryRecommendation 'NONE' `
        -RawJobs @($jobs.ToArray()) `
        -HttpStatus $sourceFetch.status_code `
        -ArtifactPaths @($messages.ToArray()) `
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
