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
    $matches = [regex]::Matches($Html, '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $candidates = New-Object System.Collections.Generic.List[object]
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
        if (-not (Test-JobAgentLiveCandidateText -Text ($text + ' ' + $evaluation.canonical_url) -SearchTerms $SearchTerms)) {
            continue
        }
        if ($seen.Add([string]$evaluation.canonical_url)) {
            $candidates.Add([pscustomobject]@{
                title = if ([string]::IsNullOrWhiteSpace($text)) { 'UNKNOWN' } else { $text }
                detail_url = [string]$evaluation.canonical_url
                verification_basis = [string]$evaluation.verification_basis
            })
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

function New-JobAgentLiveRawJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$DetailFetch
    )

    $summary = ConvertTo-JobAgentLivePlainText -Html ([string]$DetailFetch.content) -MaxLength 500
    $idMatch = [regex]::Match([string]$Candidate.detail_url, '(?i)(?:jobid|job_id|job|req|requisition|posting)[=/_-]?(?<id>[A-Za-z0-9._-]{2,})')
    $externalId = if ($idMatch.Success) { $idMatch.Groups['id'].Value } else { $null }
    $job = New-JobAgentRawJob `
        -Title ([string]$Candidate.title) `
        -DetailUrl ([string]$Candidate.detail_url) `
        -ExternalJobId $externalId `
        -AtsJobId 'UNKNOWN' `
        -LocationLabel 'UNKNOWN' `
        -Summary $summary `
        -ExtractionConfidence 60
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
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass 'NO_JOBS_FOUND' `
            -RetryRecommendation 'RETRY_NEXT_RUN' `
            -RawJobs @() `
            -HttpStatus $sourceFetch.status_code `
            -ArtifactPaths @('no_verified_job_candidates') `
            -StartedAt $startedAt `
            -FinishedAt ([datetime]::UtcNow)
    }

    $jobs = New-Object System.Collections.Generic.List[object]
    $messages = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($candidates | Select-Object -First ([int]$Policy.max_detail_fetches_per_source))) {
        $detailFetch = Invoke-JobAgentLiveFetchWithRetry -Url ([string]$candidate.detail_url) -Policy $Policy -Fetcher $Fetcher
        if ($detailFetch.ok -eq $true) {
            $jobs.Add((New-JobAgentLiveRawJob -Candidate $candidate -DetailFetch $detailFetch))
        }
        else {
            $messages.Add("detail_fetch_failed: $($candidate.detail_url): $($detailFetch.error)")
        }
    }

    if ($jobs.Count -eq 0) {
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'live-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass 'UNCLEAR_SOURCE' `
            -RetryRecommendation 'MANUAL_REVIEW' `
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
