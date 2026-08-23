#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$OutputPath = 'data/jobagent/company-discovery.register.json',
    [Parameter()][string]$MergedHintsPath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][string]$SourceId = 'source-registry:offeneregister_dump',
    [Parameter()][string]$SnapshotId = '',
    [Parameter(Mandatory)][datetime]$SnapshotDate
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)
Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.RegisterDiscovery.psm1') -Force -DisableNameChecking

function Write-JobAgentRegisterAtomicFile {
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

function Get-JobAgentRegisterHintProperty {
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

$resolvedInput = if ([IO.Path]::IsPathRooted($InputPath)) { $InputPath } else { Join-Path $projectRoot $InputPath }
$resolvedRegistry = if ([IO.Path]::IsPathRooted($SourceRegistryPath)) { $SourceRegistryPath } else { Join-Path $projectRoot $SourceRegistryPath }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$resolvedMergedHints = if ([IO.Path]::IsPathRooted($MergedHintsPath)) { $MergedHintsPath } else { Join-Path $projectRoot $MergedHintsPath }
foreach ($path in @($resolvedInput, $resolvedRegistry)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Pflichtdatei fehlt: $path"
    }
}

$observedAt = [datetime]::UtcNow
$snapshot = if ([string]::IsNullOrWhiteSpace($SnapshotId)) { [IO.Path]::GetFileNameWithoutExtension($resolvedInput) } else { $SnapshotId }
$registry = Get-Content -LiteralPath $resolvedRegistry -Raw | ConvertFrom-Json -Depth 100
$result = Import-JobAgentRegisterCandidates -InputPath $resolvedInput -SourceRegistry $registry -SourceId $SourceId -SnapshotId $snapshot -SnapshotDate $SnapshotDate -ObservedAt $observedAt

$outputDirectory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
Write-JobAgentRegisterAtomicFile -Path $resolvedOutput -Content ($result | ConvertTo-Json -Depth 100)

$existingHintStore = if (Test-Path -LiteralPath $resolvedMergedHints -PathType Leaf) {
    Get-Content -LiteralPath $resolvedMergedHints -Raw | ConvertFrom-Json -Depth 100
}
else {
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = $observedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
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
    if (-not [string]::IsNullOrWhiteSpace([string]$hint.hint_id)) {
        $mergedById[[string]$hint.hint_id] = $hint
    }
}
foreach ($hint in @($result.hints)) {
    $mergedById[[string]$hint.hint_id] = $hint
}
$mergedHints = @($mergedById.Values | Sort-Object hint_id)
$sourceCounts = [ordered]@{}
foreach ($hint in $mergedHints) {
    $sourceIdValue = [string]$hint.source_id
    if (-not $sourceCounts.Contains($sourceIdValue)) {
        $sourceCounts[$sourceIdValue] = 0
    }
    $sourceCounts[$sourceIdValue]++
}
$mergedStore = [pscustomobject]@{
    schema_version = 'jobagent/company-discovery-hints/v1'
    generated_at = $observedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
    search_matrix_count = [int]($existingHintStore.search_matrix_count)
    hints_total = $mergedHints.Count
    known_company_hints = @($mergedHints | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-JobAgentRegisterHintProperty -Object $_ -Name 'known_company_id')) }).Count
    unverified_hints = @($mergedHints | Where-Object { [string](Get-JobAgentRegisterHintProperty -Object $_ -Name 'verification_status' -Default 'UNVERIFIED') -eq 'UNVERIFIED' -or [bool](Get-JobAgentRegisterHintProperty -Object $_ -Name 'official_verification_required' -Default $false) }).Count
    source_counts = [pscustomobject]$sourceCounts
    hints = $mergedHints
}
Write-JobAgentRegisterAtomicFile -Path $resolvedMergedHints -Content ($mergedStore | ConvertTo-Json -Depth 100)

$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$logPath = Join-Path $logPathRoot ('company-discovery-register-import-' + $observedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    status = 'ok'
    ts = $observedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    input_path = $resolvedInput
    output_path = $resolvedOutput
    merged_hints_path = $resolvedMergedHints
    source_id = $SourceId
    snapshot_id = $snapshot
    records_read = [int]$result.records_read
    hints_total = [int]$result.hints_total
    reject_counts = $result.reject_counts
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 20
