#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestCandidate {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][string]$KnownCompanyId = $null,
        [Parameter()][AllowNull()][string]$KnownDomain = $null,
        [Parameter()][AllowNull()][string]$OfficialWebsiteUrl = $null,
        [Parameter()][bool]$OfficialWebsiteVerified = $false,
        [Parameter()][string]$TargetArea = 'MUNICH',
        [Parameter()][bool]$Staffing = $false,
        [Parameter()][datetime]$CandidateObservedAt = [datetime]::UtcNow
    )

    [pscustomobject]@{
        hint_id = $Id
        employer_name = $Name
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $Name
        location = 'Muenchen'
        target_area = $TargetArea
        source_id = 'source-registry:stepstone_muenchen'
        observed_url = 'https://www.stepstone.de/jobs/it/in-muenchen'
        observed_at = $CandidateObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        verification_status = 'UNVERIFIED'
        candidate_status = 'DISCOVERY_HINT'
        known_company_id = $KnownCompanyId
        known_company_domain = $KnownDomain
        confidence_score = 80
        is_staffing_agency = $Staffing
        official_verification_required = $true
        next_action = 'verify_official_company_website_or_career_url'
        official_website_url = $OfficialWebsiteUrl
        official_website_verification_status = if ($OfficialWebsiteVerified) { 'COMPANY_DOMAIN_VERIFIED' } else { 'UNVERIFIED' }
    }
}

function New-TestCompany {
    New-JobAgentCompanySeed `
        -CanonicalName 'Example AG' `
        -OfficialWebsiteUrl 'https://example.invalid/' `
        -CareerUrl $null `
        -Aliases @('Example') `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'Technology' `
        -ScanPriority 88 `
        -DiscoverySourceUrl 'https://example.invalid/' `
        -DiscoverySourceType 'DISCOVERY_HINT' `
        -DiscoveryOrigin 'test' `
        -VerificationStatus 'UNVERIFIED' `
        -CreatedAt ([datetime]'2026-08-23T08:00:00Z') `
        -NextScanAt ([datetime]'2026-08-24T08:00:00Z')
}

function New-FetchResult {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][bool]$Ok,
        [Parameter()][string]$Content = '',
        [Parameter()][int]$StatusCode = 200
    )

    [pscustomobject]@{
        ok = $Ok
        url = $Url
        final_url = $Url
        status_code = $StatusCode
        content = $Content
        content_type = 'text/html'
        error = if ($Ok) { $null } else { 'failed' }
    }
}

$observedAt = [datetime]'2026-08-23T09:00:00Z'
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds 2 -MaxFetchesPerCompany 4 -MaxCandidatesPerCompany 5
$company = New-TestCompany
$candidate = New-TestCandidate -Id 'hint:example' -Name 'Example AG' -KnownCompanyId 'company:example_ag' -KnownDomain 'example.invalid'

$careerFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/karriere">Karriere</a></html>'; break }
        'https://example.invalid/sitemap.xml' { New-FetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'; break }
        'https://example.invalid/sitemap_index.xml' { New-FetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'; break }
        'https://example.invalid/karriere' { New-FetchResult -Url $Url -Ok $true -Content '<main>Offene Stellen</main>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$careerVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $careerFetcher -ObservedAt $observedAt -ExpiresAfterDays 30
Assert-True -Condition ($careerVerification.status -eq 'CAREER_URL_VERIFIED') -Message 'Kandidat mit offizieller Karriere-URL wurde nicht verifiziert.'
Assert-True -Condition ($careerVerification.evidence[0].verification_url -eq 'https://example.invalid/karriere') -Message 'Verifikations-URL wurde falsch gesetzt.'
Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$careerVerification.evidence[0].evidence_text_hash)) -Message 'Evidence-Text-Hash fehlt.'
Assert-True -Condition ($careerVerification.evidence[0].expires_at -eq '2026-09-22T09:00:00.000Z') -Message 'Evidence-Ablaufdatum wurde falsch gesetzt.'

$atsFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://example.myworkdayjobs.com/de-DE/jobs">Offene Stellen</a></html>'; break }
        'https://example.invalid/sitemap.xml' { New-FetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'; break }
        'https://example.invalid/sitemap_index.xml' { New-FetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$atsVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $atsFetcher -ObservedAt $observedAt
Assert-True -Condition ($atsVerification.status -eq 'OFFICIAL_ATS_VERIFIED') -Message 'Offiziell verlinkter ATS-Kandidat wurde nicht als OFFICIAL_ATS_VERIFIED markiert.'
Assert-True -Condition ($atsVerification.evidence[0].evidence_type -eq 'COMPANY_LINKED_ATS') -Message 'ATS-Evidence hat falschen Typ.'
Assert-True -Condition ($atsVerification.evidence[0].verified_by_url -eq 'https://example.invalid/') -Message 'ATS-Evidence enthaelt keinen offiziellen verified_by_url-Beleg.'

$domainOnlyFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/about">About</a></html>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$domainVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $domainOnlyFetcher -ObservedAt $observedAt
Assert-True -Condition ($domainVerification.status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'Erreichbare offizielle Firmendomain wurde nicht als COMPANY_DOMAIN_VERIFIED markiert.'
Assert-True -Condition ($domainVerification.next_action -eq 'upsert_verified_company_without_job_source') -Message 'Domain-only-Verifikation darf keine JobSource-Folgeaktion haben.'

$wrongDomainCandidate = New-TestCandidate -Id 'hint:wrong-domain' -Name 'Example AG' -KnownCompanyId 'company:example_ag' -KnownDomain 'wrong.example.invalid'
$wrongDomainVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $wrongDomainCandidate -ExistingCompanies @($company) -Policy $policy -Fetcher $domainOnlyFetcher -ObservedAt $observedAt
Assert-True -Condition ($wrongDomainVerification.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Abweichende bekannte Kandidatendomain darf nicht automatisch verifiziert werden.'
Assert-True -Condition (@($wrongDomainVerification.review_reasons | Where-Object { $_ -eq 'KNOWN_COMPANY_DOMAIN_MISMATCH' }).Count -eq 1) -Message 'Domain-Mismatch erzeugt keinen Review-Grund.'

$missingDomain = Resolve-JobAgentCompanyCandidateVerification -Candidate (New-TestCandidate -Id 'hint:no-domain' -Name 'No Domain GmbH') -ExistingCompanies @() -Policy $policy -ObservedAt $observedAt
Assert-True -Condition ($missingDomain.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Kandidat ohne offiziellen Domainhinweis muss in Manual Review.'
Assert-True -Condition (@($missingDomain.review_reasons | Where-Object { $_ -eq 'OFFICIAL_COMPANY_DOMAIN_MISSING' }).Count -eq 1) -Message 'Manual-Review-Grund fuer fehlende Domain fehlt.'

$verifiedWebsiteCandidate = New-TestCandidate -Id 'hint:verified-website' -Name 'Verified Website AG' -OfficialWebsiteUrl 'https://www.verified.example.invalid/' -OfficialWebsiteVerified $true
$verifiedWebsiteFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://verified.example.invalid/' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/jobs">Jobs</a></html>'; break }
        'https://verified.example.invalid/sitemap.xml' { New-FetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'; break }
        'https://verified.example.invalid/sitemap_index.xml' { New-FetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'; break }
        'https://verified.example.invalid/jobs' { New-FetchResult -Url $Url -Ok $true -Content '<main>Offene Stellen</main>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$verifiedWebsiteResult = Resolve-JobAgentCompanyCandidateVerification -Candidate $verifiedWebsiteCandidate -ExistingCompanies @() -Policy $policy -Fetcher $verifiedWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($verifiedWebsiteResult.status -eq 'CAREER_URL_VERIFIED') -Message 'Verifizierte offizielle Website-URL ohne known_company_domain wird nicht genutzt.'
Assert-True -Condition ($verifiedWebsiteResult.company.canonical_domain -eq 'verified.example.invalid') -Message 'Domain-Ermittlung normalisiert die verifizierte Website falsch.'

$unverifiedWebsiteCandidate = New-TestCandidate -Id 'hint:unverified-website' -Name 'Unverified Website AG' -OfficialWebsiteUrl 'https://www.unverified.example.invalid/' -OfficialWebsiteVerified $false
$unverifiedWebsiteResult = Resolve-JobAgentCompanyCandidateVerification -Candidate $unverifiedWebsiteCandidate -ExistingCompanies @() -Policy $policy -Fetcher $verifiedWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($unverifiedWebsiteResult.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Unbelegte official_website_url darf keine automatische Domain-Ermittlung ausloesen.'
Assert-True -Condition (@($unverifiedWebsiteResult.review_reasons | Where-Object { $_ -eq 'OFFICIAL_COMPANY_DOMAIN_MISSING' }).Count -eq 1) -Message 'Unbelegte official_website_url muss fail-closed bleiben.'

$invalidWebsiteCandidate = New-TestCandidate -Id 'hint:invalid-website' -Name 'Invalid Website AG' -OfficialWebsiteUrl 'not-a-url' -OfficialWebsiteVerified $true
$invalidWebsiteResult = Resolve-JobAgentCompanyCandidateVerification -Candidate $invalidWebsiteCandidate -ExistingCompanies @() -Policy $policy -Fetcher $verifiedWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($invalidWebsiteResult.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Ungueltige official_website_url muss fail-closed bleiben.'

$timeoutFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $false -StatusCode 0
}
$timeoutVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $timeoutFetcher -ObservedAt $observedAt
Assert-True -Condition ($timeoutVerification.status -eq 'UNVERIFIED') -Message 'Timeout/Fetch-Fehler muss unverifiziert bleiben.'
Assert-True -Condition ($timeoutVerification.evidence[0].http_status -eq $null) -Message 'Timeout darf keinen erfolgreichen HTTP-Status vortaeuschen.'

$notFoundFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $false -StatusCode 404
}
$notFoundVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $notFoundFetcher -ObservedAt $observedAt
Assert-True -Condition ($notFoundVerification.status -eq 'UNVERIFIED') -Message '404-Fall muss unverifiziert bleiben.'

$jsOnlyFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $true -Content '<html><body><div id="root"></div><script>window.app = true;</script><noscript>JavaScript is required</noscript></body></html>'
}
$jsOnlyVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $jsOnlyFetcher -ObservedAt $observedAt
Assert-True -Condition ($jsOnlyVerification.status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'JS-only Firmendomain darf nur als Domainbeleg, nicht als Karrierequelle gelten.'
Assert-True -Condition ($jsOnlyVerification.next_action -eq 'upsert_verified_company_without_job_source') -Message 'JS-only Fall darf keine JobSource erzeugen.'

$aggregatorFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://www.stepstone.de/jobs/123">Jobs</a></html>'
}
$aggregatorVerification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($company) -Policy $policy -Fetcher $aggregatorFetcher -ObservedAt $observedAt
Assert-True -Condition ($aggregatorVerification.status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'Aggregator-Link darf nicht als Karrierebeleg akzeptiert werden.'
Assert-True -Condition ($aggregatorVerification.evidence[0].verification_url -eq 'https://example.invalid/') -Message 'Aggregator-Fall darf nur die offizielle Firmendomain belegen.'

$officialDirectoryEvidence = [pscustomobject]@{
    source_id = 'source-registry:test_official_directory'
    source_class = 'PUBLIC_INSTITUTION_DIRECTORY'
    evidence_level = 'SECONDARY_OFFICIAL_DIRECTORY'
    observed_url = 'https://directory.example.invalid/companies'
    observed_at = '2026-08-23T08:00:00.000Z'
}
$websiteDiscoveryFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://directory.example.invalid/companies' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://www.example.invalid/">Example AG</a></html>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$websiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-discovery' -Name 'Example AG') -SourceEvidence $officialDirectoryEvidence -Policy $policy -Fetcher $websiteDiscoveryFetcher -ObservedAt $observedAt
Assert-True -Condition ($websiteDiscovery.status -eq 'OFFICIAL_WEBSITE_VERIFIED') -Message 'Offizielle Verzeichnisseite verifiziert Firmenwebsite nicht.'
Assert-True -Condition ($websiteDiscovery.official_website_url -eq 'https://example.invalid/') -Message 'Website-Ermittlung normalisiert offizielle Website falsch.'
Assert-True -Condition ($websiteDiscovery.evidence[0].verified_by_url -eq 'https://directory.example.invalid/companies') -Message 'Website-Ermittlung speichert keinen Quellseitenbeleg.'

$detailWebsiteDiscoveryFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://directory.example.invalid/companies' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="/companies/example-ag">Example AG</a></html>'; break }
        'https://directory.example.invalid/companies/example-ag' { New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://www.example.invalid/">Website Example AG</a></html>'; break }
        default { New-FetchResult -Url $Url -Ok $false -StatusCode 404; break }
    }
}
$detailWebsiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-detail-discovery' -Name 'Example AG') -SourceEvidence $officialDirectoryEvidence -Policy $policy -Fetcher $detailWebsiteDiscoveryFetcher -ObservedAt $observedAt
Assert-True -Condition ($detailWebsiteDiscovery.status -eq 'OFFICIAL_WEBSITE_VERIFIED') -Message 'Offizielle Verzeichnisdetailseite verifiziert Firmenwebsite nicht.'
Assert-True -Condition ($detailWebsiteDiscovery.official_website_url -eq 'https://example.invalid/') -Message 'Detailseiten-Ermittlung normalisiert offizielle Website falsch.'
Assert-True -Condition ($detailWebsiteDiscovery.evidence[0].verified_by_url -eq 'https://directory.example.invalid/companies/example-ag') -Message 'Detailseiten-Ermittlung speichert keinen Detailseitenbeleg.'
Assert-True -Condition (@($detailWebsiteDiscovery.fetches).Count -eq 2) -Message 'Detailseiten-Ermittlung protokolliert Quell- und Detailabruf nicht.'

$aggregatorWebsiteFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://www.stepstone.de/cmp/example-ag">Example AG</a></html>'
}
$aggregatorWebsiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-aggregator' -Name 'Example AG') -SourceEvidence $officialDirectoryEvidence -Policy $policy -Fetcher $aggregatorWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($aggregatorWebsiteDiscovery.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Aggregator-Link darf nicht als offizielle Website-Ermittlung gelten.'

$searchRedirectWebsiteFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://google.de/url?q=https%3A%2F%2Fexample.invalid%2Freport.pdf">Example AG Studie</a></html>'
}
$searchRedirectWebsiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-search-redirect' -Name 'Example AG') -SourceEvidence $officialDirectoryEvidence -Policy $policy -Fetcher $searchRedirectWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($searchRedirectWebsiteDiscovery.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Suchmaschinen-Redirects duerfen keine Firmenwebsite verifizieren.'

$wrongNameWebsiteFetcher = {
    param([string]$Url, [object]$Policy)

    New-FetchResult -Url $Url -Ok $true -Content '<html><a href="https://www.other.invalid/">Andere GmbH</a></html>'
}
$wrongNameWebsiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-name-conflict' -Name 'Example AG') -SourceEvidence $officialDirectoryEvidence -Policy $policy -Fetcher $wrongNameWebsiteFetcher -ObservedAt $observedAt
Assert-True -Condition ($wrongNameWebsiteDiscovery.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Namenskonflikt muss bei Website-Ermittlung fail-closed bleiben.'

$jobBoardSourceEvidence = [pscustomobject]@{
    source_id = 'source-registry:test_jobboard'
    source_class = 'JOB_BOARD_DISCOVERY'
    evidence_level = 'DISCOVERY_HINT'
    observed_url = 'https://jobs.example.invalid/search'
    observed_at = '2026-08-23T08:00:00.000Z'
}
$jobBoardWebsiteDiscovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-jobboard' -Name 'Example AG') -SourceEvidence $jobBoardSourceEvidence -Policy $policy -Fetcher $websiteDiscoveryFetcher -ObservedAt $observedAt
Assert-True -Condition ($jobBoardWebsiteDiscovery.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Jobboerse darf nicht als offizieller Website-Ermittlungsbeleg dienen.'

$regionalDiscoveryHintEvidence = [pscustomobject]@{
    source_id = 'source-registry:test_github_directory'
    source_class = 'REGIONAL_DIRECTORY'
    evidence_level = 'DISCOVERY_HINT'
    observed_url = 'https://github.com/example/awesome-munich'
    observed_at = '2026-08-23T08:00:00.000Z'
}
$regionalDiscoveryHintResult = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate (New-TestCandidate -Id 'hint:website-regional-discovery' -Name 'Example AG') -SourceEvidence $regionalDiscoveryHintEvidence -Policy $policy -Fetcher $websiteDiscoveryFetcher -ObservedAt $observedAt
Assert-True -Condition ($regionalDiscoveryHintResult.status -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Regionale Discovery-Hints ohne offiziellen Evidenzlevel duerfen keine Firmenwebsite verifizieren.'

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-candidate-verify-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'data\jobagent') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'logs\jobagent') -Force | Out-Null
try {
    $document = New-JobAgentEmptyDocument -GeneratedAt $observedAt
    $document.companies = @($company)
    Write-JobAgentStore -ProjectRoot $projectRoot -Document $document | Out-Null

    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        hints_total = 3
        unverified_hints = 3
        hints = @(
            $candidate,
            (New-TestCandidate -Id 'hint:hays' -Name 'Hays Professional Solutions GmbH' -TargetArea 'MUNICH' -Staffing $true),
            (New-TestCandidate -Id 'hint:noresponse' -Name 'No Response AG' -KnownDomain 'noresponse.example.invalid')
        )
    } | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $projectRoot 'data\jobagent\company-discovery.hints.json') -Encoding UTF8

    [pscustomobject]@{
        responses = @(
            [pscustomobject]@{ url = 'https://example.invalid/'; ok = $true; status_code = 200; final_url = 'https://example.invalid/'; content = '<html><a href="/karriere">Karriere</a></html>' },
            [pscustomobject]@{ url = 'https://example.invalid/sitemap.xml'; ok = $true; status_code = 200; final_url = 'https://example.invalid/sitemap.xml'; content = '<urlset></urlset>' },
            [pscustomobject]@{ url = 'https://example.invalid/sitemap_index.xml'; ok = $true; status_code = 200; final_url = 'https://example.invalid/sitemap_index.xml'; content = '<sitemapindex></sitemapindex>' },
            [pscustomobject]@{ url = 'https://example.invalid/karriere'; ok = $true; status_code = 200; final_url = 'https://example.invalid/karriere'; content = '<main>Karriere bei Example</main>' }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $projectRoot 'fixture-map.json') -Encoding UTF8

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Verify-JobAgentCompanyCandidates.ps1') -ProjectRoot $projectRoot -MaxCandidates 3 -FixtureMapPath 'fixture-map.json' -MaxRetries 3 -ExpiresAfterDays 730 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Candidate-Verifikationsscript ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 100
    $scriptStore = Read-JobAgentStore -ProjectRoot $projectRoot
    $scriptCompany = @($scriptStore.companies | Where-Object { $_.company_id -eq 'company:example_ag' })[0]
    $scriptQueue = Get-Content -Raw -LiteralPath ([string]$scriptResult.queue_path) | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($scriptResult.schema_version -eq 'jobagent/company-candidate-verification/v1') -Message 'Candidate-Verifikationsscript schreibt falsche Schema-Version.'
    Assert-True -Condition (@($scriptResult.verified_candidate_ids | Where-Object { $_ -eq 'hint:example' }).Count -eq 1) -Message 'Candidate-Verifikationsscript meldet verifizierten Kandidaten nicht.'
    Assert-True -Condition (@($scriptResult.checked_candidate_ids | Where-Object { $_ -eq 'hint:hays' }).Count -eq 0) -Message 'Candidate-Verifikationsscript darf nicht-aktionable Manual-Review-Kandidaten nicht live verifizieren.'
    Assert-True -Condition (@($scriptResult.unverified_candidate_ids | Where-Object { $_ -eq 'hint:noresponse' }).Count -eq 1) -Message 'Candidate-Verifikationsscript meldet unverifizierten Retry-Kandidaten nicht.'
    Assert-True -Condition ($scriptResult.verification_queue.clusters_total -ge 3) -Message 'Candidate-Verifikationsscript erzeugt keine Cluster-Queue.'
    Assert-True -Condition ($scriptResult.decision_report.schema_version -eq 'jobagent/company-candidate-verification-decision-report/v1') -Message 'Candidate-Verifikationsscript schreibt keinen Decision-Report.'
    Assert-True -Condition ($scriptResult.decision_report.productive_upsert_allowed_total -eq 1) -Message 'Decision-Report zaehlt produktive Upserts falsch.'
    Assert-True -Condition ($scriptResult.decision_report.manual_review_total -eq 0) -Message 'Decision-Report darf nicht-aktionable Manual-Review-Kandidaten nicht als verarbeitet zaehlen.'
    Assert-True -Condition ($scriptResult.decision_report.fail_closed_reject_total -eq 1) -Message 'Decision-Report zaehlt fail-closed Rejects falsch.'
    Assert-True -Condition (@($scriptResult.decision_report.reject_items | Where-Object { $_.candidate_id -eq 'hint:noresponse' -and $_.decision -eq 'RETRY_DEFERRED' }).Count -eq 1) -Message 'Decision-Report weist Retry-Reject nicht aus.'
    Assert-True -Condition (@($scriptQueue.queue | Where-Object { $_.candidate_id -eq 'hint:example' -and $_.status -eq 'VERIFIED' }).Count -eq 1) -Message 'Queue markiert verifizierten Kandidaten nicht.'
    Assert-True -Condition (@($scriptQueue.queue | Where-Object { $_.candidate_id -eq 'hint:hays' -and $_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count -eq 1) -Message 'Queue markiert Manual-Review-Kandidaten nicht.'
    Assert-True -Condition (@($scriptQueue.queue | Where-Object { $_.candidate_id -eq 'hint:noresponse' -and $_.status -eq 'RETRY_SCHEDULED' -and $_.retry_count -eq 1 }).Count -eq 1) -Message 'Queue plant unverifizierten Kandidaten nicht fuer Retry ein.'
    Assert-True -Condition ($scriptCompany.verification_status -eq 'CAREER_URL_VERIFIED') -Message 'Candidate-Verifikationsscript aktualisiert Firmenstatus nicht.'
    Assert-True -Condition (@($scriptStore.job_sources | Where-Object { $_.company_id -eq 'company:example_ag' }).Count -eq 1) -Message 'Candidate-Verifikationsscript erzeugt keine offizielle Karrierequelle.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.log_path) -PathType Leaf) -Message 'Candidate-Verifikationsscript schreibt kein Logartefakt.'

    $secondScriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Verify-JobAgentCompanyCandidates.ps1') -ProjectRoot $projectRoot -MaxCandidates 3 -FixtureMapPath 'fixture-map.json' -MaxRetries 3 -ExpiresAfterDays 730 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Candidate-Verifikationsscript-Zweitlauf ist fehlgeschlagen: " + ($secondScriptOutput -join "`n"))
    $secondScriptResult = ($secondScriptOutput -join "`n") | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($secondScriptResult.verification_queue.processed_total -eq 0) -Message 'Candidate-Verifikationsscript darf Retry-Kandidaten vor next_attempt_at nicht erneut verarbeiten.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

$websiteRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-website-discovery-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $websiteRoot 'data\jobagent') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $websiteRoot 'logs\jobagent') -Force | Out-Null
try {
    $freshObservedAt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-sources/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        items = @(
            [pscustomobject]@{
                source_id = 'source-registry:test_official_directory'
                source_class = 'PUBLIC_INSTITUTION_DIRECTORY'
                evidence_level = 'SECONDARY_OFFICIAL_DIRECTORY'
                import_mode = 'TARGETED_LOOKUP_ONLY'
                review_required = $true
                allowed_use = 'Fixture'
                forbidden_use = 'Fixture'
                rate_limit_policy = 'Fixture'
                robots_or_terms_note = 'Fixture'
                url = 'https://directory.example.invalid/companies'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $websiteRoot 'data\jobagent\company-discovery.sources.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        hints_total = 2
        unverified_hints = 2
        hints = @(
            [pscustomobject]@{
                hint_id = 'hint:website-tool'
                employer_name = 'Example AG'
                normalized_name = 'example'
                location = 'Muenchen'
                target_area = 'MUNICH'
                source_id = 'source-registry:test_official_directory'
                observed_url = 'https://directory.example.invalid/companies'
                observed_at = $freshObservedAt
                verification_status = 'UNVERIFIED'
                candidate_status = 'REGIONAL_DISCOVERY_HINT'
                confidence_score = 80
                official_verification_required = $true
                next_action = 'verify_official_company_website_or_career_url'
            },
            [pscustomobject]@{
                hint_id = 'hint:website-missing-source'
                employer_name = 'Missing Source AG'
                normalized_name = 'missing source'
                location = 'Muenchen'
                target_area = 'MUNICH'
                source_id = 'source-registry:missing_directory'
                observed_url = ''
                observed_at = $freshObservedAt
                verification_status = 'UNVERIFIED'
                candidate_status = 'REGIONAL_DISCOVERY_HINT'
                confidence_score = 80
                official_verification_required = $true
                next_action = 'verify_official_company_website_or_career_url'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $websiteRoot 'data\jobagent\company-discovery.hints.json') -Encoding UTF8
    [pscustomobject]@{
        responses = @(
            [pscustomobject]@{ url = 'https://directory.example.invalid/companies'; ok = $true; status_code = 200; final_url = 'https://directory.example.invalid/companies'; content = '<html><a href="/companies/example-ag">Example AG</a></html>' },
            [pscustomobject]@{ url = 'https://directory.example.invalid/companies/example-ag'; ok = $true; status_code = 200; final_url = 'https://directory.example.invalid/companies/example-ag'; content = '<html><a href="https://www.example.invalid/">Website Example AG</a></html>' }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $websiteRoot 'fixture-map.json') -Encoding UTF8

    $websiteScriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Discover-JobAgentCompanyCandidateWebsites.ps1') -ProjectRoot $websiteRoot -MaxCandidates 2 -FixtureMapPath 'fixture-map.json' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Website-Ermittlungsscript ist fehlgeschlagen: " + ($websiteScriptOutput -join "`n"))
    $websiteScriptResult = ($websiteScriptOutput -join "`n") | ConvertFrom-Json -Depth 100
    $updatedHints = Get-Content -Raw -LiteralPath (Join-Path $websiteRoot 'data\jobagent\company-discovery.hints.json') | ConvertFrom-Json -Depth 100
    $updatedQueue = Get-Content -Raw -LiteralPath ([string]$websiteScriptResult.queue_path) | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($websiteScriptResult.verified_total -eq 1) -Message 'Website-Ermittlungsscript meldet verifizierte Website nicht.'
    Assert-True -Condition ($websiteScriptResult.manual_review_total -eq 1) -Message 'Website-Ermittlungsscript meldet fail-closed Manual-Review nicht.'
    Assert-True -Condition ($updatedHints.hints[0].official_website_url -eq 'https://example.invalid/') -Message 'Website-Ermittlungsscript persistiert offizielle Website nicht.'
    Assert-True -Condition ($updatedHints.hints[0].official_website_evidence[0].verified_by_url -eq 'https://directory.example.invalid/companies/example-ag') -Message 'Website-Ermittlungsscript persistiert Detailseitenbeleg nicht.'
    Assert-True -Condition ($updatedHints.hints[0].official_website_verification_status -eq 'OFFICIAL_WEBSITE_VERIFIED') -Message 'Website-Ermittlungsscript persistiert Verifikationsstatus nicht.'
    Assert-True -Condition (@($updatedQueue.queue | Where-Object { $_.candidate_id -eq 'hint:website-tool' -and $_.next_action -eq 'VERIFY_OFFICIAL_SITE' -and $_.status -eq 'PENDING' }).Count -eq 1) -Message 'Website-Ermittlung ueberfuehrt Queue nicht in offizielle Site-Verifikation.'
    Assert-True -Condition (@($updatedQueue.queue | Where-Object { $_.candidate_id -eq 'hint:website-missing-source' -and $_.next_action -eq 'DISCOVER_OFFICIAL_WEBSITE' -and $_.status -eq 'MANUAL_REVIEW_REQUIRED' -and $_.last_status -eq 'MANUAL_REVIEW_REQUIRED' -and -not [string]::IsNullOrWhiteSpace([string]$_.last_attempt_at) }).Count -eq 1) -Message 'Website-Ermittlung persistiert fail-closed Manual-Review-Ergebnis nicht in der Queue.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$websiteScriptResult.log_path) -PathType Leaf) -Message 'Website-Ermittlungsscript schreibt kein Logartefakt.'

    $secondWebsiteScriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Discover-JobAgentCompanyCandidateWebsites.ps1') -ProjectRoot $websiteRoot -MaxCandidates 2 -FixtureMapPath 'fixture-map.json' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Website-Ermittlungsscript-Zweitlauf ist fehlgeschlagen: " + ($secondWebsiteScriptOutput -join "`n"))
    $secondWebsiteScriptResult = ($secondWebsiteScriptOutput -join "`n") | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($secondWebsiteScriptResult.processed_total -eq 0) -Message 'Website-Ermittlung darf bereits fail-closed gepruefte Kandidaten nicht sofort wiederholen.'
}
finally {
    if (Test-Path -LiteralPath $websiteRoot) {
        Remove-Item -LiteralPath $websiteRoot -Recurse -Force
    }
}

$requeueWebsiteRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-website-discovery-requeue-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $requeueWebsiteRoot 'data\jobagent') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $requeueWebsiteRoot 'logs\jobagent') -Force | Out-Null
try {
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-sources/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        items = @(
            [pscustomobject]@{
                source_id = 'source-registry:test_official_directory'
                source_class = 'PUBLIC_INSTITUTION_DIRECTORY'
                evidence_level = 'SECONDARY_OFFICIAL_DIRECTORY'
                import_mode = 'TARGETED_LOOKUP_ONLY'
                review_required = $true
                allowed_use = 'Fixture'
                forbidden_use = 'Fixture'
                rate_limit_policy = 'Fixture'
                robots_or_terms_note = 'Fixture'
                url = 'https://directory.example.invalid/companies'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $requeueWebsiteRoot 'data\jobagent\company-discovery.sources.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        hints_total = 1
        unverified_hints = 1
        hints = @(
            [pscustomobject]@{
                hint_id = 'hint:website-requeue'
                employer_name = 'Example AG'
                normalized_name = 'example'
                location = 'Muenchen'
                target_area = 'MUNICH'
                source_id = 'source-registry:test_official_directory'
                observed_url = 'https://directory.example.invalid/companies'
                observed_at = '2026-08-23T08:00:00.000Z'
                verification_status = 'UNVERIFIED'
                candidate_status = 'REGIONAL_DISCOVERY_HINT'
                confidence_score = 80
                official_verification_required = $true
                next_action = 'verify_official_company_website_or_career_url'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $requeueWebsiteRoot 'data\jobagent\company-discovery.hints.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        queue_type = 'review'
        generated_at = '2026-08-23T09:00:00.000Z'
        clusters_total = 1
        candidates_total = 1
        ready_total = 0
        action_counts = [pscustomobject]@{ DISCOVER_OFFICIAL_WEBSITE = 1 }
        queue = @(
            [pscustomobject]@{
                identity_cluster_id = 'identity-cluster:hint_website_requeue'
                candidate_id = 'hint:website-requeue'
                candidate_ids = @('hint:website-requeue')
                canonical_name = 'Example AG'
                source_count = 1
                priority_score = 96
                next_action = 'DISCOVER_OFFICIAL_WEBSITE'
                reason_codes = @('OFFICIAL_VERIFICATION_REQUIRED')
                target_area_basis = @('BRANCH_HINT_IN_TARGET')
                status = 'MANUAL_REVIEW_REQUIRED'
                review_reason = 'OFFICIAL_VERIFICATION_REQUIRED'
                retry_count = 0
                last_attempt_at = '2026-08-23T09:00:00.000Z'
                next_attempt_at = $null
                last_status = 'MANUAL_REVIEW_REQUIRED'
                last_reason = 'Kein offizieller Firmendomain-Hinweis vorhanden; keine automatische Uebernahme.'
                freshness_status = 'CURRENT'
                risk_level = 'LOW'
                source_evidence = [pscustomobject]@{
                    source_id = 'source-registry:test_official_directory'
                    source_class = 'PUBLIC_INSTITUTION_DIRECTORY'
                    evidence_level = 'SECONDARY_OFFICIAL_DIRECTORY'
                    observed_url = 'https://directory.example.invalid/companies'
                    observed_at = '2026-08-23T08:00:00.000Z'
                    record_hash = 'fixture'
                    allowed_use = 'Fixture'
                    rate_limit_policy = 'Fixture'
                }
                dedupe_context = [pscustomobject]@{
                    dedupe_keys = @('name:example')
                    conflict_flags = @()
                    cluster_candidate_count = 1
                }
            }
        )
    } | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $requeueWebsiteRoot 'data\jobagent\company-candidate-verification.queue.json') -Encoding UTF8
    [pscustomobject]@{
        responses = @(
            [pscustomobject]@{ url = 'https://directory.example.invalid/companies'; ok = $true; status_code = 200; final_url = 'https://directory.example.invalid/companies'; content = '<html><a href="https://www.example.invalid/">Example AG</a></html>' }
        )
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $requeueWebsiteRoot 'fixture-map.json') -Encoding UTF8

    $requeueOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Discover-JobAgentCompanyCandidateWebsites.ps1') -ProjectRoot $requeueWebsiteRoot -MaxCandidates 1 -FixtureMapPath 'fixture-map.json' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Website-Ermittlungsscript-Requeue ist fehlgeschlagen: " + ($requeueOutput -join "`n"))
    $requeueResult = ($requeueOutput -join "`n") | ConvertFrom-Json -Depth 100
    $requeueQueue = Get-Content -Raw -LiteralPath ([string]$requeueResult.queue_path) | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($requeueResult.processed_total -eq 1) -Message 'Website-Ermittlung verarbeitet keinen frueheren Domain-Missing-Review mit offizieller Source-Evidence.'
    Assert-True -Condition ($requeueResult.verified_total -eq 1) -Message 'Website-Ermittlung requeued offiziellen Source-Beleg nicht.'
    Assert-True -Condition (@($requeueQueue.queue | Where-Object { $_.candidate_id -eq 'hint:website-requeue' -and $_.status -eq 'PENDING' -and $_.next_action -eq 'VERIFY_OFFICIAL_SITE' }).Count -eq 1) -Message 'Website-Ermittlung setzt requeued Kandidaten nicht auf offizielle Site-Verifikation.'
}
finally {
    if (Test-Path -LiteralPath $requeueWebsiteRoot) {
        Remove-Item -LiteralPath $requeueWebsiteRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'candidate_career_url_verified',
        'candidate_official_ats_verified',
        'candidate_company_domain_verified',
        'candidate_wrong_domain_manual_review',
        'candidate_missing_domain_manual_review',
        'candidate_verified_official_website_url_domain_discovery',
        'candidate_unverified_official_website_url_rejected',
        'candidate_invalid_official_website_url_rejected',
        'candidate_timeout_unverified',
        'candidate_404_unverified',
        'candidate_js_only_domain_only',
        'aggregator_not_accepted_as_career_source',
        'official_directory_website_discovery',
        'official_directory_detail_page_website_discovery',
        'aggregator_rejected_for_website_discovery',
        'search_redirect_rejected_for_website_discovery',
        'name_conflict_rejected_for_website_discovery',
        'jobboard_rejected_for_website_discovery',
        'regional_discovery_hint_rejected_for_website_discovery',
        'website_discovery_script_updates_hint_and_queue',
        'candidate_verification_script_upserts_only_verified_sources',
        'candidate_verification_cluster_queue_retry_and_review',
        'candidate_verification_retry_schedule_skip_until_due',
        'candidate_verification_decision_report_review_and_reject',
        'website_discovery_requeues_domain_missing_reviews_with_official_source_evidence'
    )
} | ConvertTo-Json -Depth 4
