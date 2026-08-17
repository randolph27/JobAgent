#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.LiveScan.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-TestCompany {
    $company = New-JobAgentCompanySeed `
        -CanonicalName 'Example AG' `
        -OfficialWebsiteUrl 'https://example.invalid/' `
        -CareerUrl 'https://example.invalid/careers' `
        -Aliases @('Example') `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'UNKNOWN' `
        -ScanPriority 90 `
        -DiscoverySourceUrl 'https://example.invalid/careers' `
        -CreatedAt ([datetime]'2026-08-17T09:00:00Z') `
        -NextScanAt ([datetime]'2026-08-17T09:00:00Z')
    $company.ats = @(
        [pscustomobject]@{
            system = 'Workday'
            official_domain = 'myworkdayjobs.invalid'
            verified_by_url = 'https://example.invalid/careers'
        }
    )
    return $company
}

function New-TestSource {
    [pscustomobject]@{
        source_id = 'source:example_ag_career'
        company_id = 'company:example_ag'
        source_type = 'CAREER_PAGE'
        url = 'https://example.invalid/careers'
        canonical_url = 'https://example.invalid/careers'
        is_official = $true
        verified_at = '2026-08-17T09:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @(
            [pscustomobject]@{
                status = 'VERIFIED'
                evidence_type = 'CAREER_URL'
                url = 'https://example.invalid/careers'
                basis_url = 'https://example.invalid/'
                redirect_chain = @()
                observed_at = '2026-08-17T09:00:00.000Z'
                reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.'
            }
        )
    }
}

function New-FetchResult {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][bool]$Ok,
        [Parameter()][int]$StatusCode = 200,
        [Parameter()][string]$Content = '',
        [Parameter()][string]$ErrorMessage = $null
    )

    [pscustomobject]@{
        ok = $Ok
        url = $Url
        final_url = $Url
        status_code = $StatusCode
        content = $Content
        content_type = 'text/html'
        started_at = '2026-08-17T10:00:00.000Z'
        finished_at = '2026-08-17T10:00:01.000Z'
        error = $ErrorMessage
    }
}

$policy = New-JobAgentLiveScanPolicy -TimeoutSeconds 7 -MaxRetries 1 -MaxResultsPerSource 3 -MaxDetailFetchesPerSource 2 -SearchTerms @('Head of IT')
Assert-True -Condition ($policy.timeout_seconds -eq 7) -Message 'Policy uebernimmt Timeout nicht.'
Assert-True -Condition ($policy.max_retries -eq 1) -Message 'Policy uebernimmt Retry-Grenze nicht.'
Assert-True -Condition ($policy.source_policy -eq 'official-career-source-only') -Message 'Policy dokumentiert offizielle Quellen nicht.'

$company = New-TestCompany
$source = New-TestSource
$context = New-JobAgentScanContext -ScanRunId 'scanrun:20260817T100000Z' -TimeoutSeconds 7 -MaxResults 3
$input = New-JobAgentAdapterInput -Company $company -JobSource $source -ScanContext $context

$html = @'
<html>
  <body>
    <a href="/careers/head-of-it-123">Head of IT</a>
    <a href="https://www.linkedin.com/jobs/view/123">Head of IT Aggregator</a>
    <a href="/about">About us</a>
  </body>
</html>
'@
$candidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $html -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @('Head of IT'))
Assert-True -Condition ($candidates.Count -eq 1) -Message 'Live-Parser filtert offizielle Kandidaten nicht korrekt.'
Assert-True -Condition ($candidates[0].detail_url -eq 'https://example.invalid/careers/head-of-it-123') -Message 'Live-Parser kanonisiert Detail-URL nicht.'

$jsonLdHtml = @'
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@graph": [
          {
            "@type": "JobPosting",
            "title": "Director IT",
            "url": "https://example.myworkdayjobs.invalid/job/director-it-987?source=linkedin",
            "identifier": {
              "@type": "PropertyValue",
              "name": "reqId",
              "value": "WD-987"
            },
            "employmentType": "FULL_TIME",
            "description": "<p>Strategische IT-Leitung.</p>",
            "jobLocation": {
              "@type": "Place",
              "address": {
                "@type": "PostalAddress",
                "addressLocality": "Muenchen"
              }
            }
          }
        ]
      }
    </script>
  </head>
</html>
'@
$jsonLdCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $jsonLdHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @('Director IT'))
Assert-True -Condition ($jsonLdCandidates.Count -eq 1) -Message 'JSON-LD JobPosting wurde nicht extrahiert.'
Assert-True -Condition ($jsonLdCandidates[0].detail_url -eq 'https://example.myworkdayjobs.invalid/job/director-it-987') -Message 'JSON-LD ATS-URL wurde nicht kanonisiert.'
Assert-True -Condition ($jsonLdCandidates[0].external_job_id -eq 'WD-987') -Message 'JSON-LD extrahiert keine externe Job-ID.'
Assert-True -Condition ($jsonLdCandidates[0].location_label -eq 'Muenchen') -Message 'JSON-LD extrahiert den Ort nicht.'

$atsAnchorHtml = '<html><body><a href="https://example.myworkdayjobs.invalid/en-US/search/job/Munich/987">Jetzt bewerben</a></body></html>'
$atsCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $atsAnchorHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @())
Assert-True -Condition ($atsCandidates.Count -eq 1) -Message 'ATS-URL-Muster ohne Titeltext wurde nicht erkannt.'
Assert-True -Condition ($atsCandidates[0].detail_url -eq 'https://example.myworkdayjobs.invalid/en-US/search/job/Munich/987') -Message 'ATS-URL-Muster liefert falsche Detail-URL.'

$fetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $html
            break
        }
        'https://example.invalid/careers/head-of-it-123' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT</h1><p>IT-Gesamtverantwortung in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}

$result = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $fetcher
Assert-True -Condition ($result.status -eq 'SUCCESS') -Message 'Live-Adapter meldet fuer abrufbare offizielle Detailseite keinen Erfolg.'
Assert-True -Condition (@($result.raw_jobs).Count -eq 1) -Message 'Live-Adapter liefert falsche RawJob-Anzahl.'
Assert-True -Condition ($result.raw_jobs[0].live_verification.detail_http_status -eq 200) -Message 'Live-Adapter protokolliert Detail-Verifikation nicht.'
Assert-True -Condition ($result.raw_jobs[0].summary -match 'IT-Gesamtverantwortung') -Message 'Live-Adapter uebernimmt Detailseitenzusammenfassung nicht.'

$emptyFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/about">About us</a></html>'
}
$emptyResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $emptyFetcher
Assert-True -Condition ($emptyResult.status -eq 'PARTIAL') -Message 'Live-Adapter markiert leere offizielle Quelle nicht als PARTIAL.'
Assert-True -Condition ($emptyResult.error_class -eq 'NO_JOBS_FOUND') -Message 'Live-Adapter setzt falsche Fehlerklasse fuer leere Quelle.'

$jsonLdFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $jsonLdHtml
            break
        }
        'https://example.myworkdayjobs.invalid/job/director-it-987' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Director IT</h1><p>Strategische IT-Leitung in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$jsonLdResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $jsonLdFetcher
Assert-True -Condition ($jsonLdResult.status -eq 'SUCCESS') -Message 'Live-Adapter verarbeitet JSON-LD JobPosting nicht erfolgreich.'
Assert-True -Condition ($jsonLdResult.raw_jobs[0].ats_job_id -eq 'WD-987') -Message 'Live-Adapter uebernimmt ATS-/Job-ID aus JSON-LD nicht.'
Assert-True -Condition ($jsonLdResult.raw_jobs[0].location_label -eq 'Muenchen') -Message 'Live-Adapter uebernimmt JSON-LD-Ort nicht.'
Assert-True -Condition ($jsonLdResult.raw_jobs[0].employment_type -eq 'FULL_TIME') -Message 'Live-Adapter uebernimmt employmentType aus JSON-LD nicht.'

$retryCounter = 0
$retryFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    $script:retryCounter++
    if ($Attempt -eq 1) {
        New-FetchResult -Url $Url -Ok $false -StatusCode 503 -ErrorMessage 'temporary'
    }
    else {
        New-FetchResult -Url $Url -Ok $true -Content '<html></html>'
    }
}
$retry = Invoke-JobAgentLiveFetchWithRetry -Url 'https://example.invalid/careers' -Policy $policy -Fetcher $retryFetcher
Assert-True -Condition ($retry.ok -eq $true) -Message 'Live-Fetch-Retry nutzt zweiten Versuch nicht.'
Assert-True -Condition (@($retry.attempts).Count -eq 2) -Message 'Live-Fetch-Retry protokolliert Versuche nicht vollstaendig.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'policy_limits',
        'official_candidate_filter',
        'aggregator_rejection',
        'jsonld_jobposting_extraction',
        'ats_url_pattern_detection',
        'live_adapter_success_with_detail_verification',
        'live_adapter_no_jobs_found',
        'live_adapter_jsonld_ats_success',
        'retry_attempt_log'
    )
} | ConvertTo-Json -Depth 5
