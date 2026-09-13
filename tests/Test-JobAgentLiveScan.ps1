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
        },
        [pscustomobject]@{
            system = 'Greenhouse'
            official_domain = 'boards.greenhouse.io'
            verified_by_url = 'https://example.invalid/careers'
        },
        [pscustomobject]@{
            system = 'Lever'
            official_domain = 'jobs.lever.co'
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
        [Parameter()][string]$ErrorMessage = $null,
        [Parameter()][string]$ErrorClass = $null,
        [Parameter()][string]$FetchClient = $null
    )

    $result = [pscustomobject]@{
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
    if (-not [string]::IsNullOrWhiteSpace($ErrorClass)) {
        $result | Add-Member -NotePropertyName error_class -NotePropertyValue $ErrorClass -Force
        $result | Add-Member -NotePropertyName error_detail -NotePropertyValue $ErrorMessage -Force
    }
    if (-not [string]::IsNullOrWhiteSpace($FetchClient)) {
        $result | Add-Member -NotePropertyName fetch_client -NotePropertyValue $FetchClient -Force
    }
    return $result
}

$policy = New-JobAgentLiveScanPolicy -TimeoutSeconds 7 -MaxRetries 1 -MaxResultsPerSource 3 -MaxDetailFetchesPerSource 2 -HostConcurrency 2 -FetchClient 'curl' -WslDistribution 'FixtureDistro' -SearchTerms @('Head of IT')
Assert-True -Condition ($policy.timeout_seconds -eq 7) -Message 'Policy uebernimmt Timeout nicht.'
Assert-True -Condition ($policy.max_retries -eq 1) -Message 'Policy uebernimmt Retry-Grenze nicht.'
Assert-True -Condition ($policy.host_concurrency -eq 2 -and $policy.fetch_client -eq 'curl' -and $policy.wsl_distribution -eq 'FixtureDistro') -Message 'Policy uebernimmt Fetch-Client-/Hostlimit-Vertrag nicht.'
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

$navigationHtml = @'
<html>
  <body>
    <a href="/careers">Career at Example</a>
    <a href="/careers/benefits">Benefits</a>
    <a href="/careers/students">Students</a>
    <a href="https://jobs.example.invalid/">Job Portal</a>
  </body>
</html>
'@
$navigationCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $navigationHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 10 -SearchTerms @('Head of IT'))
Assert-True -Condition ($navigationCandidates.Count -eq 0) -Message 'Live-Parser darf Karriere-Navigation und Jobportal-Links nicht als Stellen speichern.'

$malformedHrefHtml = '<html><body><a href="http://www.sec.gov.&nbsp">SEC</a><a href="/careers/head-of-it-123">Head of IT</a></body></html>'
$malformedHrefCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $malformedHrefHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 10 -SearchTerms @('Head of IT'))
Assert-True -Condition ($malformedHrefCandidates.Count -eq 1 -and $malformedHrefCandidates[0].detail_url -eq 'https://example.invalid/careers/head-of-it-123') -Message 'Live-Parser muss kaputte Fremd-Hrefs ignorieren und gueltige Treffer weiter auswerten.'

$storyHtml = '<html><body><a href="/en/newsroom/stories/how-product-strategy-works.html">How Product Strategy Works</a></body></html>'
$storyCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $storyHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 10 -SearchTerms @('Head of IT'))
Assert-True -Condition ($storyCandidates.Count -eq 0) -Message 'Live-Parser darf Newsroom-/Story-Seiten nicht als Stellen speichern.'

$contentPageHtml = '<html><body><a href="/content/content-functional-areas?locale=de_DE">Functional areas</a></body></html>'
$contentPageCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $contentPageHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 10 -SearchTerms @('Functional areas'))
Assert-True -Condition ($contentPageCandidates.Count -eq 0) -Message 'Live-Parser darf Content-/Funktionsbereichsseiten nicht als Stellen speichern.'

$searchCategoryHtml = '<html><body><a href="https://jobs.siemens-energy.example/en_US/jobs/SearchJobsRomania">Romania</a><a href="https://jobs.siemens-energy.example/en_US/jobs/HotJobs">View more</a><a href="https://jobs.siemens-energy.example/en_US/jobs/StayConnected">Sign up for email updates</a><a href="https://jobs.siemens-energy.example/en_US/jobs/ResetPassword">Forgot your password?</a><a href="https://jobs.siemens-energy.example/en_US/jobs/ResumeUpload">Get job recommendations</a><a href="https://siemens-energy.example/us/en/company/jobs/labor-condition-applications.html">Labor Condition Application</a></body></html>'
$searchCategoryCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $searchCategoryHtml -BaseUrl 'https://jobs.siemens-energy.example/en_US/jobs' -Company $company -MaxResults 10 -SearchTerms @())
Assert-True -Condition ($searchCategoryCandidates.Count -eq 0) -Message 'Live-Parser darf ATS-Kategorie-/Registrierungsseiten nicht als Stellen speichern.'

$avatureListingHtml = '<html><body><a href="https://example.invalid/ja_JP/jobs/Jobs/CIO?folderRecordsPerPage=20">日本語</a><a href="https://example.invalid/en_US/jobs/SearchJobsGermany">Germany</a><a href="https://example.invalid/en_US/jobs/FolderDetail/IT-Product-Manager-SCM-Logistics/301949">IT Product Manager SCM &amp; Logistics</a></body></html>'
$avatureListingCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $avatureListingHtml -BaseUrl 'https://example.invalid/en_US/jobs/Jobs/CIO?folderRecordsPerPage=20' -Company $company -MaxResults 10 -SearchTerms @('CIO'))
Assert-True -Condition ($avatureListingCandidates.Count -eq 1) -Message 'Avature-Listing-/Sprachlinks duerfen nicht als Stellen gelten, FolderDetail-Treffer muessen erhalten bleiben.'
Assert-True -Condition ($avatureListingCandidates[0].detail_url -eq 'https://example.invalid/en_US/jobs/FolderDetail/IT-Product-Manager-SCM-Logistics/301949') -Message 'Avature-FolderDetail-Treffer wird falsch gefiltert.'

$applicationHtml = '<html><body><a href="https://example.invalid/Vacancies/1345/Description/1">Broadcast Engineer</a><a href="https://example.invalid/Vacancies/1345/Application/CheckLogin/1">Jetzt bewerben</a></body></html>'
$applicationCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $applicationHtml -BaseUrl 'https://example.invalid/Vacancies' -Company $company -MaxResults 10 -SearchTerms @())
Assert-True -Condition ($applicationCandidates.Count -eq 1 -and $applicationCandidates[0].detail_url -eq 'https://example.invalid/Vacancies/1345/Description/1') -Message 'Live-Parser muss Bewerbungs-/CheckLogin-Seiten ausschliessen, aber Detailseiten behalten.'

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

$greenhouseHtml = '<html><body><a href="https://boards.greenhouse.io/example/jobs/4242">Bewerben</a></body></html>'
$greenhouseCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $greenhouseHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @())
Assert-True -Condition ($greenhouseCandidates.Count -eq 1) -Message 'Greenhouse-ATS-URL wurde nicht als offizieller Kandidat erkannt.'
Assert-True -Condition ($greenhouseCandidates[0].detail_url -eq 'https://boards.greenhouse.io/example/jobs/4242') -Message 'Greenhouse-ATS-URL wurde nicht korrekt kanonisiert.'

$encodedPathHtml = '<html><body><a href="https://jobs.example.invalid/job/M%C3%BCnchen-Head-of-IT-%28mwd%29-4242/">Head of IT</a></body></html>'
$encodedPathCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $encodedPathHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @('Head of IT'))
Assert-True -Condition ($encodedPathCandidates.Count -eq 1) -Message 'Bereits percent-encodete UTF-8-Detailpfade wurden nicht akzeptiert.'
Assert-True -Condition ($encodedPathCandidates[0].detail_url -match 'M%C3%BCnchen-Head-of-IT') -Message 'UTF-8-Detailpfad wurde falsch kanonisiert.'

$encodedSpaceHtml = '<html><body><a href="https://example.invalid/job/Ulm-Senior-Strategischer-Eink%C3%A4ufer-Externalisierung-Baugruppen-%28E%20E%29-%28wmd%29-89077/1364637855">Senior Strategischer Einkäufer</a></body></html>'
$encodedSpaceCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $encodedSpaceHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @())
Assert-True -Condition ($encodedSpaceCandidates.Count -eq 0) -Message 'Nicht passende percent-encodete Detailpfade duerfen nicht als Zielrollen-Kandidat durchrutschen.'

$structuredNavigationHtml = @'
<html>
  <head>
    <script type="application/json">
      {"items":[{"title":"Overview","url":"https://example.invalid/careers"},{"title":"Jobs","url":"https://example.invalid/careers/jobs"}]}
    </script>
  </head>
</html>
'@
$structuredNavigationCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $structuredNavigationHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @('Head of IT'))
Assert-True -Condition ($structuredNavigationCandidates.Count -eq 0) -Message 'Strukturierte Karriere-Navigation darf nicht als JobPosting gespeichert werden.'

$structuredJsonHtml = @'
<html>
  <head>
    <script type="application/json">
      {
        "postings": [
          {
            "id": "lever-123",
            "text": "Head of IT",
            "hostedUrl": "https://jobs.lever.co/example/lever-123?utm_source=test",
            "categories": {
              "location": "Muenchen",
              "commitment": "FULL_TIME"
            },
            "descriptionPlain": "Fuehrt die zentrale IT-Organisation."
          }
        ]
      }
    </script>
  </head>
</html>
'@
$structuredJsonCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $structuredJsonHtml -BaseUrl 'https://example.invalid/careers' -Company $company -MaxResults 5 -SearchTerms @('Head of IT'))
Assert-True -Condition ($structuredJsonCandidates.Count -eq 1) -Message 'Strukturierte ATS-JSON-Liste wurde nicht extrahiert.'
Assert-True -Condition ($structuredJsonCandidates[0].detail_url -eq 'https://jobs.lever.co/example/lever-123') -Message 'Strukturierte ATS-JSON-Liste wurde nicht kanonisiert.'
Assert-True -Condition ($structuredJsonCandidates[0].external_job_id -eq 'lever-123') -Message 'Strukturierte ATS-JSON-Liste extrahiert keine Job-ID.'
Assert-True -Condition ($structuredJsonCandidates[0].employment_type -eq 'FULL_TIME') -Message 'Strukturierte ATS-JSON-Liste extrahiert employmentType nicht.'

$rssFeed = @'
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[IT Manager Platform Operations (Muenchen, DE)]]></title>
      <link>https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321/?utm_source=J2WRSS</link>
      <description><![CDATA[<p>Verantwortet IT-Strategie und Plattformbetrieb.</p>]]></description>
    </item>
  </channel>
</rss>
'@
$rssCandidates = @(ConvertFrom-JobAgentLiveCareerPage -Html $rssFeed -BaseUrl 'https://jobs.example.invalid/services/rss/category/?catid=42' -Company $company -MaxResults 5 -SearchTerms @())
Assert-True -Condition ($rssCandidates.Count -eq 1) -Message 'RSS-Feed-Kandidaten wurden nicht extrahiert.'
Assert-True -Condition ($rssCandidates[0].detail_url -eq 'https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321') -Message 'RSS-Feed-Detail-URL wurde nicht kanonisiert.'
Assert-True -Condition ($rssCandidates[0].external_job_id -eq '987654321') -Message 'RSS-Feed-Job-ID wurde nicht aus der Detail-URL gelesen.'

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
Assert-True -Condition ($result.scan_complete -eq $true -and $result.scan_attempt.scan_complete -eq $true) -Message 'Vollstaendiger Live-Adapterlauf markiert den Scan nicht vollstaendig.'
Assert-True -Condition (@($result.raw_jobs).Count -eq 1) -Message 'Live-Adapter liefert falsche RawJob-Anzahl.'
Assert-True -Condition ($result.raw_jobs[0].live_verification.detail_http_status -eq 200) -Message 'Live-Adapter protokolliert Detail-Verifikation nicht.'
Assert-True -Condition ($result.raw_jobs[0].summary -match 'IT-Gesamtverantwortung') -Message 'Live-Adapter uebernimmt Detailseitenzusammenfassung nicht.'

$genericTitleHtml = '<html><body><a href="/position/head-of-it-555">Learn More</a></body></html>'
$genericTitleFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $genericTitleHtml
            break
        }
        'https://example.invalid/position/head-of-it-555' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT Platform Operations</h1><p>IT-Gesamtverantwortung in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$genericTitleResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $genericTitleFetcher
Assert-True -Condition ($genericTitleResult.status -eq 'SUCCESS') -Message 'Live-Adapter verarbeitet generischen Linktext mit Detailtitel nicht erfolgreich.'
Assert-True -Condition ($genericTitleResult.raw_jobs[0].title -eq 'Head of IT Platform Operations') -Message 'Live-Adapter ersetzt generischen Linktext nicht durch Detailseitentitel.'

$emptyFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/about">About us</a></html>'
}
$emptyResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $emptyFetcher
Assert-True -Condition ($emptyResult.status -eq 'SUCCESS') -Message 'Live-Adapter markiert vollstaendig verarbeitete leere Quelle nicht als SUCCESS.'
Assert-True -Condition ($emptyResult.scan_complete -eq $true) -Message 'Live-Adapter markiert vollstaendig verarbeitete leere Quelle nicht als complete.'
Assert-True -Condition ($emptyResult.error_class -eq 'NONE') -Message 'Live-Adapter setzt falsche Fehlerklasse fuer vollstaendig leere Quelle.'

$unprocessedEmptyPaginationPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 10 -MaxDetailFetchesPerSource 10 -MaxPagesPerSource 1
$unprocessedEmptyPaginationFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $true -Content '<html><body><a rel="next" href="/careers?page=2">Weiter</a></body></html>'
}
$unprocessedEmptyPaginationResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $unprocessedEmptyPaginationPolicy -Fetcher $unprocessedEmptyPaginationFetcher
Assert-True -Condition ($unprocessedEmptyPaginationResult.status -eq 'PARTIAL') -Message 'Live-Adapter muss leere Quellen mit unerreichter Pagination als PARTIAL markieren.'
Assert-True -Condition ($unprocessedEmptyPaginationResult.error_class -eq 'NO_JOBS_FOUND') -Message 'Live-Adapter klassifiziert leere Quellen mit unerreichter Pagination falsch.'

$blockedFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $true -Content '<html><body><h1>Access denied</h1><p>Please verify you are human to continue.</p></body></html>'
}
$blockedResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $blockedFetcher
Assert-True -Condition ($blockedResult.status -eq 'PARTIAL') -Message 'Live-Adapter markiert blockierte Quellseite nicht als PARTIAL.'
Assert-True -Condition ($blockedResult.error_class -eq 'BLOCKED') -Message 'Live-Adapter setzt fuer blockierte Quellseite nicht BLOCKED.'
Assert-True -Condition ($blockedResult.retry_recommendation -eq 'MANUAL_REVIEW') -Message 'Live-Adapter setzt fuer blockierte Quellseite keine manuelle Pruefung.'

$dynamicFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $true -Content '<html><body><div id="root"></div><script id="__NEXT_DATA__" type="application/json">{}</script><noscript>Enable JavaScript</noscript></body></html>'
}
$dynamicResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $dynamicFetcher
Assert-True -Condition ($dynamicResult.status -eq 'PARTIAL') -Message 'Live-Adapter markiert clientseitige Quellseite nicht als PARTIAL.'
Assert-True -Condition ($dynamicResult.error_class -eq 'TECHNICAL_LIMITATION') -Message 'Live-Adapter setzt fuer clientseitige Quellseite nicht TECHNICAL_LIMITATION.'
Assert-True -Condition ($dynamicResult.retry_recommendation -eq 'MANUAL_REVIEW') -Message 'Live-Adapter setzt fuer clientseitige Quellseite keine manuelle Pruefung.'

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

$paginationPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 3 -SearchTerms @('IT Manager')
$paginationFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/about">About</a><a rel="next" href="/careers?page=2">Weiter</a></html>'
            break
        }
        'https://example.invalid/careers?page=2' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/careers/jobs/it-manager-200">IT Manager</a></html>'
            break
        }
        'https://example.invalid/careers/jobs/it-manager-200' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager</h1><p>Personalverantwortung und IT-Strategie in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$paginationResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $paginationPolicy -Fetcher $paginationFetcher
Assert-True -Condition ($paginationResult.status -eq 'SUCCESS' -and $paginationResult.scan_complete) -Message 'Live-Adapter verarbeitet belegte Pagination nicht vollstaendig.'
Assert-True -Condition (@($paginationResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert Treffer auf Folgeseite nicht.'
Assert-True -Condition ($paginationResult.raw_jobs[0].detail_url -eq 'https://example.invalid/careers/jobs/it-manager-200') -Message 'Live-Adapter kanonisiert Treffer von Folgeseite falsch.'

$unprocessedJobPaginationPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 1 -SearchTerms @('IT Manager')
$unprocessedJobPaginationFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/careers/jobs/it-manager-201">IT Manager</a><a rel="next" href="/careers?page=2">Weiter</a></html>'
            break
        }
        'https://example.invalid/careers/jobs/it-manager-201' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager</h1><p>Personalverantwortung und IT-Strategie in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$unprocessedJobPaginationResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $unprocessedJobPaginationPolicy -Fetcher $unprocessedJobPaginationFetcher
Assert-True -Condition ($unprocessedJobPaginationResult.status -eq 'PARTIAL' -and -not $unprocessedJobPaginationResult.scan_complete) -Message 'Live-Adapter darf Jobs mit unerreichter Pagination nicht als vollstaendig markieren.'
Assert-True -Condition ((@($unprocessedJobPaginationResult.artifact_paths) -join "`n") -match 'pagination_detected') -Message 'Live-Adapter dokumentiert unerreichte Pagination nicht.'

$iframePolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 3 -SearchTerms @('IT Lead')
$iframeFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><iframe src="https://example.myworkdayjobs.invalid/embed/jobs"></iframe></html>'
            break
        }
        'https://example.myworkdayjobs.invalid/embed/jobs' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/job/it-lead-333">IT Lead</a></html>'
            break
        }
        'https://example.myworkdayjobs.invalid/job/it-lead-333' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Lead</h1><p>Leitet Team und verantwortet die IT-Roadmap in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$iframeResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $iframePolicy -Fetcher $iframeFetcher
Assert-True -Condition ($iframeResult.status -eq 'SUCCESS' -and $iframeResult.scan_complete) -Message 'Live-Adapter verarbeitet offiziell verlinkten ATS-Frame nicht vollstaendig.'
Assert-True -Condition (@($iframeResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert Treffer aus ATS-Frame nicht.'
Assert-True -Condition ($iframeResult.raw_jobs[0].detail_url -eq 'https://example.myworkdayjobs.invalid/job/it-lead-333') -Message 'Live-Adapter kanonisiert ATS-Frame-Treffer falsch.'

$linkedSourcePolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 3 -SearchTerms @('Head of IT')
$linkedSourceFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/careers/benefits">Benefits</a><a href="https://jobs.example.invalid/">Job Portal</a></html>'
            break
        }
        'https://jobs.example.invalid/' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/job/head-it-444">Head of IT</a></html>'
            break
        }
        'https://jobs.example.invalid/job/head-it-444' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT</h1><p>Gesamtverantwortung und IT-Strategie in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$linkedSourceResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $linkedSourcePolicy -Fetcher $linkedSourceFetcher
Assert-True -Condition ($linkedSourceResult.status -eq 'SUCCESS' -and $linkedSourceResult.scan_complete) -Message 'Live-Adapter folgt offiziell verlinktem Jobportal nicht als Quellseite.'
Assert-True -Condition (@($linkedSourceResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert Treffer aus verlinktem Jobportal nicht.'
Assert-True -Condition ($linkedSourceResult.raw_jobs[0].detail_url -eq 'https://jobs.example.invalid/job/head-it-444') -Message 'Live-Adapter kanonisiert Treffer aus verlinktem Jobportal falsch.'

$avaturePolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 4 -SearchTerms @('Head of IT')
$avatureCompany = [pscustomobject]@{
    company_id = 'company:example_avature'
    canonical_name = 'Example Avature AG'
    canonical_domain = 'example.invalid'
    official_website_url = 'https://example.invalid/'
    career_url = 'https://jobs.example.invalid/en_US/jobs'
    ats = @()
}
$avatureSource = [pscustomobject]@{
    source_id = 'source:example_avature_career'
    company_id = 'company:example_avature'
    source_type = 'CAREER_PAGE'
    url = 'https://jobs.example.invalid/en_US/jobs'
    canonical_url = 'https://jobs.example.invalid/en_US/jobs'
    is_official = $true
    verified_at = '2026-08-17T09:00:00.000Z'
    verification_basis = 'CAREER_URL'
    verification_evidence = @()
}
$avatureInput = New-JobAgentAdapterInput -Company $avatureCompany -JobSource $avatureSource -ScanContext $context
$avatureSourceHtml = '<html><head><meta name="avature.portal.id" content="140"/><meta name="avature.portal.page" content="Home"/></head><body><a href="https://jobs.example.invalid/en_US/jobs/Jobs">Search Jobs</a></body></html>'
$avatureSearchHtml = '<html><head><meta name="avature.portal.id" content="140"/><meta name="avature.portal.page" content="Jobs"/></head><body><article><h3><a href="https://jobs.example.invalid/en_US/jobs/FolderDetail?folderId=123456">Head of IT Infrastructure</a></h3><p>Munich, Bavaria, Germany</p></article><a class="paginationNextLink" href="https://jobs.example.invalid/en_US/jobs/Jobs/Head+of+IT?folderRecordsPerPage=20&amp;folderOffset=20">Next &gt;&gt;</a></body></html>'
$avatureSearchPage2Html = '<html><head><meta name="avature.portal.id" content="140"/><meta name="avature.portal.page" content="Jobs"/></head><body><p>No more relevant jobs.</p></body></html>'
$avatureFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://jobs.example.invalid/en_US/jobs' {
            New-FetchResult -Url $Url -Ok $true -Content $avatureSourceHtml
            break
        }
        'https://jobs.example.invalid/en_US/jobs/Jobs/Head+of+IT?folderRecordsPerPage=20' {
            New-FetchResult -Url $Url -Ok $true -Content $avatureSearchHtml
            break
        }
        'https://jobs.example.invalid/en_US/jobs/Jobs/Head+of+IT?folderOffset=20&folderRecordsPerPage=20' {
            New-FetchResult -Url $Url -Ok $true -Content $avatureSearchPage2Html
            break
        }
        'https://jobs.example.invalid/en_US/jobs/FolderDetail?folderId=123456' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT Infrastructure</h1><p>Leitet IT-Infrastruktur in Munich.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage ('not found: ' + $Url)
            break
        }
    }
}
$avatureResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $avatureInput -Policy $avaturePolicy -Fetcher $avatureFetcher
Assert-True -Condition ($avatureResult.status -eq 'SUCCESS' -and $avatureResult.scan_complete) -Message 'Live-Adapter verarbeitet Avature-Suchseiten und Pagination nicht vollstaendig.'
Assert-True -Condition (@($avatureResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert Avature-FolderDetail-Treffer nicht.'
Assert-True -Condition ($avatureResult.raw_jobs[0].detail_url -eq 'https://jobs.example.invalid/en_US/jobs/FolderDetail?folderId=123456') -Message 'Live-Adapter kanonisiert Avature-FolderDetail falsch.'

$rssFeedPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 3 -SearchTerms @('IT Manager')
$rssFeedFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><link rel="alternate" type="application/rss+xml" title="IT" href="https://jobs.example.invalid/services/rss/category/?catid=42" /></html>'
            break
        }
        'https://jobs.example.invalid/services/rss/category?catid=42' {
            New-FetchResult -Url $Url -Ok $true -Content $rssFeed
            break
        }
        'https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager Platform Operations</h1><p>IT-Strategie und Plattformbetrieb in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$rssFeedResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $rssFeedPolicy -Fetcher $rssFeedFetcher
Assert-True -Condition ($rssFeedResult.status -eq 'SUCCESS' -and $rssFeedResult.scan_complete) -Message 'Live-Adapter folgt offiziell verlinktem RSS-Feed nicht als Quellseite.'
Assert-True -Condition (@($rssFeedResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert Treffer aus verlinktem RSS-Feed nicht.'
Assert-True -Condition ($rssFeedResult.raw_jobs[0].detail_url -eq 'https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321') -Message 'Live-Adapter kanonisiert Treffer aus RSS-Feed falsch.'

$successFactorsPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 4 -SearchTerms @('Head of IT')
$successFactorsFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><script>j2w.init({"ssoCompanyId":"example"});</script></html>'
            break
        }
        'https://example.invalid/services/rss/job?keywords=(IT)&locale=en_US' {
            New-FetchResult -Url $Url -Ok $true -Content $rssFeed
            break
        }
        'https://example.invalid/services/rss/job?keywords=(Head%20of%20IT)&locale=en_US' {
            New-FetchResult -Url $Url -Ok $true -Content $rssFeed
            break
        }
        'https://example.invalid/search?createNewAlert=false&locationsearch=&q=' {
            New-FetchResult -Url $Url -Ok $true -Content '<html><a class="jobTitle-link" href="/job/Muenchen-Head-of-IT-80809/424242/">Head of IT</a></html>'
            break
        }
        'https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager Platform Operations</h1><p>IT-Strategie und Plattformbetrieb in Muenchen.</p></main>'
            break
        }
        'https://example.invalid/job/Muenchen-Head-of-IT-80809/424242' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT</h1><p>Gesamtverantwortung und IT-Strategie in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$successFactorsResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $successFactorsPolicy -Fetcher $successFactorsFetcher
Assert-True -Condition ($successFactorsResult.status -eq 'SUCCESS' -and $successFactorsResult.scan_complete) -Message 'Live-Adapter folgt SuccessFactors-Suchseiten nicht aus belegten j2w-Karriereseiten.'
Assert-True -Condition (@($successFactorsResult.raw_jobs).Count -eq 1) -Message 'Live-Adapter extrahiert SuccessFactors-RSS-Treffer nicht.'
Assert-True -Condition (@($successFactorsResult.raw_jobs | Where-Object { [string]$_.detail_url -eq 'https://jobs.example.invalid/job/Muenchen-IT-Manager-Platform-Operations/987654321' }).Count -eq 1) -Message 'Live-Adapter verarbeitet SuccessFactors-RSS-Follow-up nicht.'

$structuredJsonFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $structuredJsonHtml
            break
        }
        'https://jobs.lever.co/example/lever-123' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Head of IT</h1><p>Fuehrt die zentrale IT-Organisation in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$structuredJsonResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $structuredJsonFetcher
Assert-True -Condition ($structuredJsonResult.status -eq 'SUCCESS') -Message 'Live-Adapter verarbeitet strukturierte ATS-JSON-Liste nicht erfolgreich.'
Assert-True -Condition ($structuredJsonResult.raw_jobs[0].ats_job_id -eq 'lever-123') -Message 'Live-Adapter uebernimmt ATS-/Job-ID aus strukturierter JSON-Liste nicht.'
Assert-True -Condition ($structuredJsonResult.raw_jobs[0].employment_type -eq 'FULL_TIME') -Message 'Live-Adapter uebernimmt employmentType aus strukturierter JSON-Liste nicht.'
Assert-True -Condition ($structuredJsonResult.raw_jobs[0].location_label -eq 'Muenchen') -Message 'Live-Adapter uebernimmt Ort aus strukturierter JSON-Liste nicht.'

$gatsbyPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 10 -MaxDetailFetchesPerSource 10 -MaxPagesPerSource 10 -SearchTerms @('Head of IT')
$gatsbySourceHtml = '<html><script id="gatsby-script-loader">window.pagePath="/en/company/career";</script><script id="gatsby-static-query">{"staticQueryHashes":["111111111","2312721738"]}</script></html>'
$gatsbyStaticQueryJson = @'
{
  "data": {
    "allGreenhouseJob": {
      "edges": [
        {
          "node": {
            "id": "Greenhouse__Job__4762894101",
            "gh_Id": 4762894101,
            "title": "Director People Systems & Business Performance (m/w/d)",
            "departments": [{"name": "People Systems"}],
            "location": {"name": "Muenchen"}
          }
        },
        {
          "node": {
            "id": "Greenhouse__Job__4883791101",
            "gh_Id": 4883791101,
            "title": "Engineering Lead (m/f/d)",
            "departments": [{"name": "Innovation, Development & Services"}],
            "location": {"name": "Muenchen"}
          }
        }
      ]
    }
  }
}
'@
$gatsbyFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $gatsbySourceHtml
            break
        }
        'https://example.invalid/page-data/sq/d/111111111.json' {
            New-FetchResult -Url $Url -Ok $true -Content '{"data":{"irrelevant":true}}'
            break
        }
        'https://example.invalid/page-data/sq/d/2312721738.json' {
            New-FetchResult -Url $Url -Ok $true -Content $gatsbyStaticQueryJson
            break
        }
        'https://example.invalid/careers/jobs/4762894101-director-people-systems-business-performance-m-w-d?gh_jid=4762894101' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Director People Systems</h1><p>Leitet People Systems in Muenchen.</p></main>'
            break
        }
        'https://example.invalid/careers/jobs/4883791101-engineering-lead-m-f-d?gh_jid=4883791101' {
            New-FetchResult -Url $Url -Ok $true -Content '<main><h1>Engineering Lead</h1><p>Fuehrt Engineering in Muenchen.</p></main>'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$gatsbyResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $gatsbyPolicy -Fetcher $gatsbyFetcher
Assert-True -Condition ($gatsbyResult.status -eq 'SUCCESS' -and $gatsbyResult.scan_complete) -Message 'Live-Adapter verarbeitet Gatsby-StaticQuery-Greenhouse-Listen nicht vollstaendig.'
Assert-True -Condition (@($gatsbyResult.raw_jobs).Count -eq 2) -Message 'Live-Adapter extrahiert nicht alle Greenhouse-Jobs aus Gatsby-StaticQuery.'
Assert-True -Condition (@($gatsbyResult.raw_jobs | Where-Object { [string]$_.detail_url -match '/careers/jobs/[0-9]+-' }).Count -eq 2) -Message 'Live-Adapter baut Greenhouse-Detail-URLs aus Gatsby-Daten falsch.'
Assert-True -Condition (@($gatsbyResult.raw_jobs | Where-Object { [string]$_.location_label -eq 'Muenchen' }).Count -eq 2) -Message 'Live-Adapter uebernimmt Greenhouse-Orte aus Gatsby-Daten nicht.'

$blockedDetailFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $html
            break
        }
        'https://example.invalid/careers/head-of-it-123' {
            New-FetchResult -Url $Url -Ok $false -StatusCode 403 -ErrorMessage 'forbidden'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$blockedDetailResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $blockedDetailFetcher
Assert-True -Condition ($blockedDetailResult.status -eq 'PARTIAL') -Message 'Live-Adapter markiert blockierten Detailfetch nicht als PARTIAL.'
Assert-True -Condition ($blockedDetailResult.error_class -eq 'BLOCKED') -Message 'Live-Adapter setzt fuer blockierten Detailfetch nicht BLOCKED.'
Assert-True -Condition ($blockedDetailResult.retry_recommendation -eq 'MANUAL_REVIEW') -Message 'Live-Adapter setzt fuer blockierten Detailfetch keine manuelle Pruefung.'

$timeoutDetailFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    switch ($Url) {
        'https://example.invalid/careers' {
            New-FetchResult -Url $Url -Ok $true -Content $html
            break
        }
        'https://example.invalid/careers/head-of-it-123' {
            New-FetchResult -Url $Url -Ok $false -StatusCode 504 -ErrorMessage 'gateway timeout'
            break
        }
        default {
            New-FetchResult -Url $Url -Ok $false -StatusCode 404 -ErrorMessage 'not found'
            break
        }
    }
}
$timeoutDetailResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $timeoutDetailFetcher
Assert-True -Condition ($timeoutDetailResult.status -eq 'PARTIAL') -Message 'Live-Adapter markiert Timeout-Detailfetch nicht als PARTIAL.'
Assert-True -Condition ($timeoutDetailResult.error_class -eq 'TIMEOUT') -Message 'Live-Adapter setzt fuer Timeout-Detailfetch nicht TIMEOUT.'
Assert-True -Condition ($timeoutDetailResult.retry_recommendation -eq 'RETRY_NEXT_RUN') -Message 'Live-Adapter setzt fuer Timeout-Detailfetch nicht RETRY_NEXT_RUN.'

$tlsSourceFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    New-FetchResult -Url $Url -Ok $false -ErrorMessage 'SEC_E_NO_CREDENTIALS' -ErrorClass 'TLS_CREDENTIAL_UNAVAILABLE' -FetchClient 'curl.exe'
}
$tlsSourceResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $policy -Fetcher $tlsSourceFetcher
Assert-True -Condition ($tlsSourceResult.status -eq 'FAILED' -and $tlsSourceResult.error_class -eq 'NOT_REACHABLE') -Message 'Live-Adapter klassifiziert TLS-Quellfehler nicht fail-closed.'
Assert-True -Condition ((@($tlsSourceResult.artifact_paths) -join "`n") -match 'source_fetch_failed\[TLS_CREDENTIAL_UNAVAILABLE\]\[curl\.exe\]') -Message 'Live-Adapter verliert konkrete Fetch-Fehlerklasse oder Client im Artefakt.'

$collisionHtml = '<html><body><a href="https://example.myworkdayjobs.invalid/job/123">IT Manager 123</a><a href="https://example.myworkdayjobs.invalid/job/456">IT Manager 456</a></body></html>'
$collisionPolicy = New-JobAgentLiveScanPolicy -MaxRetries 0 -MaxResultsPerSource 5 -MaxDetailFetchesPerSource 5
$collisionFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    if ($Url -eq 'https://example.invalid/careers') {
        return New-FetchResult -Url $Url -Ok $true -Content $collisionHtml
    }
    return New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager</h1><p>IT-Fuehrung in Muenchen.</p></main>'
}
$collisionResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $collisionPolicy -Fetcher $collisionFetcher
Assert-True -Condition ($collisionResult.status -eq 'SUCCESS' -and $collisionResult.scan_complete) -Message 'Vollstaendige unterschiedliche Detailseiten werden nicht als erfolgreicher Scan erkannt.'
Assert-True -Condition ((@($collisionResult.raw_jobs | Select-Object -ExpandProperty external_job_id | Select-Object -Unique).Count -eq 2) -and (@($collisionResult.raw_jobs | Select-Object -ExpandProperty external_job_id) -notcontains 's.example.myworkdayjobs.invalid')) -Message 'Pfadbasierte Job-IDs unterscheiden verschiedene Jobs nicht sicher.'

$mixedHtml = '<html><body><a href="https://example.myworkdayjobs.invalid/job/111">IT Manager 111</a><a href="https://example.myworkdayjobs.invalid/job/222">IT Manager 222</a></body></html>'
$mixedFetcher = {
    param([string]$Url, [object]$Policy, [int]$Attempt)

    if ($Url -eq 'https://example.invalid/careers') {
        return New-FetchResult -Url $Url -Ok $true -Content $mixedHtml
    }
    if ($Url -match '/222$') {
        return New-FetchResult -Url $Url -Ok $false -StatusCode 503 -ErrorMessage 'unavailable'
    }
    return New-FetchResult -Url $Url -Ok $true -Content '<main><h1>IT Manager</h1><p>IT-Fuehrung in Muenchen.</p></main>'
}
$mixedResult = Invoke-JobAgentLiveHtmlAdapter -AdapterInput $input -Policy $collisionPolicy -Fetcher $mixedFetcher
Assert-True -Condition ($mixedResult.status -eq 'PARTIAL' -and -not $mixedResult.scan_complete -and @($mixedResult.raw_jobs).Count -eq 1) -Message 'Gemischter Detailabruf darf weder vollstaendig noch SUCCESS sein.'

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
        'career_navigation_candidate_rejection',
        'malformed_href_candidate_skip',
        'newsroom_story_candidate_rejection',
        'content_page_candidate_rejection',
        'ats_category_page_candidate_rejection',
        'avature_listing_navigation_rejection',
        'application_page_candidate_rejection',
        'aggregator_rejection',
        'jsonld_jobposting_extraction',
        'ats_url_pattern_detection',
        'greenhouse_ats_url_pattern_detection',
        'encoded_utf8_detail_path',
        'encoded_space_detail_path',
        'structured_navigation_candidate_rejection',
        'structured_ats_json_extraction',
        'live_adapter_success_with_detail_verification',
        'live_adapter_replaces_generic_anchor_title_from_detail_page',
        'live_adapter_complete_empty_source',
        'live_adapter_empty_pagination_remains_partial',
        'live_adapter_blocked_source_detection',
        'live_adapter_dynamic_source_detection',
        'live_adapter_jsonld_ats_success',
        'live_adapter_pagination_success',
        'live_adapter_job_pagination_remains_partial',
        'live_adapter_official_iframe_ats_success',
        'live_adapter_official_linked_job_portal_success',
        'live_adapter_avature_search_pagination_success',
        'rss_feed_job_extraction',
        'live_adapter_official_rss_feed_success',
        'live_adapter_successfactors_search_followup_success',
        'live_adapter_successfactors_rss_followup_success',
        'live_adapter_structured_json_ats_success',
        'live_adapter_gatsby_static_query_greenhouse_success',
        'live_adapter_blocked_detail_fetch',
        'live_adapter_timeout_detail_fetch',
        'live_adapter_preserves_fetch_error_diagnostics',
        'path_scoped_job_identity',
        'mixed_detail_fetch_is_partial',
        'retry_attempt_log'
    )
} | ConvertTo-Json -Depth 5
