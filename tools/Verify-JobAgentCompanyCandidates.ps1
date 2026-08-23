#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$QueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCandidates = 25,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
    [Parameter()][ValidateRange(1, 730)][int]$ExpiresAfterDays = 90,
    [Parameter()][ValidateRange(1, 20)][int]$MaxRetries = 3,
    [Parameter()][string]$FixtureMapPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-ToolIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-ToolDateOrNull {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    return [datetime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
}

function Get-ToolCandidateId {
    param([Parameter(Mandatory)][object]$Candidate)

    foreach ($property in @('candidate_id', 'hint_id', 'company_id')) {
        if ($Candidate.PSObject.Properties.Name -contains $property -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$property)) {
            return [string]$Candidate.$property
        }
    }
    throw 'Kandidat enthaelt keine stabile ID.'
}

function New-ToolCandidateSourceId {
    param(
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Status
    )

    $basis = if ($Status -eq 'OFFICIAL_ATS_VERIFIED') { 'official_ats' } else { 'career_url' }
    return 'source:' + (([string]$CompanyId).Substring(8) + '_' + $basis -replace '[^A-Za-z0-9_]+', '_').ToLowerInvariant()
}

function Get-ToolCandidateLocation {
    param([Parameter(Mandatory)][object]$Candidate)

    $label = foreach ($name in @('location', 'job_location', 'register_city', 'address_or_location_hint', 'region_reference')) {
        if ($Candidate.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$name)) {
            [string]$Candidate.$name
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = 'UNKNOWN'
    }
    $area = foreach ($name in @('target_area_match', 'target_area')) {
        if ($Candidate.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$name)) {
            [string]$Candidate.$name
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($area) -or @('TARGET_AREA_UNCERTAIN') -contains $area) {
        $area = 'UNKNOWN'
    }
    if (@('MUNICH', 'MUNICH_20KM', 'FREISING', 'REMOTE_WITH_TARGET_REFERENCE', 'UNKNOWN', 'OUT_OF_SCOPE') -notcontains $area) {
        $area = 'UNKNOWN'
    }
    $city = if ($label -match 'Freising') { 'Freising' } elseif ($label -match 'Muenchen|Munich|Garching|Unterfoehring|Ismaning|Taufkirchen|Neubiberg|Pullach|Gruenwald') { 'Muenchen' } else { 'UNKNOWN' }
    New-JobAgentTargetLocation -Label $label -City $city -TargetArea $area
}

function ConvertTo-ToolCompanyFromCandidateVerification {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    $company = $Verification.company.PSObject.Copy()
    $company.verification_status = [string]$Verification.status
    if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$Verification.status) {
        $company.career_url = [string]$Verification.career_url
    }
    $company.ats = if ($null -ne $Verification.ats) { @($Verification.ats) } else { @($company.ats) }
    $company.locations = if (@($company.locations).Count -gt 0) { @($company.locations) } else { @(Get-ToolCandidateLocation -Candidate $Candidate) }
    if ($company.PSObject.Properties.Name -contains 'updated_at') {
        $company.updated_at = ConvertTo-ToolIso -Value $ObservedAt
    }
    else {
        $company | Add-Member -NotePropertyName updated_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt)
    }
    if ($company.PSObject.Properties.Name -notcontains 'created_at') {
        $company | Add-Member -NotePropertyName created_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt)
    }
    if ($company.PSObject.Properties.Name -notcontains 'next_scan_at') {
        $company | Add-Member -NotePropertyName next_scan_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt.Date.AddDays(1))
    }
    if ($company.PSObject.Properties.Name -notcontains 'last_successful_scan_at') {
        $company | Add-Member -NotePropertyName last_successful_scan_at -NotePropertyValue $null
    }
    if ($company.PSObject.Properties.Name -notcontains 'discovery_source') {
        $observedUrl = if ($Candidate.PSObject.Properties.Name -contains 'observed_url') { [string]$Candidate.observed_url } elseif ($Candidate.PSObject.Properties.Name -contains 'source_page') { [string]$Candidate.source_page } else { [string]$company.official_website_url }
        $company | Add-Member -NotePropertyName discovery_source -NotePropertyValue (New-JobAgentDiscoverySource -Type 'DISCOVERY_HINT' -Url $observedUrl -ObservedAt $ObservedAt -VerificationUrl $Verification.evidence[0].verification_url -DiscoveryOrigin ([string]$Candidate.source_id) -TargetArea ([string](Get-ToolCandidateLocation -Candidate $Candidate).target_area) -IndustryHint 'UNKNOWN' -EvidenceNote 'Discovery-Kandidat wurde ueber offizielle Firmen-/Karrierequelle verifiziert.')
    }
    else {
        $company.discovery_source.verification_url = $Verification.evidence[0].verification_url
    }
    $company | Add-Member -NotePropertyName candidate_verification_evidence -NotePropertyValue @($Verification.evidence) -Force
    return $company
}

function New-ToolJobSourceFromCandidateVerification {
    param(
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    if ([string]::IsNullOrWhiteSpace([string]$Verification.career_url)) {
        return $null
    }
    $basis = if ([string]$Verification.status -eq 'OFFICIAL_ATS_VERIFIED') { 'COMPANY_LINKED_ATS' } else { 'CAREER_URL' }
    [pscustomobject]@{
        source_id = New-ToolCandidateSourceId -CompanyId ([string]$Verification.company_id) -Status ([string]$Verification.status)
        company_id = [string]$Verification.company_id
        source_type = if ([string]$Verification.status -eq 'OFFICIAL_ATS_VERIFIED') { 'OFFICIAL_ATS' } else { 'CAREER_PAGE' }
        url = [string]$Verification.career_url
        canonical_url = ConvertTo-JobAgentCanonicalUrl -Url ([string]$Verification.career_url)
        is_official = $true
        verified_at = ConvertTo-ToolIso -Value $ObservedAt
        verification_basis = $basis
        verification_evidence = @($Verification.evidence | ForEach-Object {
                [pscustomobject]@{
                    status = 'VERIFIED'
                    evidence_type = [string]$_.evidence_type
                    url = [string]$_.verification_url
                    basis_url = $_.verified_by_url
                    redirect_chain = @($_.redirect_chain)
                    observed_at = [string]$_.observed_at
                    reason = [string]$_.reason
                }
            })
    }
}

function New-ToolFixtureFetcher {
    param([Parameter(Mandatory)][string]$Path)

    $fixture = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    $map = @{}
    foreach ($entry in @($fixture.responses)) {
        $map[[string]$entry.url] = $entry
    }
    return {
        param([string]$Url, [object]$Policy)

        if ($map.ContainsKey($Url)) {
            $entry = $map[$Url]
            return [pscustomobject]@{
                ok = [bool]$entry.ok
                url = $Url
                final_url = if ([string]::IsNullOrWhiteSpace([string]$entry.final_url)) { $Url } else { [string]$entry.final_url }
                status_code = if ($null -eq $entry.status_code) { $null } else { [int]$entry.status_code }
                content = if ($null -eq $entry.content) { '' } else { [string]$entry.content }
                content_type = 'text/html'
                error = if ([bool]$entry.ok) { $null } else { 'fixture failure' }
            }
        }
        [pscustomobject]@{
            ok = $false
            url = $Url
            final_url = $Url
            status_code = 404
            content = ''
            content_type = 'text/html'
            error = 'fixture missing'
        }
    }.GetNewClosure()
}

function Read-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][datetime]$Now
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    }
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        generated_at = ConvertTo-ToolIso -Value $Now
        queue = @()
    }
}

function New-ToolQueueEntry {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$Cluster,
        [Parameter()][AllowNull()][object]$Previous,
        [Parameter(Mandatory)][datetime]$Now
    )

    $candidateId = Get-ToolCandidateId -Candidate $Candidate
    $previousRetryCount = if ($null -eq $Previous) { 0 } else { [int]$Previous.retry_count }
    $previousNextAttemptAt = if ($null -eq $Previous) { $Now } else { ConvertTo-ToolDateOrNull -Value $Previous.next_attempt_at }
    $previousLastAttemptAt = if ($null -eq $Previous) { $null } else { ConvertTo-ToolDateOrNull -Value $Previous.last_attempt_at }
    $previousStatus = if ($null -eq $Previous) { 'PENDING' } else { [string]$Previous.status }
    $priority = if ($Candidate.PSObject.Properties.Name -contains 'confidence_score') { [int]$Candidate.confidence_score } elseif ($Candidate.PSObject.Properties.Name -contains 'priority_score') { [int]$Candidate.priority_score } else { 50 }

    [pscustomobject]@{
        identity_cluster_id = [string]$Cluster.identity_cluster_id
        candidate_id = $candidateId
        candidate_ids = @($Cluster.candidate_ids)
        canonical_name = [string]$Cluster.canonical_name
        source_count = [int]$Cluster.source_count
        priority_score = $priority + ([int]$Cluster.source_count * 5)
        target_area_basis = @($Cluster.target_area_basis)
        status = $previousStatus
        review_reason = [string]$Cluster.review_queue_reason
        retry_count = $previousRetryCount
        last_attempt_at = if ($null -eq $previousLastAttemptAt) { $null } else { ConvertTo-ToolIso -Value $previousLastAttemptAt }
        next_attempt_at = if ($null -eq $previousNextAttemptAt) { ConvertTo-ToolIso -Value $Now } else { ConvertTo-ToolIso -Value $previousNextAttemptAt }
        last_status = if ($null -eq $Previous -or $Previous.PSObject.Properties.Name -notcontains 'last_status') { $null } else { [string]$Previous.last_status }
        last_reason = if ($null -eq $Previous -or $Previous.PSObject.Properties.Name -notcontains 'last_reason') { $null } else { [string]$Previous.last_reason }
    }
}

function New-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)][object]$PreviousQueue,
        [Parameter(Mandatory)][datetime]$Now
    )

    $previousByCandidate = @{}
    foreach ($entry in @($PreviousQueue.queue)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.candidate_id)) {
            $previousByCandidate[[string]$entry.candidate_id] = $entry
        }
    }
    $clusterReport = Resolve-JobAgentCompanyCandidateClusters -Candidates $Candidates -ObservedAt $Now
    $clusterByCandidate = @{}
    foreach ($cluster in @($clusterReport.clusters)) {
        foreach ($candidateId in @($cluster.candidate_ids)) {
            $clusterByCandidate[[string]$candidateId] = $cluster
        }
    }

    $entries = foreach ($candidate in @($Candidates)) {
        $candidateId = Get-ToolCandidateId -Candidate $candidate
        $previous = if ($previousByCandidate.ContainsKey($candidateId)) { $previousByCandidate[$candidateId] } else { $null }
        New-ToolQueueEntry -Candidate $candidate -Cluster $clusterByCandidate[$candidateId] -Previous $previous -Now $Now
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        generated_at = ConvertTo-ToolIso -Value $Now
        clusters_total = [int]$clusterReport.clusters_total
        candidates_total = @($Candidates).Count
        ready_total = @($entries | Where-Object { (ConvertTo-ToolDateOrNull -Value $_.next_attempt_at) -le $Now.ToUniversalTime() -and [string]$_.status -notin @('VERIFIED', 'MANUAL_REVIEW_REQUIRED', 'RETRY_EXHAUSTED') }).Count
        queue = @($entries | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id)
    }
}

function Update-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][object]$Queue,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter(Mandatory)][int]$MaxRetries
    )

    $resultsByCandidate = @{}
    foreach ($result in @($Results)) {
        $resultsByCandidate[[string]$result.candidate_id] = $result
    }
    $updated = foreach ($entry in @($Queue.queue)) {
        if (-not $resultsByCandidate.ContainsKey([string]$entry.candidate_id)) {
            $entry
            continue
        }
        $result = $resultsByCandidate[[string]$entry.candidate_id]
        $status = [string]$result.status
        $isVerified = @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains $status
        $retryCount = [int]$entry.retry_count
        $nextAttemptAt = $null
        $queueStatus = if ($isVerified) {
            'VERIFIED'
        }
        elseif ($status -eq 'MANUAL_REVIEW_REQUIRED') {
            'MANUAL_REVIEW_REQUIRED'
        }
        else {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                'RETRY_EXHAUSTED'
            }
            else {
                $nextAttemptAt = $Now.ToUniversalTime().AddHours([Math]::Min([double]168, [double](24 * [Math]::Pow(2, ($retryCount - 1)))))
                'RETRY_SCHEDULED'
            }
        }
        [pscustomobject]@{
            identity_cluster_id = [string]$entry.identity_cluster_id
            candidate_id = [string]$entry.candidate_id
            candidate_ids = @($entry.candidate_ids)
            canonical_name = [string]$entry.canonical_name
            source_count = [int]$entry.source_count
            priority_score = [int]$entry.priority_score
            target_area_basis = @($entry.target_area_basis)
            status = $queueStatus
            review_reason = if (@($result.review_reasons).Count -gt 0) { (@($result.review_reasons) -join ',') } elseif ($queueStatus -eq 'RETRY_EXHAUSTED') { 'RETRY_EXHAUSTED' } else { [string]$entry.review_reason }
            retry_count = $retryCount
            last_attempt_at = ConvertTo-ToolIso -Value $Now
            next_attempt_at = if ($null -eq $nextAttemptAt) { $null } else { ConvertTo-ToolIso -Value $nextAttemptAt }
            last_status = $status
            last_reason = if (@($result.evidence).Count -gt 0) { [string]$result.evidence[0].reason } else { [string]$result.next_action }
        }
    }

    $Queue.queue = @($updated | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id)
    $Queue.generated_at = ConvertTo-ToolIso -Value $Now
    $Queue.ready_total = @($Queue.queue | Where-Object { (ConvertTo-ToolDateOrNull -Value $_.next_attempt_at) -le $Now.ToUniversalTime() -and [string]$_.status -notin @('VERIFIED', 'MANUAL_REVIEW_REQUIRED', 'RETRY_EXHAUSTED') }).Count
    return $Queue
}

$startedAt = [datetime]::UtcNow
$hintStoreResolved = Resolve-ToolPath -Root $projectRootResolved -Path $HintStorePath
$queueResolved = Resolve-ToolPath -Root $projectRootResolved -Path $QueuePath
if (-not (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf)) {
    throw "Discovery-Hint-Store fehlt: $hintStoreResolved"
}

$hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds $TimeoutSeconds
$fetcher = if ([string]::IsNullOrWhiteSpace($FixtureMapPath)) { $null } else { New-ToolFixtureFetcher -Path (Resolve-ToolPath -Root $projectRootResolved -Path $FixtureMapPath) }

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRootResolved -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot
    $results = New-Object System.Collections.Generic.List[object]
    $previousQueue = Read-ToolCandidateVerificationQueue -Path $queueResolved -Now $startedAt
    $queue = New-ToolCandidateVerificationQueue -Candidates @($hintStore.hints) -PreviousQueue $previousQueue -Now $startedAt
    $candidateById = @{}
    foreach ($candidate in @($hintStore.hints)) {
        $candidateById[(Get-ToolCandidateId -Candidate $candidate)] = $candidate
    }
    $targetCandidates = @($queue.queue |
        Where-Object { (ConvertTo-ToolDateOrNull -Value $_.next_attempt_at) -le $startedAt.ToUniversalTime() -and [string]$_.status -notin @('VERIFIED', 'MANUAL_REVIEW_REQUIRED', 'RETRY_EXHAUSTED') } |
        Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id |
        ForEach-Object { $candidateById[[string]$_.candidate_id] } |
        Select-Object -First $MaxCandidates)

    foreach ($candidate in $targetCandidates) {
        $verification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($document.companies) -Policy $policy -Fetcher $fetcher -ObservedAt $startedAt -ExpiresAfterDays $ExpiresAfterDays
        $results.Add($verification)
        if (@('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$verification.status) {
            $company = ConvertTo-ToolCompanyFromCandidateVerification -Candidate $candidate -Verification $verification -ObservedAt $startedAt
            $document = Upsert-JobAgentCompany -Document $document -Company $company
            if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$verification.status) {
                $source = New-ToolJobSourceFromCandidateVerification -Verification $verification -ObservedAt $startedAt
                if ($null -ne $source) {
                    $document = Upsert-JobAgentJobSource -Document $document -JobSource $source
                }
            }
        }
    }
    $queue = Update-ToolCandidateVerificationQueue -Queue $queue -Results @($results.ToArray()) -Now $startedAt -MaxRetries $MaxRetries
    New-Item -ItemType Directory -Path (Split-Path -Parent $queueResolved) -Force | Out-Null
    $queue | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $queueResolved -Encoding UTF8
    $storePath = Write-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot -Document $document -CreateBackup
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$logRootPath = Resolve-ToolPath -Root $projectRootResolved -Path $LogRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$logPath = Join-Path $logRootPath ('company-candidate-verification-' + $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$resultItems = @($results.ToArray())
$queueItems = @($queue.queue)
$checkedCandidateIds = @($resultItems | ForEach-Object { [string]$_.candidate_id })
$verifiedCandidateIds = @($resultItems | Where-Object { @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$_.status } | ForEach-Object { [string]$_.candidate_id })
$manualReviewCandidateIds = @($resultItems | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' } | ForEach-Object { [string]$_.candidate_id })
$unverifiedCandidateIds = @($resultItems | Where-Object { [string]$_.status -eq 'UNVERIFIED' } | ForEach-Object { [string]$_.candidate_id })
$summary = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-verification/v1'
    ts = ConvertTo-ToolIso -Value $startedAt
    store_path = $storePath
    hint_store_path = $hintStoreResolved
    queue_path = $queueResolved
    policy = $policy
    verification_queue = [pscustomobject]@{
        clusters_total = [int]$queue.clusters_total
        candidates_total = [int]$queue.candidates_total
        ready_total = [int]$queue.ready_total
        processed_total = $resultItems.Count
        retry_scheduled_total = @($queueItems | Where-Object { [string]$_.status -eq 'RETRY_SCHEDULED' }).Count
        manual_review_total = @($queueItems | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count
        verified_total = @($queueItems | Where-Object { [string]$_.status -eq 'VERIFIED' }).Count
    }
    checked_candidate_ids = $checkedCandidateIds
    verified_candidate_ids = $verifiedCandidateIds
    manual_review_candidate_ids = $manualReviewCandidateIds
    unverified_candidate_ids = $unverifiedCandidateIds
    results = $resultItems
}
$summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 100
