#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
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

[pscustomobject]@{
    status = 'ok'
    cases = @('canonical_url', 'company_domain', 'career_url', 'ats_domain', 'aggregator_rejection', 'unverified_third_party', 'verified_source', 'ats_requires_verified_by_url', 'resolved_alternatives')
} | ConvertTo-Json -Depth 4
