#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking

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
        ats = @()
        scan_status = 'PENDING'
        scan_priority = 80
        next_scan_at = '2026-08-18T10:30:00Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = [pscustomobject]@{
            type = 'OFFICIAL_WEBSITE'
            url = 'https://example.invalid/careers'
            observed_at = '2026-08-17T10:00:00Z'
            verification_url = 'https://example.invalid/careers'
            discovery_origin = 'seed.manual'
            target_area = 'MUNICH'
            industry_hint = 'UNKNOWN'
            evidence_note = 'Offizielle Firmenquelle wurde manuell gepflegt.'
        }
        created_at = '2026-08-17T10:00:00Z'
        updated_at = '2026-08-17T10:00:00Z'
        last_successful_scan_at = $null
    }
}

function New-TestSource {
    param([bool]$Official = $true)

    [pscustomobject]@{
        source_id = 'source:example_ag_career'
        company_id = 'company:example_ag'
        source_type = 'CAREER_PAGE'
        url = 'https://example.invalid/careers'
        canonical_url = 'https://example.invalid/careers'
        is_official = $Official
        verified_at = '2026-08-17T10:30:00Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @(
            [pscustomobject]@{
                status = 'VERIFIED'
                evidence_type = 'CAREER_URL'
                url = 'https://example.invalid/careers'
                basis_url = 'https://example.invalid/'
                redirect_chain = @()
                observed_at = '2026-08-17T10:30:00Z'
                reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.'
            }
        )
    }
}

$context = New-JobAgentScanContext -ScanRunId 'scanrun:20260817T103000Z' -TimeoutSeconds 10 -MaxResults 2 -SearchTerms @('Head IT', '')
Assert-True -Condition ($context.timeout_seconds -eq 10) -Message 'ScanContext uebernimmt Timeout nicht.'
Assert-True -Condition (@($context.search_terms).Count -eq 1) -Message 'ScanContext filtert leere Suchbegriffe nicht.'

$input = New-JobAgentAdapterInput -Company (New-TestCompany) -JobSource (New-TestSource) -ScanContext $context
Assert-True -Condition ($input.source.is_official -eq $true) -Message 'AdapterInput enthaelt keine offizielle Quelle.'

try {
    New-JobAgentAdapterInput -Company (New-TestCompany) -JobSource (New-TestSource -Official $false) -ScanContext $context | Out-Null
    throw 'Nicht-offizielle Quelle wurde akzeptiert.'
}
catch {
    Assert-True -Condition ($_.Exception.Message -match 'nicht-offizielle') -Message "Unerwarteter Fehler fuer nicht-offizielle Quelle: $($_.Exception.Message)"
}

$rawJob = New-JobAgentRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/job-123' -ExternalJobId '123' -LocationLabel 'Muenchen' -Summary 'Fuehrungsrolle' -ExtractionConfidence 95
Assert-True -Condition ($rawJob.external_job_id -eq '123') -Message 'RawJob speichert externe Job-ID nicht.'
Assert-True -Condition ($rawJob.source_status -eq 'ACTIVE') -Message 'RawJob setzt keinen Default fuer source_status.'

try {
    New-JobAgentRawJob -Title 'Head of IT' -DetailUrl 'not-a-url' | Out-Null
    throw 'Ungueltige Detail-URL wurde akzeptiert.'
}
catch {
    Assert-True -Condition ($_.Exception.Message -match 'detail_url') -Message "Unerwarteter Fehler fuer ungueltige Detail-URL: $($_.Exception.Message)"
}

$fixtureResult = Invoke-JobAgentFixtureAdapter -AdapterInput $input -FixtureJobs @($rawJob)
Assert-True -Condition ($fixtureResult.status -eq 'SUCCESS') -Message 'FixtureAdapter meldet keinen Erfolg.'
Assert-True -Condition (@($fixtureResult.raw_jobs).Count -eq 1) -Message 'FixtureAdapter liefert falsche Trefferanzahl.'
Assert-True -Condition ($fixtureResult.scan_attempt.error_class -eq 'NONE') -Message 'FixtureAdapter erzeugt falsche Fehlerklasse.'

$emptyFixtureResult = Invoke-JobAgentFixtureAdapter -AdapterInput $input -FixtureJobs @()
Assert-True -Condition ($emptyFixtureResult.error_class -eq 'NO_JOBS_FOUND') -Message 'Leerer FixtureAdapter-Lauf klassifiziert nicht NO_JOBS_FOUND.'
Assert-True -Condition ($emptyFixtureResult.retry_recommendation -eq 'RETRY_NEXT_RUN') -Message 'Leerer FixtureAdapter-Lauf setzt falsche Retry-Empfehlung.'

$html = @'
<html>
  <body>
    <a href="/careers/job-123">Head of IT</a>
    <a href="https://example.invalid/careers/job-456?utm_source=x">Director IT</a>
  </body>
</html>
'@
$htmlResult = Invoke-JobAgentGenericHtmlAdapter -AdapterInput $input -Html $html
Assert-True -Condition ($htmlResult.status -eq 'SUCCESS') -Message 'GenericHtmlAdapter meldet keinen Erfolg.'
Assert-True -Condition (@($htmlResult.raw_jobs).Count -eq 2) -Message 'GenericHtmlAdapter extrahiert falsche Trefferanzahl.'
Assert-True -Condition ($htmlResult.raw_jobs[0].detail_url -eq 'https://example.invalid/careers/job-123') -Message 'GenericHtmlAdapter loest relative URL nicht auf.'

$noJobsResult = Invoke-JobAgentGenericHtmlAdapter -AdapterInput $input -Html '<html><body><p>Keine Links</p></body></html>'
Assert-True -Condition ($noJobsResult.error_class -eq 'NO_JOBS_FOUND') -Message 'GenericHtmlAdapter erkennt leere Trefferliste nicht.'

$emptyHtmlResult = Invoke-JobAgentGenericHtmlAdapter -AdapterInput $input -Html ''
Assert-True -Condition ($emptyHtmlResult.error_class -eq 'PARSING_ERROR') -Message 'GenericHtmlAdapter erkennt leeres HTML nicht als Parsingfehler.'
$attemptDocument = Record-JobAgentScanAttempt -Document (New-JobAgentEmptyDocument) -ScanAttempt $htmlResult.scan_attempt
Assert-JobAgentDocument -Document $attemptDocument

$contract = Get-JobAgentAdapterContract
foreach ($errorClass in @('NONE', 'NOT_REACHABLE', 'TIMEOUT', 'BLOCKED', 'NO_JOBS_FOUND', 'UNCLEAR_SOURCE', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')) {
    Assert-True -Condition (@($contract.error_classes) -contains $errorClass) -Message "Adaptervertrag fehlt Fehlerklasse $errorClass."
}
Assert-True -Condition (@($contract.raw_job_optional) -contains 'source_status') -Message 'Adaptervertrag nennt source_status nicht als optionales RawJob-Feld.'

[pscustomobject]@{
    status = 'ok'
    cases = @('scan_context', 'official_source_guard', 'raw_job_validation', 'fixture_success', 'fixture_empty', 'html_success', 'html_no_jobs', 'html_parsing_error', 'contract_errors', 'raw_job_source_status')
    raw_jobs = @($htmlResult.raw_jobs).Count
} | ConvertTo-Json -Depth 4
