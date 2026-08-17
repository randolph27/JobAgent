#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Deduplication.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestLocation {
    param([string]$Label = 'Muenchen')
    [pscustomobject]@{
        label = $Label
        city = $Label
        region = 'Bayern'
        country = 'DE'
        target_area = if ($Label -eq 'Freising') { 'FREISING' } else { 'MUNICH' }
    }
}

function New-TestClassification {
    [pscustomobject]@{
        result = 'MATCH'
        priority = 'A'
        score = 90
        reasons = @('Fixture')
        rejected_reasons = @()
        evaluated_at = '2026-08-17T10:30:00.000Z'
    }
}

function New-TestJob {
    param(
        [string]$JobId = 'job:example_ag_official_job_id_123',
        [string]$ExternalJobId = '123',
        [string]$AtsJobId = 'UNKNOWN',
        [string]$OfficialUrl = 'https://example.invalid/careers/head-it-123',
        [string]$Title = 'Head of IT',
        [string]$Status = 'NEW',
        [object]$Location = (New-TestLocation)
    )

    [pscustomobject]@{
        job_id = $JobId
        company_id = 'company:example_ag'
        official_url = $OfficialUrl
        alternative_official_urls = @('https://example.myworkdayjobs.invalid/job/123')
        source_id = 'source:example_ag_career'
        external_job_id = $ExternalJobId
        ats_job_id = $AtsJobId
        title = $Title
        location = $Location
        work_model = 'HYBRID'
        employment_type = 'FULL_TIME'
        status = $Status
        first_seen = '2026-08-17T10:30:00.000Z'
        last_seen = '2026-08-17T10:30:00.000Z'
        changed_at = '2026-08-17T10:30:00.000Z'
        classification = New-TestClassification
        priority = 'A'
        requirements = @('Fuehrungserfahrung')
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

function New-TestDocument {
    param([object[]]$Jobs)
    $document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T10:30:00Z')
    $document.jobs = @($Jobs)
    return $document
}

$baseJob = New-TestJob
$document = New-TestDocument -Jobs @($baseJob)

$sameCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Head of IT' `
    -OfficialUrl 'https://www.example.invalid/careers/head-it-123/?utm_source=x&sessionid=abc#apply' `
    -ExternalJobId '123' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$sameDecision = Resolve-JobAgentJobDeduplication -Document $document -Candidate $sameCandidate
Assert-True -Condition ($sameDecision.decision -eq 'KNOWN') -Message "Dieselbe Stelle wurde nicht als bekannt erkannt: $($sameDecision | ConvertTo-Json -Compress)"
Assert-True -Condition ($sameDecision.job_id -eq $baseJob.job_id) -Message 'Bekannte Stelle hat nicht dieselbe job_id behalten.'
Assert-True -Condition ($sameDecision.identity_basis -eq 'OFFICIAL_JOB_ID') -Message 'Offizielle Job-ID wurde nicht priorisiert.'

$urlOnlyDocument = New-TestDocument -Jobs @(New-TestJob -ExternalJobId '123' -OfficialUrl 'https://example.invalid/careers/head-it-123')
$idChangedCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Head of IT' `
    -OfficialUrl 'https://example.invalid/careers/head-it-123?utm_campaign=mail' `
    -ExternalJobId '987' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$idChangedDecision = Resolve-JobAgentJobDeduplication -Document $urlOnlyDocument -Candidate $idChangedCandidate
Assert-True -Condition ($idChangedDecision.is_existing -eq $true) -Message 'Job-ID-Wechsel bei gleicher kanonischer URL erzeugt faelschlich neue Stelle.'
Assert-True -Condition ($idChangedDecision.decision -eq 'UPDATED') -Message 'Job-ID-Wechsel wurde nicht als Update erkannt.'
Assert-True -Condition (@($idChangedDecision.changed_fields) -contains 'external_job_id') -Message 'Geaenderte externe Job-ID fehlt in changed_fields.'

$titleChangedCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Director Information Technology' `
    -OfficialUrl 'https://example.invalid/careers/changed-url' `
    -ExternalJobId '123' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$titleChangedDecision = Resolve-JobAgentJobDeduplication -Document $document -Candidate $titleChangedCandidate
Assert-True -Condition ($titleChangedDecision.job_id -eq $baseJob.job_id) -Message 'Titel- oder URL-Aenderung bei gleicher offizieller Job-ID erzeugt neue Stelle.'
Assert-True -Condition (@($titleChangedDecision.changed_fields) -contains 'title') -Message 'Titel-Aenderung fehlt in changed_fields.'
Assert-True -Condition (@($titleChangedDecision.changed_fields) -contains 'official_url') -Message 'URL-Aenderung fehlt in changed_fields.'

$alternativeCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Head of IT' `
    -OfficialUrl 'https://example.myworkdayjobs.invalid/job/123?source=linkedin' `
    -ExternalJobId 'UNKNOWN' `
    -AtsJobId 'UNKNOWN' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$alternativeDecision = Resolve-JobAgentJobDeduplication -Document $document -Candidate $alternativeCandidate
Assert-True -Condition ($alternativeDecision.is_existing -eq $true) -Message 'Alternative offizielle URL wurde nicht zur Wiedererkennung genutzt.'
Assert-True -Condition ($alternativeDecision.identity_basis -eq 'CANONICAL_URL') -Message 'Alternative URL wurde nicht als CANONICAL_URL-Match ausgewiesen.'

$repostCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Head of IT' `
    -OfficialUrl 'https://example.invalid/careers/head-it-456' `
    -ExternalJobId '456' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$repostDecision = Resolve-JobAgentJobDeduplication -Document $document -Candidate $repostCandidate
Assert-True -Condition ($repostDecision.decision -eq 'NEW') -Message 'Echte Neuausschreibung mit neuer ID und neuer URL wurde faelschlich zusammengefuehrt.'

$fallbackDocument = New-TestDocument -Jobs @(New-TestJob -JobId 'job:example_ag_composite_head_it' -ExternalJobId 'UNKNOWN' -AtsJobId 'UNKNOWN' -OfficialUrl 'https://example.invalid/search?job=head-it' -Title 'Head of IT')
$fallbackDocument.jobs[0].alternative_official_urls = @()
$fallbackCandidate = New-JobAgentJobIdentityCandidate `
    -CompanyId 'company:example_ag' `
    -Title 'Head of IT' `
    -OfficialUrl 'https://example.invalid/search?job=head-it&utm_source=x' `
    -ExternalJobId 'UNKNOWN' `
    -AtsJobId 'UNKNOWN' `
    -Location (New-TestLocation) `
    -SourceId 'source:example_ag_career'
$fallbackDecision = Resolve-JobAgentJobDeduplication -Document $fallbackDocument -Candidate $fallbackCandidate
Assert-True -Condition ($fallbackDecision.is_existing -eq $true) -Message 'Kanonische URL ohne starke IDs wurde nicht wiedererkannt.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'same_job_second_run_known',
        'official_job_id_priority',
        'job_id_change_via_canonical_url',
        'url_parameter_canonicalization',
        'title_change_is_update',
        'alternative_official_url_match',
        'reposting_new_id_new_url_is_new'
    )
} | ConvertTo-Json -Depth 4
