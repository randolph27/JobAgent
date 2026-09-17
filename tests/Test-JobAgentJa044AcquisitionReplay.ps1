#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$FixturePath = (Join-Path $PSScriptRoot 'fixtures\jobagent\ja-044-acquisition-replay.json'),
    [Parameter()][AllowNull()][string]$EvidencePath = $null
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-JsonProperty {
    param([Parameter(Mandatory)][object]$Object, [Parameter(Mandatory)][string]$Name)

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Fixture-Eintrag fehlt: $Name" }
    return $property.Value
}

function New-ReplaySeed {
    param([Parameter(Mandatory)][object]$Definition, [Parameter(Mandatory)][datetime]$ObservedAt)

    $location = $Definition.location
    $targetLocation = New-JobAgentTargetLocation -Label ([string]$location.label) -City ([string]$location.city) -TargetArea ([string]$location.target_area)
    return New-JobAgentCompanySeed `
        -CanonicalName ([string]$Definition.canonical_name) `
        -OfficialWebsiteUrl ([string]$Definition.official_website_url) `
        -CareerUrl ([string]$Definition.career_url) `
        -Locations @($targetLocation) `
        -Industry ([string]$Definition.industry) `
        -ScanPriority ([int]$Definition.scan_priority) `
        -DiscoverySourceUrl ([string]$Definition.career_url) `
        -CreatedAt $ObservedAt `
        -NextScanAt $ObservedAt
}

function Invoke-ReplayPhase {
    param(
        [Parameter(Mandatory)][object]$Phase,
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string[]]$CompanyIds
    )

    $adapter = {
        param([object]$AdapterInput)

        $entry = Get-JsonProperty -Object $Phase -Name ([string]$AdapterInput.company.company_id)
        $completeEmpty = ($entry.PSObject.Properties.Name -contains 'complete_empty') -and [bool]$entry.complete_empty
        Invoke-JobAgentFixtureAdapter `
            -AdapterInput $AdapterInput `
            -FixtureJobs @($entry.raw_jobs) `
            -Status ([string]$entry.status) `
            -ErrorClass ([string]$entry.error_class) `
            -RetryRecommendation ([string]$entry.retry_recommendation) `
            -CompleteEmptyResult:$completeEmpty
    }

    return Invoke-JobAgentDailyRun -ProjectRoot $ProjectRoot -AdapterResolver $adapter -CompanyIds $CompanyIds -MaxCompanies $CompanyIds.Count -StartedAt $StartedAt
}

$fixture = Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json -Depth 20
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-ja044-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

try {
    $referenceTime = [datetime]::Parse([string]$fixture.reference_time, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $document = New-JobAgentEmptyDocument -GeneratedAt $referenceTime
    $alphaSeed = New-ReplaySeed -Definition $fixture.companies[0] -ObservedAt $referenceTime
    $knownResult = Add-JobAgentCompanySeedInventory -Document $document -Seeds @($alphaSeed) -SeededAt $referenceTime
    $document = $knownResult.document
    $newSeeds = @(
        (New-ReplaySeed -Definition $fixture.companies[1] -ObservedAt $referenceTime),
        (New-ReplaySeed -Definition $fixture.duplicate_candidate -ObservedAt $referenceTime),
        (New-ReplaySeed -Definition $fixture.companies[2] -ObservedAt $referenceTime)
    )
    $newResult = Add-JobAgentCompanySeedInventory -Document $document -Seeds $newSeeds -SeededAt $referenceTime
    $document = $newResult.document
    Write-JobAgentStore -ProjectRoot $temporaryRoot -Document $document | Out-Null

    $expectedCompanyIds = @($fixture.expected.company_ids | ForEach-Object { [string]$_ } | Sort-Object)
    $companyIds = @($document.companies | ForEach-Object { [string]$_.company_id } | Sort-Object)
    Assert-True -Condition (($companyIds -join '|') -eq ($expectedCompanyIds -join '|')) -Message 'Verifizierte neue Firma oder bekannte Firmenretention stimmt nicht.'
    Assert-True -Condition (@($newResult.deduplicated | Where-Object { [string]$_.company_id -eq 'company:beta_gmbh' }).Count -eq 1) -Message 'Doppelhinweis hat keine einzelne Beta-Firma ergeben.'

    $first = Invoke-ReplayPhase -Phase $fixture.phases.initial -StartedAt $referenceTime -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    Assert-True -Condition ($first.status -eq 'SUCCESS') -Message 'Initialer vollstaendiger Replay-Lauf ist nicht erfolgreich.'
    $firstExternalIds = @($first.document.jobs | ForEach-Object { [string]$_.external_job_id } | Sort-Object)
    $expectedExternalIds = @($fixture.expected.job_external_ids | ForEach-Object { [string]$_ } | Sort-Object)
    Assert-True -Condition (($firstExternalIds -join '|') -eq ($expectedExternalIds -join '|')) -Message 'Initialer Replay-Lauf erzeugt nicht die vorab definierten Stellen-IDs.'
    Assert-True -Condition (@($first.document.companies | Where-Object { [string]$_.company_id -eq 'company:gamma_gmbh' }).Count -eq 1) -Message 'Firma ohne offene Stellen wurde nicht erhalten.'

    $second = Invoke-ReplayPhase -Phase $fixture.phases.initial -StartedAt $referenceTime.AddHours(1) -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    $secondExternalIds = @($second.document.jobs | ForEach-Object { [string]$_.external_job_id } | Sort-Object)
    Assert-True -Condition (($secondExternalIds -join '|') -eq ($expectedExternalIds -join '|')) -Message 'Identischer Replay-Lauf erzeugt Dubletten oder verliert Stellen.'
    Assert-True -Condition (@($second.document.jobs | Where-Object { $_.status -eq 'REMOVED' }).Count -eq 0) -Message 'Identischer Replay-Lauf hat Stellen entfernt.'

    $timeout = Invoke-ReplayPhase -Phase $fixture.phases.timeout -StartedAt $referenceTime.AddHours(2) -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    $retainedId = [string]$fixture.expected.retained_after_failure_external_id
    Assert-True -Condition ($timeout.status -eq 'PARTIAL') -Message 'Timeout-Replay wird nicht als PARTIAL ausgewiesen.'
    Assert-True -Condition (@($timeout.document.jobs | Where-Object { [string]$_.external_job_id -eq $retainedId -and [string]$_.status -ne 'REMOVED' }).Count -eq 1) -Message 'Timeout hat eine zuvor bekannte Stelle faelschlich entfernt.'

    $completeEmpty = Invoke-ReplayPhase -Phase $fixture.phases.complete_empty_beta -StartedAt $referenceTime.AddHours(3) -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    $removedId = [string]$fixture.expected.removed_external_id
    Assert-True -Condition ($completeEmpty.status -eq 'SUCCESS') -Message 'Vollstaendiger Leerscan ist nicht erfolgreich.'
    Assert-True -Condition (@($completeEmpty.document.jobs | Where-Object { [string]$_.external_job_id -eq $removedId -and [string]$_.status -eq 'REMOVED' }).Count -eq 1) -Message 'Vollstaendiger Leerscan hat die fehlende Quellstelle nicht entfernt.'
    Assert-True -Condition (@($completeEmpty.document.change_events | Where-Object { [string]$_.event_type -eq 'JOB_REMOVED' -and [string]$_.job_id -eq (@($completeEmpty.document.jobs | Where-Object { [string]$_.external_job_id -eq $removedId })[0].job_id) }).Count -eq 1) -Message 'Vollstaendiger Leerscan protokolliert keine eindeutige REMOVED-Aenderung.'

    $partial = Invoke-ReplayPhase -Phase $fixture.phases.partial_alpha -StartedAt $referenceTime.AddHours(4) -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    Assert-True -Condition ($partial.status -eq 'PARTIAL') -Message 'Budgetabbruch-Replay wird nicht als PARTIAL ausgewiesen.'
    Assert-True -Condition (@($partial.document.jobs | Where-Object { [string]$_.external_job_id -eq $retainedId -and [string]$_.status -ne 'REMOVED' }).Count -eq 1) -Message 'Teilscan hat Alpha-Stelle faelschlich entfernt.'

    $restart = Invoke-ReplayPhase -Phase $fixture.phases.complete_empty_beta -StartedAt $referenceTime.AddHours(5) -ProjectRoot $temporaryRoot -CompanyIds $companyIds
    $finalDocument = $restart.document
    Assert-True -Condition (@($finalDocument.companies).Count -eq 3) -Message 'Restart hat eine Firma verloren oder dupliziert.'
    Assert-True -Condition (@($finalDocument.jobs | Where-Object { [string]$_.external_job_id -eq $retainedId }).Count -eq 1) -Message 'Restart erzeugt eine Alpha-Stellendublette.'
    Assert-True -Condition (@($finalDocument.scan_attempts | Where-Object { [string]$_.status -eq 'FAILED' -and [string]$_.error_class -eq 'TIMEOUT' }).Count -eq 1) -Message 'Timeout-Versuch wurde nicht getrennt persistiert.'

    $evidence = [ordered]@{
        schema_version = 'jobagent/ja-044-acquisition-replay/v1'
        fixture_path = [IO.Path]::GetFullPath($FixturePath)
        reference_time = $referenceTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        expected_company_ids = $expectedCompanyIds
        expected_job_external_ids = $expectedExternalIds
        phases = @(
            [ordered]@{ name = 'initial'; status = $first.status; jobs = $firstExternalIds },
            [ordered]@{ name = 'identical_replay'; status = $second.status; jobs = $secondExternalIds },
            [ordered]@{ name = 'timeout'; status = $timeout.status; retained_job_external_id = $retainedId },
            [ordered]@{ name = 'complete_empty_beta'; status = $completeEmpty.status; removed_job_external_id = $removedId },
            [ordered]@{ name = 'partial_alpha'; status = $partial.status; retained_job_external_id = $retainedId },
            [ordered]@{ name = 'restart'; status = $restart.status; companies_total = @($finalDocument.companies).Count }
        )
        final = [ordered]@{
            companies = @($finalDocument.companies | ForEach-Object { [string]$_.company_id } | Sort-Object)
            jobs = @($finalDocument.jobs | Sort-Object external_job_id | ForEach-Object { [ordered]@{ external_job_id = [string]$_.external_job_id; status = [string]$_.status; job_id = [string]$_.job_id } })
            timeout_attempts = @($finalDocument.scan_attempts | Where-Object { [string]$_.status -eq 'FAILED' -and [string]$_.error_class -eq 'TIMEOUT' }).Count
        }
    }
    $evidenceJson = $evidence | ConvertTo-Json -Depth 20
    $evidenceHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($evidenceJson))).ToLowerInvariant()
    $evidence.evidence_sha256 = $evidenceHash
    if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
        $resolvedEvidencePath = [IO.Path]::GetFullPath((Join-Path $root $EvidencePath))
        $evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
        New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
        [IO.File]::WriteAllText($resolvedEvidencePath, ($evidence | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        $evidence.evidence_path = $resolvedEvidencePath
    }

    [pscustomobject]@{
        status = 'ok'
        cases = @('verified_new_company_and_duplicate_hint', 'identical_replay_without_duplicates', 'complete_empty_source_removes_only_its_job', 'timeout_retains_job', 'partial_scan_retains_job', 'restart_preserves_company_and_job_identity')
        evidence = $evidence
    } | ConvertTo-Json -Depth 20
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
