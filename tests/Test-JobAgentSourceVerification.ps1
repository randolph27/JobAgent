#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceVerificationModule = Import-Module (Join-Path $root 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking -PassThru

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
    [pscustomobject]@{
        company_id = 'company:example_ag'
        canonical_name = 'Example AG'
        canonical_domain = 'example.invalid'
        official_website_url = 'https://example.invalid/'
        career_url = 'https://example.invalid/careers'
        aliases = @('Example')
        locations = @()
        industry = 'UNKNOWN'
        ats = @(
            [pscustomobject]@{
                system = 'Workday'
                official_domain = 'myworkdayjobs.invalid'
                verified_by_url = 'https://example.invalid/careers'
            }
        )
    }
}

$canonical = ConvertTo-JobAgentCanonicalUrl -Url 'https://www.example.invalid/careers/job-123/?utm_source=x&jobId=123&sessionid=abc#apply'
Assert-True -Condition ($canonical -eq 'https://example.invalid/careers/job-123?jobId=123') -Message "Kanonisierung entfernt Tracking nicht korrekt: $canonical"

$companyDomain = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url 'https://jobs.example.invalid/careers/job-123?utm_medium=email'
Assert-True -Condition ($companyDomain.is_official -eq $true) -Message 'Subdomain der Firmendomain wurde nicht akzeptiert.'
Assert-True -Condition ($companyDomain.canonical_url -eq 'https://jobs.example.invalid/careers/job-123') -Message 'Offizielle URL wurde nicht kanonisiert.'

$career = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url 'https://example.invalid/careers/job-456'
Assert-True -Condition ($career.verification_basis -eq 'CAREER_URL') -Message 'Karriere-URL wurde nicht als Verification-Basis erkannt.'
Assert-True -Condition (@($career.verification_evidence).Count -eq 1) -Message 'Karriere-URL liefert keinen einzelnen Verifikationsbeleg.'
Assert-True -Condition ($career.verification_evidence[0].evidence_type -eq 'CAREER_URL') -Message 'Karriere-URL nutzt falschen Evidenztyp.'

$encodedOfficial = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url 'https://example.invalid/job/Ulm-Senior-Strategischer-Eink%C3%A4ufer-Externalisierung-Baugruppen-%28E%20E%29-%28wmd%29-89077/1364637855'
Assert-True -Condition ($encodedOfficial.is_official -eq $true) -Message 'Percent-encodete offizielle Detail-URL mit kodiertem Leerzeichen wurde abgelehnt.'
Assert-True -Condition ($encodedOfficial.canonical_url -match '%20') -Message 'Percent-encodetes Leerzeichen wurde in der kanonischen URL verloren.'

$ats = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url 'https://example.myworkdayjobs.invalid/job/789?source=linkedin'
Assert-True -Condition ($ats.is_official -eq $true) -Message 'Firmengebundene ATS-Domain wurde nicht akzeptiert.'
Assert-True -Condition ($ats.verification_basis -eq 'COMPANY_LINKED_ATS') -Message 'ATS-Verifikationsbasis ist falsch.'
Assert-True -Condition (@($ats.verification_evidence).Count -eq 2) -Message 'ATS-Verifikation liefert nicht beide Evidenzbelege.'
Assert-True -Condition (@($ats.verification_evidence | Where-Object evidence_type -eq 'ATS_VERIFIED_BY_URL').Count -eq 1) -Message 'ATS-Verifikation enthaelt keinen verified_by_url-Beleg.'

foreach ($url in @(
    'https://www.stepstone.de/stellenangebote--Head-of-IT-Example--123.html',
    'https://de.indeed.com/viewjob?jk=123',
    'https://www.linkedin.com/jobs/view/123',
    'https://www.xing.com/jobs/example-head-it-123',
    'https://www.kununu.com/de/example/jobs',
    'https://www.glassdoor.de/job-listing/head-it-example.htm'
)) {
    $evaluation = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url $url
    Assert-True -Condition ($evaluation.status -eq 'INVALID') -Message "Aggregator wurde nicht abgelehnt: $url"
}

$unknown = Get-JobAgentOfficialSourceEvaluation -Company (New-TestCompany) -Url 'https://thirdparty.invalid/jobs/123'
Assert-True -Condition ($unknown.status -eq 'UNVERIFIED') -Message 'Unbekannte Drittquelle wurde nicht als UNVERIFIED markiert.'
Assert-True -Condition ($unknown.verification_evidence[0].status -eq 'UNVERIFIED') -Message 'Unbekannte Drittquelle liefert keinen UNVERIFIED-Beleg.'

$source = New-JobAgentVerifiedJobSource -Company (New-TestCompany) -Url 'https://example.invalid/careers/job-123?utm_campaign=x' -SourceType 'JOB_DETAIL' -VerifiedAt ([datetime]'2026-08-17T10:30:00Z')
Assert-True -Condition ($source.canonical_url -eq 'https://example.invalid/careers/job-123') -Message 'Verified JobSource speichert keine kanonische URL.'
Assert-True -Condition ($source.is_official -eq $true) -Message 'Verified JobSource ist nicht offiziell.'
Assert-True -Condition (@($source.verification_evidence).Count -eq 1) -Message 'Verified JobSource persistiert keinen Verifikationsbeleg.'
Assert-True -Condition ($source.verification_evidence[0].observed_at -eq '2026-08-17T10:30:00.000Z') -Message 'Verified JobSource setzt observed_at nicht auf VerifiedAt.'

try {
    New-JobAgentVerifiedJobSource -Company (New-TestCompany) -Url 'https://www.stepstone.de/jobs/123' | Out-Null
    throw 'Aggregator wurde als JobSource akzeptiert.'
}
catch {
    Assert-True -Condition ($_.Exception.Message -match 'Nicht-offizielle') -Message "Unerwarteter Fehler fuer Aggregator-JobSource: $($_.Exception.Message)"
}

$missingProofCompany = New-TestCompany
$missingProofCompany.ats = @(
    [pscustomobject]@{
        system = 'Workday'
        official_domain = 'myworkdayjobs.invalid'
        verified_by_url = ''
    }
)
$missingProof = Get-JobAgentOfficialSourceEvaluation -Company $missingProofCompany -Url 'https://example.myworkdayjobs.invalid/job/789'
Assert-True -Condition ($missingProof.is_official -eq $false) -Message 'ATS ohne Firmenbeleg wurde faelschlich akzeptiert.'
Assert-True -Condition ($missingProof.reason -match 'verified_by_url') -Message 'ATS ohne Firmenbeleg liefert keinen klaren Hinweis.'

$resolved = Resolve-JobAgentOfficialJobUrl `
    -Company (New-TestCompany) `
    -PrimaryUrl 'https://example.invalid/careers/job-123?utm_source=x' `
    -AlternativeUrls @('https://example.myworkdayjobs.invalid/job/123?sid=abc', 'https://www.linkedin.com/jobs/view/123')
Assert-True -Condition ($resolved.status -eq 'VALID') -Message 'Primaere offizielle Job-URL wurde nicht validiert.'
Assert-True -Condition ($resolved.official_url -eq 'https://example.invalid/careers/job-123') -Message 'Primaere offizielle URL wurde falsch aufgeloest.'
Assert-True -Condition (@($resolved.alternative_official_urls).Count -eq 1) -Message 'Alternative offizielle URLs wurden nicht korrekt gefiltert.'

$careerPolicy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds 3 -MaxFetchesPerCompany 4 -MaxCandidatesPerCompany 5
Assert-True -Condition ($careerPolicy.policy -eq 'official-site-linked-career-or-ats-only') -Message 'Career-Verifikationspolicy dokumentiert den Fail-closed-Vertrag nicht.'
Assert-True -Condition ($careerPolicy.host_concurrency -eq 1) -Message 'Career-Verifikationspolicy setzt das Host-Concurrency-Limit nicht.'

$parallelPolicy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds 3 -MaxFetchesPerCompany 4 -MaxCandidatesPerCompany 5 -HostConcurrency 3
Assert-True -Condition ($parallelPolicy.host_concurrency -eq 3) -Message 'Career-Verifikationspolicy uebernimmt ein explizites Host-Concurrency-Limit nicht.'

$curlPolicy = New-JobAgentCompanyCareerVerificationPolicy -FetchClient 'curl'
Assert-True -Condition ($curlPolicy.fetch_client -eq 'curl') -Message 'Career-Verifikationspolicy uebernimmt den nativen Curl-Fetch-Client nicht.'
Assert-True -Condition ($curlPolicy.curl_schannel_revoke_best_effort -eq $true) -Message 'Career-Verifikationspolicy dokumentiert den kontrollierten Schannel-Curl-Fallback nicht.'

$wslPolicy = New-JobAgentCompanyCareerVerificationPolicy -FetchClient 'wsl-curl' -WslDistribution 'Ubuntu-22.04'
Assert-True -Condition ($wslPolicy.fetch_client -eq 'wsl-curl') -Message 'Career-Verifikationspolicy uebernimmt den expliziten Fetch-Client nicht.'
Assert-True -Condition ($wslPolicy.wsl_distribution -eq 'Ubuntu-22.04') -Message 'Career-Verifikationspolicy dokumentiert die WSL-Distribution nicht.'

$curlCertificateDiagnostic = $sourceVerificationModule.Invoke({ Get-JobAgentCurlFailureDiagnostic -Output 'curl: (60) SSL: no alternative certificate subject name matches target host name' })
Assert-True -Condition ($curlCertificateDiagnostic.error_class -eq 'TLS_HANDSHAKE_FAILED') -Message 'Curl-Diagnose klassifiziert Zertifikatsfehler nicht als TLS-Handshake-Fehler.'
$curlCredentialDiagnostic = $sourceVerificationModule.Invoke({ Get-JobAgentCurlFailureDiagnostic -Output 'schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS' })
Assert-True -Condition ($curlCredentialDiagnostic.error_class -eq 'TLS_CREDENTIAL_UNAVAILABLE') -Message 'Curl-Diagnose klassifiziert Schannel-Credentialfehler nicht.'

$curlOpenSslOptions = $sourceVerificationModule.Invoke({
        Resolve-JobAgentCurlInvocationOptions -Path 'C:\tools\curl.exe' -VersionOutput 'curl 8.17.0 libcurl/8.17.0 LibreSSL/4.2.1 Features: CAcert SSL'
    })
Assert-True -Condition ([string]$curlOpenSslOptions.tls_backend -eq 'openssl-compatible' -and $curlOpenSslOptions.ca_native -eq $true) -Message 'Curl-Aufrufoptionen aktivieren OS-CA fuer OpenSSL-kompatibles curl nicht.'

$curlSchannelOptions = $sourceVerificationModule.Invoke({
        Resolve-JobAgentCurlInvocationOptions -Path 'C:\Windows\System32\curl.exe' -VersionOutput 'curl 8.13.0 libcurl/8.13.0 Schannel Features: SSL'
    })
Assert-True -Condition ([string]$curlSchannelOptions.tls_backend -eq 'schannel' -and $curlSchannelOptions.ca_native -eq $false) -Message 'Curl-Aufrufoptionen duerfen Schannel nicht mit --ca-native konfigurieren.'

$curlParsed = $sourceVerificationModule.Invoke({
        ConvertFrom-JobAgentCompanyVerificationCurlOutput `
            -Output @('HTTP/2 200', 'content-type: text/html', 'retry-after: 17', '', '<html>ok</html>', 'JOBAGENT_FINAL_URL:https://example.invalid/jobs', 'JOBAGENT_STATUS:200') `
            -ExitCode 0 `
            -Url 'https://example.invalid/jobs' `
            -ClientName 'curl.exe'
    })
Assert-True -Condition ($curlParsed.ok -eq $true -and $curlParsed.fetch_client -eq 'curl.exe' -and $curlParsed.content -match 'ok') -Message 'Curl-Output-Parser verliert Erfolg, Client oder Content.'
Assert-True -Condition ($curlParsed.content_type -eq 'text/html' -and $curlParsed.retry_after_seconds -eq 17) -Message 'Curl-Output-Parser liest Header nicht case-insensitive aus.'

$curlSchannelFallback = $sourceVerificationModule.Invoke({
        $result = ConvertFrom-JobAgentCompanyVerificationCurlOutput `
            -Output @('HTTP/2 200', 'content-type: text/html', '', '<html>ok</html>', 'JOBAGENT_FINAL_URL:https://example.invalid/jobs', 'JOBAGENT_STATUS:200') `
            -ExitCode 0 `
            -Url 'https://example.invalid/jobs' `
            -ClientName 'curl.exe'
        Add-JobAgentCurlSchannelFallbackMetadata -Result $result
    })
Assert-True -Condition ($curlSchannelFallback.ok -eq $true -and $curlSchannelFallback.fetch_client -eq 'curl.exe+ssl-revoke-best-effort') -Message 'Curl-Schannel-Fallback verliert Erfolg oder Client-Metadaten.'
Assert-True -Condition ($curlSchannelFallback.tls_revocation_policy -eq 'ssl-revoke-best-effort') -Message 'Curl-Schannel-Fallback dokumentiert die TLS-Revocation-Policy nicht.'

$careerHtml = '<html><body><a href="/de/karriere">Karriere</a><a href="https://www.linkedin.com/jobs/view/123">Jobs</a></body></html>'
$careerLinks = @(Get-JobAgentCompanyCareerCandidateLinks -Html $careerHtml -BaseUrl 'https://example.invalid/' -Company (New-TestCompany) -MaxCandidates 5)
Assert-True -Condition ($careerLinks.Count -eq 1) -Message 'Career-Linksuche filtert offizielle Karrierekandidaten nicht korrekt.'
Assert-True -Condition ($careerLinks[0].url -eq 'https://example.invalid/de/karriere') -Message 'Career-Linksuche kanonisiert Kandidaten nicht.'

$misleadingCareerHtml = '<html><body><a href="/unternehmen/erdgasmobilitaet">Karriere und Unternehmen</a></body></html>'
$misleadingCareerLinks = @(Get-JobAgentCompanyCareerCandidateLinks -Html $misleadingCareerHtml -BaseUrl 'https://example.invalid/' -Company (New-TestCompany) -MaxCandidates 5)
Assert-True -Condition ($misleadingCareerLinks.Count -eq 0) -Message 'Career-Linksuche akzeptiert einen offiziellen, aber nicht karrierebezogenen Firmenpfad.'

$substringCareerHtml = '<html><body><a href="/elektromobilitaet/oeffentliche-ladestationen/ladekarte-bestellen">Stellen und bestellen</a></body></html>'
$substringCareerLinks = @(Get-JobAgentCompanyCareerCandidateLinks -Html $substringCareerHtml -BaseUrl 'https://example.invalid/' -Company (New-TestCompany) -MaxCandidates 5)
Assert-True -Condition ($substringCareerLinks.Count -eq 0) -Message 'Career-Linksuche akzeptiert stellen als Teil von bestellen.'

function New-CareerFetchResult {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][bool]$Ok,
        [Parameter()][string]$FinalUrl = $Url,
        [Parameter()][string]$Content = '',
        [Parameter()][int]$StatusCode = 200
    )

    [pscustomobject]@{
        ok = $Ok
        url = $Url
        final_url = $FinalUrl
        status_code = $StatusCode
        content = $Content
        content_type = 'text/html'
        error = if ($Ok) { $null } else { 'failed' }
    }
}

$companyCareerFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<html><a href="/jobs">Jobs & Karriere</a></html>'
            break
        }
        'https://example.invalid/careers' {
            New-CareerFetchResult -Url $Url -Ok $false -StatusCode 404
            break
        }
        'https://example.invalid/sitemap.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'
            break
        }
        'https://example.invalid/sitemap_index.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'
            break
        }
        'https://example.invalid/jobs' {
            New-CareerFetchResult -Url $Url -Ok $true -FinalUrl 'https://example.invalid/jobs/' -Content '<html><h1>Jobs</h1></html>'
            break
        }
        default {
            New-CareerFetchResult -Url $Url -Ok $false -StatusCode 404
            break
        }
    }
}
$companyCareerVerification = Resolve-JobAgentCompanyCareerVerification -Company (New-TestCompany) -Policy $careerPolicy -Fetcher $companyCareerFetcher
Assert-True -Condition ($companyCareerVerification.status -eq 'CAREER_URL_VERIFIED') -Message 'Offizieller Karrierepfad wurde nicht verifiziert.'
Assert-True -Condition ($companyCareerVerification.career_url -eq 'https://example.invalid/jobs') -Message 'Offizieller Karrierepfad wurde falsch kanonisiert.'
Assert-True -Condition ($companyCareerVerification.verification_evidence[0].evidence_type -eq 'CAREER_URL') -Message 'Offizieller Karrierepfad erzeugt falschen Evidenztyp.'
Assert-True -Condition (@($companyCareerVerification.verification_evidence[0].redirect_chain).Count -ge 1) -Message 'Offizieller Karrierepfad protokolliert keine Redirect-Kette.'

$atsCompany = New-TestCompany
$atsCompany.career_url = $null
$atsFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<html><a href="https://example.myworkdayjobs.com/de-DE/jobs">Offene Stellen</a></html>'
            break
        }
        'https://example.invalid/sitemap.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'
            break
        }
        'https://example.invalid/sitemap_index.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'
            break
        }
        default {
            New-CareerFetchResult -Url $Url -Ok $false -StatusCode 404
            break
        }
    }
}
$atsVerification = Resolve-JobAgentCompanyCareerVerification -Company $atsCompany -Policy $careerPolicy -Fetcher $atsFetcher
Assert-True -Condition ($atsVerification.status -eq 'ATS_VERIFIED_BY_COMPANY_LINK') -Message 'Offiziell verlinkte ATS-URL wurde nicht verifiziert.'
Assert-True -Condition ($atsVerification.ats.official_domain -eq 'myworkdayjobs.com') -Message 'ATS-Domain wurde nicht erkannt.'
Assert-True -Condition ($atsVerification.verification_evidence[0].evidence_type -eq 'COMPANY_LINKED_ATS') -Message 'ATS-Verifikation erzeugt falschen Evidenztyp.'

$workableCompany = New-TestCompany
$workableCompany.career_url = $null
$workableCompany.ats = @(
    [pscustomobject]@{
        system = 'Workable'
        official_domain = 'apply.workable.com'
        verified_by_url = 'https://example.invalid/jobs'
    }
)
$workableFetcher = {
    param([string]$Url, [object]$Policy)

    switch ($Url) {
        'https://example.invalid/' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<html><a href="https://apply.workable.com/example/">Jobs</a></html>'
            break
        }
        'https://example.invalid/sitemap.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<urlset></urlset>'
            break
        }
        'https://example.invalid/sitemap_index.xml' {
            New-CareerFetchResult -Url $Url -Ok $true -Content '<sitemapindex></sitemapindex>'
            break
        }
        default {
            New-CareerFetchResult -Url $Url -Ok $false -StatusCode 404
            break
        }
    }
}
$workableVerification = Resolve-JobAgentCompanyCareerVerification -Company $workableCompany -Policy $careerPolicy -Fetcher $workableFetcher
Assert-True -Condition ($workableVerification.status -eq 'ATS_VERIFIED_BY_COMPANY_LINK') -Message 'Offiziell verlinkte Workable-ATS-URL wurde nicht verifiziert.'
Assert-True -Condition ($workableVerification.ats.official_domain -eq 'apply.workable.com') -Message 'Workable-ATS-Domain wurde nicht erkannt.'

$dynamicFetcher = {
    param([string]$Url, [object]$Policy)

    New-CareerFetchResult -Url $Url -Ok $true -Content '<html><body><div id="root"></div><script id="__NEXT_DATA__" type="application/json">{}</script><noscript>Enable JavaScript</noscript></body></html>'
}
$dynamicVerification = Resolve-JobAgentCompanyCareerVerification -Company $atsCompany -Policy $careerPolicy -Fetcher $dynamicFetcher
Assert-True -Condition ($dynamicVerification.status -eq 'TECHNICAL_LIMITATION') -Message 'JS-only-Seite wird nicht als technische Limitation markiert.'

$manualFetcher = {
    param([string]$Url, [object]$Policy)

    New-CareerFetchResult -Url $Url -Ok $true -Content '<html><body><a href="/about">About</a></body></html>'
}
$manualVerification = Resolve-JobAgentCompanyCareerVerification -Company $atsCompany -Policy $careerPolicy -Fetcher $manualFetcher
Assert-True -Condition ($manualVerification.status -eq 'MANUAL_REVIEW') -Message 'Belegloser HTML-Fall wird nicht fail-closed als Manual Review markiert.'

[pscustomobject]@{
    status = 'ok'
    cases = @('canonical_url', 'company_domain', 'career_url', 'encoded_official_url', 'ats_domain', 'aggregator_rejection', 'unverified_third_party', 'verified_source', 'ats_requires_verified_by_url', 'resolved_alternatives', 'career_verification_policy', 'career_verification_host_concurrency_policy', 'career_verification_curl_policy', 'career_verification_wsl_curl_policy', 'curl_tls_error_diagnostics', 'curl_invocation_options', 'curl_output_parser', 'curl_schannel_fallback_metadata', 'career_link_extraction', 'career_link_rejects_non_career_company_path', 'career_link_rejects_substring_path_match', 'company_career_path_verification', 'company_linked_ats_verification', 'workable_company_linked_ats_verification', 'career_dynamic_limitation', 'career_manual_review')
} | ConvertTo-Json -Depth 4
