#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxReviewItems = 50
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $repoRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

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

function ConvertTo-ToolMarkdownText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'UNKNOWN'
    }
    return (([string]$Value).Trim() -replace '\|', '\|' -replace "`r?`n", ' ')
}

function ConvertTo-ToolClusterMarkdown {
    param(
        [Parameter(Mandatory)][object]$Report,
        [Parameter(Mandatory)][int]$MaxReviewItems
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('# JobAgent Kandidaten-Dedupe-Report')
    [void]$lines.Add('')
    [void]$lines.Add("- Generiert: $($Report.generated_at)")
    [void]$lines.Add("- Kandidaten: $($Report.candidates_total)")
    [void]$lines.Add("- Cluster: $($Report.clusters_total)")
    [void]$lines.Add("- Konfliktcluster: $($Report.conflict_clusters)")
    [void]$lines.Add("- Review-Queue: $($Report.review_queue_total)")
    [void]$lines.Add("- Laufzeit ms: $($Report.performance_ms)")
    [void]$lines.Add('')
    [void]$lines.Add('## Review-Queue')
    [void]$lines.Add('| Cluster | Firma | Grund | Kandidaten | Dedupe-Keys |')
    [void]$lines.Add('|---|---|---|---:|---|')
    foreach ($cluster in @($Report.clusters | Where-Object { [string]$_.review_queue_reason -ne 'READY_FOR_OFFICIAL_VERIFICATION' } | Select-Object -First $MaxReviewItems)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f
                (ConvertTo-ToolMarkdownText $cluster.identity_cluster_id),
                (ConvertTo-ToolMarkdownText $cluster.canonical_name),
                (ConvertTo-ToolMarkdownText $cluster.review_queue_reason),
                @($cluster.candidate_ids).Count,
                (ConvertTo-ToolMarkdownText (@($cluster.dedupe_keys) -join ', '))))
    }
    return ($lines.ToArray() -join "`n")
}

function Add-ToolClusterFieldsToHint {
    param(
        [Parameter(Mandatory)][object]$Hint,
        [Parameter(Mandatory)][object]$Cluster
    )

    $copy = [ordered]@{}
    foreach ($property in @($Hint.PSObject.Properties)) {
        $copy[$property.Name] = $property.Value
    }
    $copy.identity_cluster_id = [string]$Cluster.identity_cluster_id
    $copy.cluster_candidate_ids = @($Cluster.candidate_ids)
    $copy.cluster_dedupe_keys = @($Cluster.dedupe_keys)
    $copy.conflict_flags = @($Cluster.conflict_flags)
    $copy.target_area_basis = @($Cluster.target_area_basis)
    $copy.source_count = [int]$Cluster.source_count
    $copy.first_seen_at = [string]$Cluster.first_seen_at
    $copy.last_seen_at = [string]$Cluster.last_seen_at
    $copy.review_queue_reason = [string]$Cluster.review_queue_reason
    return [pscustomobject]$copy
}

$hintStoreResolved = Resolve-ToolPath -Root $projectRoot -Path $HintStorePath
if (-not (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf)) {
    throw "Discovery-Hint-Store fehlt: $hintStoreResolved"
}

$hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
$generatedAt = [datetime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$clusterReport = Resolve-JobAgentCompanyCandidateClusters -Candidates @($hintStore.hints) -ObservedAt $generatedAt
$stopwatch.Stop()
$clusterReport | Add-Member -NotePropertyName performance_ms -NotePropertyValue ([int]$stopwatch.ElapsedMilliseconds)

$clusterByCandidateId = @{}
foreach ($cluster in @($clusterReport.clusters)) {
    foreach ($candidateId in @($cluster.candidate_ids)) {
        $clusterByCandidateId[[string]$candidateId] = $cluster
    }
}
$enrichedHints = foreach ($hint in @($hintStore.hints)) {
    $candidateId = if ($hint.PSObject.Properties.Name -contains 'hint_id') { [string]$hint.hint_id } else { [string]$hint.candidate_id }
    if ($clusterByCandidateId.ContainsKey($candidateId)) {
        Add-ToolClusterFieldsToHint -Hint $hint -Cluster $clusterByCandidateId[$candidateId]
    }
}

$logRootPath = Resolve-ToolPath -Root $projectRoot -Path $LogRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$stamp = $generatedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
$jsonPath = Join-Path $logRootPath "company-candidate-dedupe-$stamp.json"
$markdownPath = Join-Path $logRootPath "company-candidate-dedupe-$stamp.md"
$enrichedHintsPath = Join-Path $logRootPath "company-discovery-hints-clustered-$stamp.json"

$clusterReport | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
ConvertTo-ToolClusterMarkdown -Report $clusterReport -MaxReviewItems $MaxReviewItems | Set-Content -LiteralPath $markdownPath -Encoding UTF8
[pscustomobject]@{
    schema_version = 'jobagent/company-discovery-hints-clustered/v1'
    generated_at = $clusterReport.generated_at
    source_hint_store = $hintStoreResolved
    hints_total = @($enrichedHints).Count
    hints = @($enrichedHints)
} | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $enrichedHintsPath -Encoding UTF8

[pscustomobject]@{
    status = 'ok'
    generated_at = $clusterReport.generated_at
    json_path = $jsonPath
    markdown_path = $markdownPath
    enriched_hints_path = $enrichedHintsPath
    candidates_total = $clusterReport.candidates_total
    clusters_total = $clusterReport.clusters_total
    conflict_clusters = $clusterReport.conflict_clusters
    review_queue_total = $clusterReport.review_queue_total
    performance_ms = $clusterReport.performance_ms
} | ConvertTo-Json -Depth 6
