#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter(Mandatory)][string]$SnapshotPath,
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$OutputPath = 'data/jobagent/company-discovery.jobboards.json',
    [Parameter()][string]$MergedHintsPath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.JobBoardDiscovery.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Write-JobAgentJobBoardAtomicFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($tempPath, $Content + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function Get-JobAgentJobBoardHintProperty {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object -or $Object.PSObject.Properties.Name -notcontains $Name) {
        return $Default
    }
    return $Object.$Name
}

$resolvedSnapshot = if ([IO.Path]::IsPathRooted($SnapshotPath)) { $SnapshotPath } else { Join-Path $projectRoot $SnapshotPath }
$resolvedRegistry = if ([IO.Path]::IsPathRooted($SourceRegistryPath)) { $SourceRegistryPath } else { Join-Path $projectRoot $SourceRegistryPath }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$resolvedMergedHints = if ([IO.Path]::IsPathRooted($MergedHintsPath)) { $MergedHintsPath } else { Join-Path $projectRoot $MergedHintsPath }
$resolvedLogRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }

foreach ($path in @($resolvedSnapshot, $resolvedRegistry)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Pflichtdatei fehlt: $path"
    }
}

$registry = Get-Content -LiteralPath $resolvedRegistry -Raw | ConvertFrom-Json -Depth 100
Assert-JobAgentDiscoverySourceRegistry -Registry $registry
$document = Read-JobAgentStore -ProjectRoot $projectRoot
$result = Import-JobAgentJobBoardEmployers -SnapshotPath $resolvedSnapshot -SourceRegistry $registry -KnownCompanies @($document.companies)

Write-JobAgentJobBoardAtomicFile -Path $resolvedOutput -Content ($result | ConvertTo-Json -Depth 100)

$existingHintStore = if (Test-Path -LiteralPath $resolvedMergedHints -PathType Leaf) {
    Get-Content -LiteralPath $resolvedMergedHints -Raw | ConvertFrom-Json -Depth 100
}
else {
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
        search_matrix_count = 0
        hints_total = 0
        known_company_hints = 0
        unverified_hints = 0
        source_counts = [pscustomobject]@{}
        hints = @()
    }
}

$mergedById = [ordered]@{}
foreach ($hint in @($existingHintStore.hints)) {
    $hintId = [string](Get-JobAgentJobBoardHintProperty -Object $hint -Name 'hint_id' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($hintId)) {
        $mergedById[$hintId] = $hint
    }
}
foreach ($hint in @($result.hints)) {
    $mergedById[[string]$hint.hint_id] = $hint
}

$mergedHints = @($mergedById.Values | Sort-Object hint_id)
$sourceCounts = [ordered]@{}
foreach ($hint in $mergedHints) {
    $sourceIdValue = [string](Get-JobAgentJobBoardHintProperty -Object $hint -Name 'source_id' -Default 'UNKNOWN')
    if (-not $sourceCounts.Contains($sourceIdValue)) {
        $sourceCounts[$sourceIdValue] = 0
    }
    $sourceCounts[$sourceIdValue]++
}

$mergedStore = [pscustomobject]@{
    schema_version = 'jobagent/company-discovery-hints/v1'
    generated_at = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
    search_matrix_count = [int](Get-JobAgentJobBoardHintProperty -Object $existingHintStore -Name 'search_matrix_count' -Default 0)
    hints_total = $mergedHints.Count
    known_company_hints = @($mergedHints | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-JobAgentJobBoardHintProperty -Object $_ -Name 'known_company_id')) }).Count
    unverified_hints = @($mergedHints | Where-Object { [string](Get-JobAgentJobBoardHintProperty -Object $_ -Name 'verification_status' -Default 'UNVERIFIED') -eq 'UNVERIFIED' -or [bool](Get-JobAgentJobBoardHintProperty -Object $_ -Name 'official_verification_required' -Default $false) }).Count
    source_counts = [pscustomobject]$sourceCounts
    hints = $mergedHints
}
Write-JobAgentJobBoardAtomicFile -Path $resolvedMergedHints -Content ($mergedStore | ConvertTo-Json -Depth 100)

New-Item -ItemType Directory -Path $resolvedLogRoot -Force | Out-Null
$logPath = Join-Path $resolvedLogRoot ('company-discovery-jobboards-import-' + [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    status = 'ok'
    ts = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    snapshot_path = $resolvedSnapshot
    output_path = $resolvedOutput
    merged_hints_path = $resolvedMergedHints
    log_path = $logPath
    source_id = [string]$result.source_id
    platform = [string]$result.platform
    pages_read = [int]$result.pages_read
    records_read = [int]$result.records_read
    hints_total = [int]$result.hints_total
    staffing_agency_hints = [int]$result.staffing_agency_hints
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 20
