#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-RegisterHint {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Number,
        [Parameter()][string]$City = 'Muenchen',
        [Parameter()][string]$Area = 'MUNICH',
        [Parameter()][string]$ObservedAt = '2026-08-23T08:00:00.000Z'
    )

    [pscustomobject]@{
        hint_id = 'register-hint:' + $Number
        register_name = $Name
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $Name
        register_city = $City
        register_court = 'Amtsgericht Muenchen'
        register_number = 'HRB ' + $Number
        source_id = 'source-registry:offeneregister_dump'
        target_area_match = $Area
        confidence_score = 88
        observed_at = $ObservedAt
        candidate_status = 'REGISTER_DISCOVERY_HINT'
        dedupe_keys = @(
            'name:' + (ConvertTo-JobAgentCompanyNameKey -Name $Name),
            'register:amtsgericht_muenchen_hrb_' + $Number
        )
    }
}

function New-JobBoardHint {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$HintId,
        [Parameter()][AllowNull()][string]$Domain = $null,
        [Parameter()][string]$Location = 'Muenchen',
        [Parameter()][bool]$Staffing = $false
    )

    [pscustomobject]@{
        hint_id = $HintId
        employer_name = $Name
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $Name
        job_location = $Location
        location = $Location
        target_area = if ($Location -eq 'Freising') { 'FREISING' } else { 'MUNICH' }
        source_id = 'source-registry:stepstone_muenchen'
        observed_at = '2026-08-23T09:00:00.000Z'
        confidence_score = 70
        candidate_status = 'DISCOVERY_HINT'
        known_company_domain = $Domain
        is_staffing_agency = $Staffing
    }
}

function New-RegionalHint {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$HintId,
        [Parameter()][string]$Area = 'FREISING'
    )

    [pscustomobject]@{
        hint_id = $HintId
        company_name = $Name
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $Name
        source_id = 'source-registry:landkreis_freising_wirtschaft'
        observed_at = '2026-08-23T10:00:00.000Z'
        priority_score = 84
        target_area = $Area
        candidate_status = 'REGIONAL_DISCOVERY_HINT'
        source_record_hash = ('a' * 64)
    }
}

$sameRegister = @(
    New-RegisterHint -Name 'Alpha Technik GmbH' -Number 1001
    New-RegisterHint -Name 'Alpha Technik AG' -Number 1001
)
$sameDomain = @(
    New-JobBoardHint -Name 'Beta Analytics AG' -HintId 'jobboard-hint:beta-1' -Domain 'beta.example.invalid'
    New-RegionalHint -Name 'Beta Analytics GmbH' -HintId 'regional-hint:beta-2'
    New-JobBoardHint -Name 'Beta Analytics SE' -HintId 'jobboard-hint:beta-3' -Domain 'https://www.beta.example.invalid/jobs'
)
$conflictingName = @(
    New-JobBoardHint -Name 'Gamma Services GmbH' -HintId 'jobboard-hint:gamma-staffing' -Domain 'gamma-staffing.example.invalid' -Staffing $true
    New-JobBoardHint -Name 'Gamma Services GmbH' -HintId 'jobboard-hint:gamma-operating' -Domain 'gamma-operating.example.invalid'
)
$uncertainRegional = New-RegionalHint -Name 'Unknown Place GmbH' -HintId 'regional-hint:unknown-place' -Area 'TARGET_AREA_UNCERTAIN'

$scaleCandidates = New-Object System.Collections.Generic.List[object]
foreach ($item in @($sameRegister + $sameDomain + $conflictingName + @($uncertainRegional))) {
    $scaleCandidates.Add($item)
}
for ($index = 1; $index -le 5000; $index++) {
    $area = if (($index % 5) -eq 0) { 'FREISING' } elseif (($index % 7) -eq 0) { 'MUNICH_20KM' } else { 'MUNICH' }
    $scaleCandidates.Add((New-RegisterHint -Name ('Scale Candidate {0:D4} GmbH' -f $index) -Number (200000 + $index) -Area $area))
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$report = Resolve-JobAgentCompanyCandidateClusters -Candidates $scaleCandidates.ToArray() -ObservedAt ([datetime]'2026-08-23T12:00:00Z')
$stopwatch.Stop()

Assert-True -Condition ($report.schema_version -eq 'jobagent/company-candidate-clusters/v1') -Message 'Cluster-Report hat falsche Schema-Version.'
Assert-True -Condition ($report.candidates_total -eq 5008) -Message 'Scale-Report zaehlt Kandidaten falsch.'
Assert-True -Condition ($report.clusters_total -eq 5006) -Message 'Starke Deduplikation erzeugt falsche Clusterzahl.'
Assert-True -Condition ($stopwatch.Elapsed.TotalSeconds -lt 10) -Message ('Scale-Dedupe ist zu langsam: {0:n2}s' -f $stopwatch.Elapsed.TotalSeconds)

$alpha = @($report.clusters | Where-Object { @($_.candidate_ids) -contains 'register-hint:1001' })[0]
Assert-True -Condition (@($alpha.candidate_ids).Count -eq 2) -Message 'Register-ID-Deduplikation fasst Varianten nicht zusammen.'
Assert-True -Condition (@($alpha.dedupe_keys | Where-Object { $_ -eq 'register:amtsgericht_muenchen_hrb_1001' }).Count -eq 1) -Message 'Register-Dedupe-Key fehlt.'
Assert-True -Condition (@($alpha.target_area_basis | Where-Object { $_ -eq 'REGISTER_SEAT_IN_TARGET' }).Count -eq 1) -Message 'Register-Standortbasis fehlt.'

$beta = @($report.clusters | Where-Object { @($_.dedupe_keys) -contains 'domain:beta.example.invalid' })[0]
Assert-True -Condition (@($beta.candidate_ids).Count -eq 2) -Message 'Domain-Deduplikation fasst Domainvarianten nicht zusammen.'
Assert-True -Condition (@($beta.target_area_basis | Where-Object { $_ -eq 'JOB_LOCATION_IN_TARGET' }).Count -eq 1) -Message 'Job-Standortbasis fehlt.'

$gammaClusters = @($report.clusters | Where-Object { [string]$_.canonical_name -eq 'Gamma Services GmbH' })
Assert-True -Condition ($gammaClusters.Count -eq 2) -Message 'Unterschiedliche Domains gleicher Namen duerfen nicht automatisch verschmolzen werden.'
Assert-True -Condition (@($gammaClusters | Where-Object { @($_.conflict_flags) -contains 'NAME_MATCH_WITHOUT_STRONG_IDENTITY' }).Count -eq 2) -Message 'Namenskonflikt ohne starke Identitaet wird nicht markiert.'
Assert-True -Condition (@($gammaClusters | Where-Object { @($_.conflict_flags) -contains 'STAFFING_AGENCY_REVIEW' }).Count -eq 1) -Message 'Personaldienstleister-Review wird nicht markiert.'

$uncertain = @($report.clusters | Where-Object { @($_.candidate_ids) -contains 'regional-hint:unknown-place' })[0]
Assert-True -Condition (@($uncertain.conflict_flags) -contains 'TARGET_AREA_UNCERTAIN') -Message 'Unsicheres Zielgebiet wird nicht als Konflikt markiert.'
Assert-True -Condition (@($uncertain.target_area_basis) -contains 'TARGET_UNCERTAIN') -Message 'Unsicheres Zielgebiet hat falsche Standortbasis.'
Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$uncertain.review_queue_reason)) -Message 'Review-Queue-Grund fehlt.'

$firstScale = @($report.clusters | Where-Object { @($_.candidate_ids) -contains 'register-hint:200001' })[0]
$secondRun = Resolve-JobAgentCompanyCandidateClusters -Candidates $scaleCandidates.ToArray() -ObservedAt ([datetime]'2026-08-23T12:00:00Z')
$firstScaleAgain = @($secondRun.clusters | Where-Object { @($_.candidate_ids) -contains 'register-hint:200001' })[0]
Assert-True -Condition ($firstScale.identity_cluster_id -eq $firstScaleAgain.identity_cluster_id) -Message 'Cluster-IDs sind nicht idempotent.'
Assert-True -Condition ($firstScale.source_count -eq 1) -Message 'Source-Count fuer Einzelkandidat falsch.'
Assert-True -Condition ($alpha.first_seen_at -eq '2026-08-23T08:00:00.000Z' -and $alpha.last_seen_at -eq '2026-08-23T08:00:00.000Z') -Message 'First-/Last-Seen fuer Registercluster falsch.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'register_identity_merge',
        'domain_identity_merge',
        'name_only_conflict_not_merged',
        'staffing_agency_review_flag',
        'target_area_basis_mapping',
        'target_uncertain_review_queue',
        'scale_5000_candidates',
        'idempotent_cluster_ids'
    )
    candidates = $report.candidates_total
    clusters = $report.clusters_total
    elapsed_ms = [int]$stopwatch.ElapsedMilliseconds
} | ConvertTo-Json -Depth 5
