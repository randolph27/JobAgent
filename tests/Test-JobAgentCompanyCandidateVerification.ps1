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
        [Parameter()][bool]$Staffing = $false
    )

    [pscustomobject]@{
        hint_id = $Id
        employer_name = $Name
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $Name
        location = 'Muenchen'
        target_area = $TargetArea
        source_id = 'source-registry:stepstone_muenchen'
        observed_url = 'https://www.stepstone.de/jobs/it/in-muenchen'
        observed_at = '2026-08-23T08:00:00.000Z'
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

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Verify-JobAgentCompanyCandidates.ps1') -ProjectRoot $projectRoot -MaxCandidates 3 -FixtureMapPath 'fixture-map.json' -MaxRetries 3 2>&1)
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
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
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
        'candidate_verification_script_upserts_only_verified_sources',
        'candidate_verification_cluster_queue_retry_and_review',
        'candidate_verification_decision_report_review_and_reject'
    )
} | ConvertTo-Json -Depth 4
