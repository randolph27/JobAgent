#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$SnapshotManifestPath = 'data/jobagent/company-discovery.snapshot.json',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$QueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$RefillStatePath = 'data/jobagent/company-discovery.refill.state.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 25)][int]$MaxSources = 1,
    [Parameter()][switch]$Force
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

function Resolve-RefillPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-RefillIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-RefillRelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][AllowEmptyString()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    return [IO.Path]::GetRelativePath($Root, (Resolve-RefillPath -Root $Root -Path $Path)).Replace('\', '/')
}

function Read-RefillJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][ValidateRange(2, 100)][int]$Depth = 100
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Pflichtdatei fehlt: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth $Depth
}

function Write-RefillJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value,
        [Parameter()][ValidateRange(2, 100)][int]$Depth = 100
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($tempPath, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

function Get-RefillProperty {
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

function ConvertTo-RefillDateOrNull {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    $parsed = [datetime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([datetime]::TryParse(([string]$Value).Trim(), [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }
    return $null
}

function Get-RefillFileHash {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-RefillQueueHasReadyWork {
    param(
        [Parameter()][AllowNull()][object]$Queue,
        [Parameter(Mandatory)][datetime]$Now
    )

    if ($null -eq $Queue) {
        return $false
    }
    foreach ($entry in @($Queue.queue)) {
        $status = [string](Get-RefillProperty -Object $entry -Name 'status' -Default '')
        $action = [string](Get-RefillProperty -Object $entry -Name 'next_action' -Default '')
        if ($action -notin @('DISCOVER_OFFICIAL_WEBSITE', 'VERIFY_OFFICIAL_SITE') -or $status -notin @('PENDING', 'RETRY_SCHEDULED', 'MANUAL_REVIEW_REQUIRED')) {
            continue
        }
        $nextAttemptAt = ConvertTo-RefillDateOrNull -Value (Get-RefillProperty -Object $entry -Name 'next_attempt_at')
        if ($status -eq 'PENDING' -or $null -eq $nextAttemptAt -or $nextAttemptAt -le $Now.ToUniversalTime()) {
            return $true
        }
    }
    return $false
}

function Get-RefillWakeAt {
    param([Parameter()][AllowNull()][object]$Queue)

    if ($null -eq $Queue) {
        return $null
    }
    $futureDates = @($Queue.queue | ForEach-Object {
            ConvertTo-RefillDateOrNull -Value (Get-RefillProperty -Object $_ -Name 'next_attempt_at')
        } | Where-Object { $null -ne $_ -and $_ -gt ([datetime]::UtcNow) } | Sort-Object)
    if ($futureDates.Count -eq 0) {
        return $null
    }
    return ConvertTo-RefillIso -Value $futureDates[0]
}

function Read-RefillState {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][datetime]$Now
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return Read-RefillJsonFile -Path $Path -Depth 100
    }
    return [pscustomobject]@{
        schema_version = 'jobagent/discovery-refill-state/v1'
        generated_at = ConvertTo-RefillIso -Value $Now
        wave_count = 0
        imports = @()
    }
}

function Get-RefillSourceById {
    param(
        [Parameter(Mandatory)][object]$Registry,
        [Parameter(Mandatory)][string]$SourceId
    )

    @($Registry.items | Where-Object { [string]$_.source_id -eq $SourceId } | Select-Object -First 1)
}

function Test-RefillSourceAllowed {
    param([Parameter(Mandatory)][object]$Source)

    $sourceClass = [string](Get-RefillProperty -Object $Source -Name 'source_class' -Default '')
    $importMode = [string](Get-RefillProperty -Object $Source -Name 'import_mode' -Default '')
    $legalRisk = [string](Get-RefillProperty -Object $Source -Name 'legal_risk' -Default '')
    return $sourceClass -in @('OPEN_REGISTER_DUMP', 'REGIONAL_DIRECTORY', 'PUBLIC_INSTITUTION_DIRECTORY', 'JOB_BOARD_DISCOVERY') -and
        $importMode -in @('BULK_SNAPSHOT', 'FIXTURE_OR_SNAPSHOT_ONLY') -and
        $legalRisk -ne 'BLOCKED'
}

function Get-RefillPreviousImport {
    param(
        [Parameter(Mandatory)][object]$State,
        [Parameter(Mandatory)][string]$ManifestKey
    )

    @($State.imports | Where-Object { [string]$_.manifest_key -eq $ManifestKey } | Select-Object -Last 1)
}

function New-RefillPlan {
    param(
        [Parameter(Mandatory)][object]$Registry,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][object]$State,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][int]$MaxSources
    )

    $waveCount = [int](Get-RefillProperty -Object $State -Name 'wave_count' -Default 0)
    $preferFreising = ($waveCount % 2) -eq 1
    $candidates = foreach ($item in @($Manifest.items)) {
        $sourceId = [string](Get-RefillProperty -Object $item -Name 'source_id' -Default '')
        $inputPath = [string](Get-RefillProperty -Object $item -Name 'input_path' -Default '')
        $source = @(Get-RefillSourceById -Registry $Registry -SourceId $sourceId)
        if ($source.Count -ne 1 -or -not (Test-RefillSourceAllowed -Source $source[0]) -or [string]::IsNullOrWhiteSpace($inputPath)) {
            continue
        }
        $resolvedInputPath = Resolve-RefillPath -Root $Root -Path $inputPath
        $hash = Get-RefillFileHash -Path $resolvedInputPath
        $manifestKey = ([string](Get-RefillProperty -Object $item -Name 'kind' -Default 'UNKNOWN')) + '|' + $sourceId + '|' + (ConvertTo-RefillRelativePath -Root $Root -Path $resolvedInputPath)
        $previous = @(Get-RefillPreviousImport -State $State -ManifestKey $manifestKey)
        $previousHash = if ($previous.Count -eq 1) { [string](Get-RefillProperty -Object $previous[0] -Name 'input_hash' -Default '') } else { '' }
        if ($previous.Count -eq 1 -and $previousHash -eq $hash) {
            continue
        }
        [pscustomobject]@{
            manifest_key = $manifestKey
            kind = [string](Get-RefillProperty -Object $item -Name 'kind' -Default 'UNKNOWN')
            source_id = $sourceId
            input_path = ConvertTo-RefillRelativePath -Root $Root -Path $resolvedInputPath
            input_hash = $hash
            snapshot_id = Get-RefillProperty -Object $item -Name 'snapshot_id' -Default $null
            snapshot_date = Get-RefillProperty -Object $item -Name 'snapshot_date' -Default $null
            freising_rank = if ($preferFreising -and ($sourceId -match 'freising' -or $inputPath -match 'freising')) { 0 } else { 1 }
        }
    }
    return @($candidates | Sort-Object freising_rank, kind, source_id, input_path | Select-Object -First $MaxSources)
}

function Invoke-RefillImport {
    param(
        [Parameter(Mandatory)][object]$Item,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RegistryPath,
        [Parameter(Mandatory)][string]$HintPath,
        [Parameter(Mandatory)][string]$LogRoot
    )

    $inputPath = Resolve-RefillPath -Root $Root -Path ([string]$Item.input_path)
    switch ([string]$Item.kind) {
        'regional' {
            $script = Join-Path $toolRoot 'tools\Import-JobAgentRegionalDirectories.ps1'
            $output = & pwsh -NoProfile -File $script -ProjectRoot $Root -SnapshotPath $inputPath -SourceRegistryPath $RegistryPath -MergedHintsPath $HintPath -LogRoot $LogRoot 2>&1
            break
        }
        'jobboard' {
            $script = Join-Path $toolRoot 'tools\Import-JobAgentJobBoardEmployers.ps1'
            $output = & pwsh -NoProfile -File $script -ProjectRoot $Root -SnapshotPath $inputPath -SourceRegistryPath $RegistryPath -MergedHintsPath $HintPath -LogRoot $LogRoot 2>&1
            break
        }
        'register' {
            $script = Join-Path $toolRoot 'tools\Import-JobAgentRegisterCandidates.ps1'
            $snapshotDate = ConvertTo-RefillDateOrNull -Value (Get-RefillProperty -Object $Item -Name 'snapshot_date')
            if ($null -eq $snapshotDate) {
                throw "Register-Snapshot ohne snapshot_date: $($Item.input_path)"
            }
            $output = & pwsh -NoProfile -File $script -ProjectRoot $Root -InputPath $inputPath -SourceRegistryPath $RegistryPath -MergedHintsPath $HintPath -LogRoot $LogRoot -SourceId ([string]$Item.source_id) -SnapshotId ([string](Get-RefillProperty -Object $Item -Name 'snapshot_id' -Default '')) -SnapshotDate $snapshotDate 2>&1
            break
        }
        default {
            throw "Nicht unterstuetzter Refill-Kind: $($Item.kind)"
        }
    }
    if ($LASTEXITCODE -ne 0) {
        throw ('Discovery-Refill-Import fehlgeschlagen: ' + ($output -join "`n"))
    }
    return ($output -join "`n") | ConvertFrom-Json -Depth 100
}

function Update-RefillState {
    param(
        [Parameter(Mandatory)][object]$State,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ImportedItems,
        [Parameter(Mandatory)][datetime]$Now
    )

    $imports = [System.Collections.Generic.List[object]]::new()
    foreach ($existing in @($State.imports)) {
        $imports.Add($existing)
    }
    foreach ($item in @($ImportedItems)) {
        $imports.Add($item)
    }
    $State.generated_at = ConvertTo-RefillIso -Value $Now
    $State.wave_count = [int](Get-RefillProperty -Object $State -Name 'wave_count' -Default 0) + $(if ($ImportedItems.Count -gt 0) { 1 } else { 0 })
    $State.imports = @($imports.ToArray() | Sort-Object imported_at, manifest_key)
    return $State
}

$startedAt = [datetime]::UtcNow
$registryPath = Resolve-RefillPath -Root $projectRootResolved -Path $SourceRegistryPath
$manifestPath = Resolve-RefillPath -Root $projectRootResolved -Path $SnapshotManifestPath
$hintPath = Resolve-RefillPath -Root $projectRootResolved -Path $HintStorePath
$queuePathResolved = Resolve-RefillPath -Root $projectRootResolved -Path $QueuePath
$storePath = Resolve-RefillPath -Root $projectRootResolved -Path (Join-Path $DataRoot 'store.json')
$statePath = Resolve-RefillPath -Root $projectRootResolved -Path $RefillStatePath
$logRootPath = Resolve-RefillPath -Root $projectRootResolved -Path $LogRoot

$queueBefore = if (Test-Path -LiteralPath $queuePathResolved -PathType Leaf) { Read-RefillJsonFile -Path $queuePathResolved -Depth 100 } else { $null }
if (-not $Force -and (Test-RefillQueueHasReadyWork -Queue $queueBefore -Now $startedAt)) {
    $summary = [pscustomobject]@{
        schema_version = 'jobagent/discovery-refill/v1'
        status = 'SKIPPED'
        reason = 'ready_queue_available'
        started_at = ConvertTo-RefillIso -Value $startedAt
        finished_at = ConvertTo-RefillIso -Value ([datetime]::UtcNow)
        imported_sources_total = 0
        imported_sources = @()
        queue_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $queuePathResolved
        wake_at = Get-RefillWakeAt -Queue $queueBefore
    }
    $summary | ConvertTo-Json -Depth 20
    return
}

if ((-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) -or (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf))) {
    $summary = [pscustomobject]@{
        schema_version = 'jobagent/discovery-refill/v1'
        status = 'SKIPPED'
        reason = 'source_registry_or_snapshot_manifest_missing'
        started_at = ConvertTo-RefillIso -Value $startedAt
        finished_at = ConvertTo-RefillIso -Value ([datetime]::UtcNow)
        imported_sources_total = 0
        imported_sources = @()
        queue_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $queuePathResolved
        wake_at = Get-RefillWakeAt -Queue $queueBefore
    }
    $summary | ConvertTo-Json -Depth 20
    return
}

$registry = Read-RefillJsonFile -Path $registryPath -Depth 100
$manifest = Read-RefillJsonFile -Path $manifestPath -Depth 100
$state = Read-RefillState -Path $statePath -Now $startedAt
$plan = @(New-RefillPlan -Registry $registry -Manifest $manifest -State $state -Root $projectRootResolved -MaxSources $MaxSources)
$imported = New-Object System.Collections.Generic.List[object]
foreach ($item in $plan) {
    $importResult = Invoke-RefillImport -Item $item -Root $projectRootResolved -RegistryPath $registryPath -HintPath $hintPath -LogRoot $LogRoot
    $imported.Add([pscustomobject]@{
            manifest_key = [string]$item.manifest_key
            kind = [string]$item.kind
            source_id = [string]$item.source_id
            input_path = [string]$item.input_path
            input_hash = [string]$item.input_hash
            imported_at = ConvertTo-RefillIso -Value ([datetime]::UtcNow)
            hints_total = [int](Get-RefillProperty -Object $importResult -Name 'hints_total' -Default 0)
            log_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path ([string](Get-RefillProperty -Object $importResult -Name 'log_path' -Default ''))
        })
}

$updatedState = Update-RefillState -State $state -ImportedItems @($imported.ToArray()) -Now $startedAt
Write-RefillJsonFile -Path $statePath -Value $updatedState -Depth 100

$hintStore = if (Test-Path -LiteralPath $hintPath -PathType Leaf) { Read-RefillJsonFile -Path $hintPath -Depth 100 } else { $null }
$previousQueue = if (Test-Path -LiteralPath $queuePathResolved -PathType Leaf) { Read-RefillJsonFile -Path $queuePathResolved -Depth 100 } else { $null }
$store = if (Test-Path -LiteralPath $storePath -PathType Leaf) { Read-RefillJsonFile -Path $storePath -Depth 100 } else { [pscustomobject]@{ companies = @() } }
$rebuiltQueue = New-JobAgentCoverageCandidateReviewQueue -HintStore $hintStore -SourceRegistry $registry -PreviousQueue $previousQueue -ExistingCompanies @($store.companies) -Now $startedAt -MaxItems 1000
Write-RefillJsonFile -Path $queuePathResolved -Value $rebuiltQueue -Depth 100

New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$logPath = Join-Path $logRootPath ('JA-027-refill-' + $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    schema_version = 'jobagent/discovery-refill/v1'
    status = if ($imported.Count -gt 0) { 'COMPLETED' } else { 'SKIPPED' }
    reason = if ($imported.Count -gt 0) { 'source_wave_imported' } else { 'no_changed_or_unseen_allowed_snapshot' }
    started_at = ConvertTo-RefillIso -Value $startedAt
    finished_at = ConvertTo-RefillIso -Value ([datetime]::UtcNow)
    source_registry_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $registryPath
    snapshot_manifest_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $manifestPath
    hint_store_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $hintPath
    queue_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $queuePathResolved
    state_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $statePath
    log_path = ConvertTo-RefillRelativePath -Root $projectRootResolved -Path $logPath
    imported_sources_total = $imported.Count
    imported_sources = @($imported.ToArray())
    queue_total = @($rebuiltQueue.queue).Count
    queue_ready_total = [int]$rebuiltQueue.ready_total
    wake_at = Get-RefillWakeAt -Queue $rebuiltQueue
}
Write-RefillJsonFile -Path $logPath -Value $summary -Depth 100
$summary | ConvertTo-Json -Depth 100
