#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$QueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCandidates = 25,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
    [Parameter()][string]$FixtureMapPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking
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

function Get-ToolCandidateId {
    param([Parameter(Mandatory)][object]$Candidate)

    foreach ($property in @('candidate_id', 'hint_id', 'company_id')) {
        if ($Candidate.PSObject.Properties.Name -contains $property -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$property)) {
            return [string]$Candidate.$property
        }
    }
    throw 'Kandidat enthaelt keine stabile ID.'
}

function New-ToolFixtureFetcher {
    param([Parameter(Mandatory)][string]$Path)

    $fixture = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    $map = @{}
    foreach ($entry in @($fixture.responses)) {
        $map[(ConvertTo-JobAgentCanonicalUrl -Url ([string]$entry.url))] = $entry
    }
    return {
        param([string]$Url, [object]$Policy)

        $key = ConvertTo-JobAgentCanonicalUrl -Url $Url
        if ($map.ContainsKey($key)) {
            $entry = $map[$key]
            return [pscustomobject]@{
                ok = [bool]$entry.ok
                url = $key
                final_url = if ([string]::IsNullOrWhiteSpace([string]$entry.final_url)) { $key } else { ConvertTo-JobAgentCanonicalUrl -Url ([string]$entry.final_url) }
                status_code = if ($null -eq $entry.status_code) { $null } else { [int]$entry.status_code }
                content = if ($null -eq $entry.content) { '' } else { [string]$entry.content }
                content_type = 'text/html'
                error = if ([bool]$entry.ok) { $null } else { 'fixture failure' }
            }
        }
        [pscustomobject]@{
            ok = $false
            url = $key
            final_url = $key
            status_code = 404
            content = ''
            content_type = 'text/html'
            error = 'fixture missing'
        }
    }.GetNewClosure()
}

function Add-ToolProperty {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Value
    )

    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function ConvertTo-ToolSourceEvidence {
    param(
        [Parameter(Mandatory)][object]$Entry,
        [Parameter(Mandatory)][object]$Candidate
    )

    $entryEvidence = if ($Entry.PSObject.Properties.Name -contains 'source_evidence') { $Entry.source_evidence } else { $null }
    [pscustomobject]@{
        source_id = if ($null -ne $entryEvidence) { [string]$entryEvidence.source_id } else { [string]$Candidate.source_id }
        source_class = if ($null -ne $entryEvidence) { [string]$entryEvidence.source_class } else { 'UNKNOWN' }
        evidence_level = if ($null -ne $entryEvidence) { [string]$entryEvidence.evidence_level } else { 'DISCOVERY_HINT' }
        observed_url = if ($null -ne $entryEvidence) { $entryEvidence.observed_url } elseif ($Candidate.PSObject.Properties.Name -contains 'observed_url') { $Candidate.observed_url } else { $null }
        observed_at = if ($null -ne $entryEvidence) { $entryEvidence.observed_at } elseif ($Candidate.PSObject.Properties.Name -contains 'observed_at') { $Candidate.observed_at } else { $null }
    }
}

function Update-ToolHintWithWebsiteDiscovery {
    param(
        [Parameter(Mandatory)][object]$Hint,
        [Parameter(Mandatory)][object]$Discovery
    )

    Add-ToolProperty -Object $Hint -Name 'official_website_url' -Value ([string]$Discovery.official_website_url)
    Add-ToolProperty -Object $Hint -Name 'verified_official_website_url' -Value ([string]$Discovery.official_website_url)
    Add-ToolProperty -Object $Hint -Name 'canonical_domain' -Value ([string]$Discovery.official_website_domain)
    Add-ToolProperty -Object $Hint -Name 'official_website_verification_status' -Value 'OFFICIAL_WEBSITE_VERIFIED'
    Add-ToolProperty -Object $Hint -Name 'company_domain_verification_status' -Value 'OFFICIAL_WEBSITE_VERIFIED'
    Add-ToolProperty -Object $Hint -Name 'official_website_evidence' -Value ([object[]]@($Discovery.evidence))
    Add-ToolProperty -Object $Hint -Name 'next_action' -Value 'verify_official_company_website_or_career_url'
}

function ConvertTo-ToolTextHash {
    param([Parameter()][AllowEmptyString()][string]$Text)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
    }
}

function ConvertTo-ToolPlainTextExcerpt {
    param(
        [Parameter()][AllowEmptyString()][string]$Html,
        [Parameter()][ValidateRange(1, 400)][int]$MaxLength = 160
    )

    $text = [regex]::Replace($Html, '<(script|style)\b.*?</\1>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $text = [regex]::Replace($text, '<[^>]+>', ' ')
    $text = [Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength)
    }
    return $text
}

function ConvertTo-ToolWebsiteDiscoveryLogResult {
    param([Parameter(Mandatory)][object]$Result)

    $evidenceItems = if ($Result.PSObject.Properties.Name -contains 'evidence') { @($Result.evidence) } else { @() }
    $fetchItems = if ($Result.PSObject.Properties.Name -contains 'fetches') { @($Result.fetches) } else { @() }
    $candidateItems = if ($Result.PSObject.Properties.Name -contains 'candidates') { @($Result.candidates) } else { @() }
    [pscustomobject]@{
        candidate_id = [string]$Result.candidate_id
        status = [string]$Result.status
        official_website_url = $Result.official_website_url
        official_website_domain = $Result.official_website_domain
        evidence = @($evidenceItems)
        fetches = @($fetchItems | ForEach-Object {
                $content = if ($_.PSObject.Properties.Name -contains 'content') { [string]$_.content } else { '' }
                [pscustomobject]@{
                    ok = [bool]$_.ok
                    url = [string]$_.url
                    final_url = if ($_.PSObject.Properties.Name -contains 'final_url') { [string]$_.final_url } else { [string]$_.url }
                    status_code = if ($_.PSObject.Properties.Name -contains 'status_code') { $_.status_code } else { $null }
                    content_type = if ($_.PSObject.Properties.Name -contains 'content_type') { [string]$_.content_type } else { '' }
                    content_hash = if ([string]::IsNullOrWhiteSpace($content)) { $null } else { ConvertTo-ToolTextHash -Text $content }
                    content_excerpt = if ([string]::IsNullOrWhiteSpace($content)) { '' } else { ConvertTo-ToolPlainTextExcerpt -Html $content -MaxLength 160 }
                    error = if ($_.PSObject.Properties.Name -contains 'error') { $_.error } else { $null }
                }
            })
        candidates = @($candidateItems)
        reason = [string]$Result.reason
        next_action = [string]$Result.next_action
    }
}

$startedAt = [datetime]::UtcNow
$hintStoreResolved = Resolve-ToolPath -Root $projectRootResolved -Path $HintStorePath
$sourceRegistryResolved = Resolve-ToolPath -Root $projectRootResolved -Path $SourceRegistryPath
$queueResolved = Resolve-ToolPath -Root $projectRootResolved -Path $QueuePath
if (-not (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf)) {
    throw "Discovery-Hint-Store fehlt: $hintStoreResolved"
}

$hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
$sourceRegistry = if (Test-Path -LiteralPath $sourceRegistryResolved -PathType Leaf) { Get-Content -Raw -LiteralPath $sourceRegistryResolved | ConvertFrom-Json -Depth 100 } else { $null }
$previousQueue = if (Test-Path -LiteralPath $queueResolved -PathType Leaf) { Get-Content -Raw -LiteralPath $queueResolved | ConvertFrom-Json -Depth 100 } else { $null }
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds $TimeoutSeconds
$fetcher = if ([string]::IsNullOrWhiteSpace($FixtureMapPath)) { $null } else { New-ToolFixtureFetcher -Path (Resolve-ToolPath -Root $projectRootResolved -Path $FixtureMapPath) }

$queue = New-JobAgentCoverageCandidateReviewQueue -HintStore $hintStore -SourceRegistry $sourceRegistry -PreviousQueue $previousQueue -Now $startedAt -MaxItems 1000
$candidateById = @{}
foreach ($candidate in @($hintStore.hints)) {
    $candidateById[(Get-ToolCandidateId -Candidate $candidate)] = $candidate
}

$targets = @($queue.queue |
    Where-Object { [string]$_.next_action -eq 'DISCOVER_OFFICIAL_WEBSITE' -and $candidateById.ContainsKey([string]$_.candidate_id) } |
    Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id |
    Select-Object -First $MaxCandidates)
$results = New-Object System.Collections.Generic.List[object]
foreach ($entry in $targets) {
    $candidate = $candidateById[[string]$entry.candidate_id]
    $sourceEvidence = ConvertTo-ToolSourceEvidence -Entry $entry -Candidate $candidate
    $discovery = Resolve-JobAgentCandidateOfficialWebsiteDiscovery -Candidate $candidate -SourceEvidence $sourceEvidence -Policy $policy -Fetcher $fetcher -ObservedAt $startedAt
    $results.Add($discovery)
    if ([string]$discovery.status -eq 'OFFICIAL_WEBSITE_VERIFIED') {
        Update-ToolHintWithWebsiteDiscovery -Hint $candidate -Discovery $discovery
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $hintStoreResolved) -Force | Out-Null
$hintStore.generated_at = ConvertTo-ToolIso -Value $startedAt
$hintStore | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $hintStoreResolved -Encoding UTF8
$updatedQueue = New-JobAgentCoverageCandidateReviewQueue -HintStore $hintStore -SourceRegistry $sourceRegistry -PreviousQueue $queue -Now $startedAt -MaxItems 1000
New-Item -ItemType Directory -Path (Split-Path -Parent $queueResolved) -Force | Out-Null
$updatedQueue | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $queueResolved -Encoding UTF8

$logRootPath = Resolve-ToolPath -Root $projectRootResolved -Path $LogRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$logPath = Join-Path $logRootPath ('company-candidate-website-discovery-' + $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$resultItems = @($results.ToArray())
$logResultItems = @($resultItems | ForEach-Object { ConvertTo-ToolWebsiteDiscoveryLogResult -Result $_ })
$summary = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-website-discovery/v1'
    ts = ConvertTo-ToolIso -Value $startedAt
    hint_store_path = $hintStoreResolved
    queue_path = $queueResolved
    log_path = $logPath
    processed_total = $resultItems.Count
    verified_total = @($resultItems | Where-Object { [string]$_.status -eq 'OFFICIAL_WEBSITE_VERIFIED' }).Count
    manual_review_total = @($resultItems | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count
    unverified_total = @($resultItems | Where-Object { [string]$_.status -eq 'UNVERIFIED' }).Count
    verified_candidate_ids = @($resultItems | Where-Object { [string]$_.status -eq 'OFFICIAL_WEBSITE_VERIFIED' } | ForEach-Object { [string]$_.candidate_id })
    results = @($logResultItems)
}
$summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 100
