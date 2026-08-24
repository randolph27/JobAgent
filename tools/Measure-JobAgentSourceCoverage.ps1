#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7,
    [Parameter()][switch]$Markdown
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $repoRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

function Resolve-SourceToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-SourceMetricRow {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][object]$Value
    )

    '| {0} | {1} |' -f ($Label -replace '\|', '\|'), $Value
}

$sourceRegistry = $null
$sourceRegistryResolved = Resolve-SourceToolPath -Root $projectRoot -Path $SourceRegistryPath
if (Test-Path -LiteralPath $sourceRegistryResolved -PathType Leaf) {
    $sourceRegistry = Get-Content -Raw -LiteralPath $sourceRegistryResolved | ConvertFrom-Json -Depth 100
}

$hintStore = $null
$hintStoreResolved = Resolve-SourceToolPath -Root $projectRoot -Path $HintStorePath
if (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf) {
    $hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
}

$document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$generatedAt = [datetime]::UtcNow
$inventory = New-JobAgentSourceInventoryReport -Document $document -SourceRegistry $sourceRegistry -HintStore $hintStore -Now $generatedAt -StaleAfterDays $StaleAfterDays

if ($Markdown) {
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('# JobAgent Quellenbestand')
    [void]$lines.Add('')
    [void]$lines.Add("- Generiert: $($inventory.generated_at)")
    [void]$lines.Add("- Letzter ScanRun: $($inventory.latest_scan_run_id)")
    [void]$lines.Add('')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Quellen gesamt' -Value $inventory.sources_total))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Offizielle Quellen' -Value $inventory.official_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Karrierequellen' -Value $inventory.career_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'ATS-Quellen' -Value $inventory.ats_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Discovery-Hinweise' -Value $inventory.discovery_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Verifizierte Quellen' -Value $inventory.verified_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Offene Quellen' -Value $inventory.unverified_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Blockierte Quellen' -Value $inventory.blocked_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Retry offen' -Value $inventory.retry_open_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Im letzten Lauf versucht' -Value $inventory.attempted_latest_run))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Im letzten Lauf gescannt' -Value $inventory.scan_succeeded_latest_run))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Im letzten Lauf fehlgeschlagen' -Value $inventory.scan_failed_latest_run))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Nie gescannte Quellen' -Value $inventory.never_scanned_sources))
    [void]$lines.Add((ConvertTo-SourceMetricRow -Label 'Faellige Quellen' -Value $inventory.stale_sources))
    $lines.ToArray() -join "`n"
    return
}

[pscustomobject]@{
    status = 'ok'
    generated_at = $inventory.generated_at
    latest_scan_run_id = $inventory.latest_scan_run_id
    sources_total = $inventory.sources_total
    official_sources = $inventory.official_sources
    career_sources = $inventory.career_sources
    ats_sources = $inventory.ats_sources
    discovery_sources = $inventory.discovery_sources
    discovery_hints = $inventory.discovery_hints
    verified_sources = $inventory.verified_sources
    unverified_sources = $inventory.unverified_sources
    blocked_sources = $inventory.blocked_sources
    retry_open_sources = $inventory.retry_open_sources
    attempted_latest_run = $inventory.attempted_latest_run
    scan_succeeded_latest_run = $inventory.scan_succeeded_latest_run
    scan_failed_latest_run = $inventory.scan_failed_latest_run
    never_scanned_sources = $inventory.never_scanned_sources
    stale_sources = $inventory.stale_sources
    duplicate_url_groups = $inventory.duplicate_url_groups
    by_group = $inventory.by_group
    by_type = $inventory.by_type
} | ConvertTo-Json -Depth 20
