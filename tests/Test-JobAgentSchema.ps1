#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$schemaPath = Join-Path $root 'schemas\jobagent.schema.json'
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -Depth 100
$fixtureRoot = Join-Path $root 'tests\fixtures\jobagent'

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
    [pscustomobject]@{
        label = 'Muenchen'
        city = 'Muenchen'
        region = 'Bayern'
        country = 'DE'
        target_area = 'MUNICH'
    }
}

function New-ValidJobAgentDocument {
    $location = New-TestLocation
    [pscustomobject]@{
        schema_version = 'jobagent/v1'
        generated_at = '2026-08-17T10:30:00Z'
        companies = @(
            [pscustomobject]@{
                company_id = 'company:example_ag'
                canonical_name = 'Example AG'
                canonical_domain = 'example.invalid'
                official_website_url = 'https://example.invalid/'
                career_url = 'https://example.invalid/careers'
                aliases = @('Example')
                locations = @($location)
                industry = 'UNKNOWN'
                ats = @()
                scan_status = 'SUCCESS'
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
                updated_at = '2026-08-17T10:30:00Z'
                last_successful_scan_at = '2026-08-17T10:30:00Z'
            }
        )
        jobs = @(
            [pscustomobject]@{
                job_id = 'job:example_ag_head_it_123'
                company_id = 'company:example_ag'
                official_url = 'https://example.invalid/careers/head-it-123'
                alternative_official_urls = @('https://jobs.example.invalid/job/123')
                source_id = 'source:example_ag_career'
                external_job_id = '123'
                ats_job_id = 'UNKNOWN'
                title = 'Head of IT'
                location = $location
                work_model = 'HYBRID'
                employment_type = 'FULL_TIME'
                description = 'IT-Fuehrungsrolle mit offizieller Detailseite.'
                description_source = 'OFFICIAL_SOURCE'
                status = 'NEW'
                first_seen = '2026-08-17T10:30:00Z'
                last_seen = '2026-08-17T10:30:00Z'
                changed_at = '2026-08-17T10:30:00Z'
                classification = [pscustomobject]@{
                    result = 'MATCH'
                    priority = 'A'
                    score = 92
                    reasons = @('IT-Gesamtverantwortung belegt', 'Zielgebiet Muenchen')
                    rejected_reasons = @()
                    evaluated_at = '2026-08-17T10:30:00Z'
                }
                priority = 'A'
                requirements = @('Fuehrungserfahrung', 'IT-Strategie')
                salary = 'UNKNOWN'
                identity_basis = 'OFFICIAL_JOB_ID'
            }
        )
        job_sources = @(
            [pscustomobject]@{
                source_id = 'source:example_ag_career'
                company_id = 'company:example_ag'
                source_type = 'CAREER_PAGE'
                url = 'https://example.invalid/careers'
                canonical_url = 'https://example.invalid/careers'
                is_official = $true
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
        )
        scan_runs = @(
            [pscustomobject]@{
                scan_run_id = 'scanrun:20260817T103000Z'
                started_at = '2026-08-17T10:30:00Z'
                finished_at = '2026-08-17T10:31:00Z'
                status = 'SUCCESS'
                company_ids = @('company:example_ag')
                artifact_paths = @('logs/jobagent/daily-run-2026-08-17.json')
                errors = @()
            }
        )
        scan_attempts = @(
            [pscustomobject]@{
                scan_attempt_id = 'scanattempt:example_ag_20260817T103000Z'
                scan_run_id = 'scanrun:20260817T103000Z'
                company_id = 'company:example_ag'
                source_id = 'source:example_ag_career'
                started_at = '2026-08-17T10:30:00Z'
                finished_at = '2026-08-17T10:30:10Z'
                status = 'SUCCESS'
                adapter = 'fixture-html'
                error_class = 'NONE'
                retry_recommendation = 'NONE'
                http_status = 200
            }
        )
        job_snapshots = @(
            [pscustomobject]@{
                snapshot_id = 'snapshot:example_ag_head_it_123_20260817'
                job_id = 'job:example_ag_head_it_123'
                scan_run_id = 'scanrun:20260817T103000Z'
                source_id = 'source:example_ag_career'
                captured_at = '2026-08-17T10:30:10Z'
                content_hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                status = 'NEW'
                title = 'Head of IT'
                location = $location
                official_url = 'https://example.invalid/careers/head-it-123'
                summary = 'IT-Fuehrungsrolle mit offizieller Detailseite.'
                description = 'IT-Fuehrungsrolle mit offizieller Detailseite.'
            }
        )
        change_events = @(
            [pscustomobject]@{
                change_event_id = 'change:example_ag_head_it_123_created'
                job_id = 'job:example_ag_head_it_123'
                scan_run_id = 'scanrun:20260817T103000Z'
                event_type = 'JOB_CREATED'
                created_at = '2026-08-17T10:30:10Z'
                old_status = $null
                new_status = 'NEW'
                changed_fields = @('status')
                reason = 'Erstmals ueber offizielle Karriere-URL erkannt.'
            }
        )
    }
}

function Test-UriValue {
    param([Parameter(Mandatory)][string]$Value)

    [Uri]::IsWellFormedUriString($Value, [UriKind]::Absolute)
}

function Assert-RequiredProperty {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$Property,
        [Parameter(Mandatory)][string]$Context
    )

    Assert-True -Condition ($Object.PSObject.Properties.Name -contains $Property) -Message "$Context fehlt Pflichtfeld $Property."
    $value = $Object.$Property
    Assert-True -Condition ($null -ne $value) -Message "$Context.$Property ist null."
    if ($value -is [string]) {
        Assert-True -Condition ($value.Length -gt 0) -Message "$Context.$Property ist leer."
    }
}

function Test-JobAgentDocument {
    param([Parameter(Mandatory)][object]$Document)

    foreach ($property in @('schema_version', 'generated_at', 'companies', 'jobs', 'job_sources', 'scan_runs', 'scan_attempts', 'job_snapshots', 'change_events')) {
        Assert-RequiredProperty -Object $Document -Property $property -Context 'root'
    }
    Assert-True -Condition ($Document.schema_version -eq 'jobagent/v1') -Message 'schema_version muss jobagent/v1 sein.'

    foreach ($company in @($Document.companies)) {
        foreach ($property in @('company_id', 'canonical_name', 'canonical_domain', 'official_website_url', 'career_url', 'locations', 'scan_status', 'scan_priority', 'next_scan_at', 'verification_status', 'discovery_source', 'created_at', 'updated_at')) {
            Assert-RequiredProperty -Object $company -Property $property -Context 'company'
        }
        Assert-True -Condition ($company.company_id -match '^company:') -Message 'company_id braucht Prefix company:.'
        Assert-True -Condition (Test-UriValue $company.official_website_url) -Message 'official_website_url ist keine absolute URL.'
        if ($null -ne $company.career_url) {
            Assert-True -Condition (Test-UriValue $company.career_url) -Message 'career_url ist keine absolute URL.'
        }
        Assert-True -Condition (($company.scan_priority -ge 1) -and ($company.scan_priority -le 100)) -Message 'scan_priority liegt ausserhalb 1..100.'
        Assert-True -Condition (@('COMPANY_DOMAIN_VERIFIED', 'CAREER_URL_VERIFIED', 'UNVERIFIED') -contains $company.verification_status) -Message "Ungueltiger verification_status $($company.verification_status)."
    }

    foreach ($source in @($Document.job_sources)) {
        foreach ($property in @('source_id', 'company_id', 'source_type', 'url', 'canonical_url', 'is_official', 'verified_at', 'verification_basis', 'verification_evidence')) {
            Assert-RequiredProperty -Object $source -Property $property -Context 'job_source'
        }
        Assert-True -Condition ($source.is_official -eq $true) -Message 'JobSource muss offiziell sein.'
        Assert-True -Condition (@($source.verification_evidence).Count -ge 1) -Message 'JobSource braucht mindestens einen Verifikationsbeleg.'
    }

    foreach ($job in @($Document.jobs)) {
        foreach ($property in @('job_id', 'company_id', 'official_url', 'alternative_official_urls', 'source_id', 'external_job_id', 'ats_job_id', 'title', 'location', 'work_model', 'employment_type', 'description', 'description_source', 'status', 'first_seen', 'last_seen', 'changed_at', 'classification', 'priority', 'requirements', 'salary', 'identity_basis')) {
            Assert-RequiredProperty -Object $job -Property $property -Context 'job'
        }
        Assert-True -Condition ($job.job_id -match '^job:') -Message 'job_id braucht Prefix job:.'
        Assert-True -Condition (Test-UriValue $job.official_url) -Message 'official_url ist keine absolute URL.'
        if ($job.PSObject.Properties.Name -contains 'alternative_official_urls') {
            foreach ($alternativeUrl in @($job.alternative_official_urls)) {
                Assert-True -Condition (Test-UriValue $alternativeUrl) -Message 'alternative_official_urls enthaelt keine absolute URL.'
            }
        }
        Assert-True -Condition (@('NEW', 'ACTIVE', 'UPDATED', 'CLOSED', 'REMOVED', 'INVALID') -contains $job.status) -Message "Ungueltiger Jobstatus $($job.status)."
        Assert-True -Condition (@('OFFICIAL_SOURCE', 'NONE') -contains $job.description_source) -Message "Ungueltige description_source $($job.description_source)."
        Assert-True -Condition (($job.external_job_id -ne 'UNKNOWN') -or ($job.ats_job_id -ne 'UNKNOWN') -or ($job.identity_basis -eq 'CANONICAL_URL')) -Message 'Job braucht eine stabile Identitaetsgrundlage.'
    }

    foreach ($snapshot in @($Document.job_snapshots)) {
        foreach ($property in @('snapshot_id', 'job_id', 'scan_run_id', 'source_id', 'captured_at', 'content_hash', 'status', 'title', 'location', 'official_url', 'summary', 'description')) {
            Assert-RequiredProperty -Object $snapshot -Property $property -Context 'job_snapshot'
        }
        Assert-True -Condition ($snapshot.content_hash -match '^[a-f0-9]{64}$') -Message 'Snapshot content_hash muss SHA-256-Format haben.'
        Assert-True -Condition (Test-UriValue $snapshot.official_url) -Message 'Snapshot official_url ist keine absolute URL.'
    }
}

Assert-True -Condition ($schema.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') -Message 'Schema nutzt nicht Draft 2020-12.'
Assert-True -Condition ($schema.properties.schema_version.const -eq 'jobagent/v1') -Message 'Schema-Version ist nicht fixiert.'
foreach ($definition in @('company', 'job', 'job_source', 'scan_run', 'scan_attempt', 'adapter_result', 'raw_job', 'job_snapshot', 'change_event')) {
    Assert-True -Condition ($schema.'$defs'.PSObject.Properties.Name -contains $definition) -Message "Schema-Definition fehlt: $definition."
}

$valid = New-ValidJobAgentDocument
Test-JobAgentDocument -Document $valid

$missingOfficialUrl = New-ValidJobAgentDocument
$missingOfficialUrl.jobs[0].PSObject.Properties.Remove('official_url')
try {
    Test-JobAgentDocument -Document $missingOfficialUrl
    throw 'Negativtest fehlende official_url hat keinen Fehler erzeugt.'
}
catch {
    Assert-True -Condition ($_.Exception.Message -match 'official_url') -Message "Unerwarteter Fehler fuer fehlende official_url: $($_.Exception.Message)"
}

$missingStableId = New-ValidJobAgentDocument
$missingStableId.jobs[0].job_id = ''
try {
    Test-JobAgentDocument -Document $missingStableId
    throw 'Negativtest fehlende stabile job_id hat keinen Fehler erzeugt.'
}
catch {
    Assert-True -Condition ($_.Exception.Message -match 'job_id') -Message "Unerwarteter Fehler fuer fehlende job_id: $($_.Exception.Message)"
}

$removed = New-ValidJobAgentDocument
$removed.jobs[0].status = 'REMOVED'
$removed.job_snapshots[0].status = 'REMOVED'
$removed.change_events[0].event_type = 'JOB_REMOVED'
$removed.change_events[0].old_status = 'ACTIVE'
$removed.change_events[0].new_status = 'REMOVED'
$removed.change_events[0].reason = 'Nach erfolgreichem offiziellem Scan nicht mehr auffindbar.'
Test-JobAgentDocument -Document $removed

$updated = New-ValidJobAgentDocument
$updated.jobs[0].status = 'UPDATED'
$updated.jobs[0].title = 'Director IT'
$updated.job_snapshots[0].status = 'UPDATED'
$updated.job_snapshots[0].title = 'Director IT'
$updated.change_events[0].event_type = 'JOB_UPDATED'
$updated.change_events[0].old_status = 'ACTIVE'
$updated.change_events[0].new_status = 'UPDATED'
$updated.change_events[0].changed_fields = @('title', 'status')
$updated.change_events[0].reason = 'Titel auf offizieller Detailseite geaendert.'
Test-JobAgentDocument -Document $updated

$ajv = Get-Command npx -ErrorAction SilentlyContinue
if ($null -ne $ajv) {
    $validFixture = Join-Path $fixtureRoot 'valid.json'
    $missingOfficialUrlFixture = Join-Path $fixtureRoot 'invalid-missing-official-url.json'
    $missingJobIdFixture = Join-Path $fixtureRoot 'invalid-missing-job-id.json'

    $compileOutput = @(& npx --yes --package ajv-cli@5 --package ajv-formats ajv compile -s $schemaPath --spec=draft2020 -c ajv-formats 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "AJV konnte Schema nicht kompilieren: $($compileOutput -join "`n")"

    $validOutput = @(& npx --yes --package ajv-cli@5 --package ajv-formats ajv validate -s $schemaPath -d $validFixture --spec=draft2020 -c ajv-formats 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "AJV hat gueltiges Fixture abgelehnt: $($validOutput -join "`n")"

    foreach ($invalidFixture in @($missingOfficialUrlFixture, $missingJobIdFixture)) {
        $invalidOutput = @(& npx --yes --package ajv-cli@5 --package ajv-formats ajv validate -s $schemaPath -d $invalidFixture --spec=draft2020 -c ajv-formats 2>&1)
        Assert-True -Condition ($LASTEXITCODE -ne 0) -Message "AJV hat ungueltiges Fixture akzeptiert: $invalidFixture`n$($invalidOutput -join "`n")"
    }
}

[pscustomobject]@{
    status = 'ok'
    schema = $schemaPath
    ajv = $(if ($null -ne $ajv) { 'run' } else { 'not-found' })
    cases = @('valid', 'missing_official_url', 'missing_stable_job_id', 'updated_job', 'removed_job')
} | ConvertTo-Json -Depth 4
