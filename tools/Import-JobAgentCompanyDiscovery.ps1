#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$FeedPath = 'data/jobagent/company-discovery.official.json',
    [Parameter()][switch]$SnapshotLane,
    [Parameter()][AllowNull()][string]$SnapshotManifestPath = $null,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][AllowNull()][string]$WaveId = $null,
    [Parameter()][string]$WaveConfigPath = 'data/jobagent/company-import-waves.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.RegisterDiscovery.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.JobBoardDiscovery.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.RegionalDiscovery.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function New-ToolStoreBackup {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$DataRootPath,
        [Parameter(Mandatory)][string]$Reason
    )

    $store = Join-Path (Join-Path $Root $DataRootPath) 'store.json'
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) {
        return $null
    }
    $backupRoot = Join-Path (Join-Path $Root $DataRootPath) 'backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
    $backupPath = Join-Path $backupRoot ("store-$stamp-$Reason.json")
    Copy-Item -LiteralPath $store -Destination $backupPath -Force
    return $backupPath
}

function Write-ToolImportGateFailureLog {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$LogRootPath,
        [Parameter(Mandatory)][datetime]$Timestamp,
        [Parameter(Mandatory)][string]$FeedPath,
        [Parameter(Mandatory)][string]$WaveIdValue,
        [Parameter(Mandatory)][object]$WaveGate,
        [Parameter()][AllowNull()][string]$BackupPath
    )

    $resolvedLogRoot = if ([IO.Path]::IsPathRooted($LogRootPath)) { $LogRootPath } else { Join-Path $Root $LogRootPath }
    New-Item -ItemType Directory -Path $resolvedLogRoot -Force | Out-Null
    $logPath = Join-Path $resolvedLogRoot ('company-discovery-import-failed-' + $Timestamp.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
    [pscustomobject]@{
        ts = $Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        status = 'failed'
        feed_path = $FeedPath
        wave_id = $WaveIdValue
        wave_gate = $WaveGate
        backup_path = $BackupPath
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $logPath -Encoding UTF8
    return $logPath
}

function Resolve-ToolProjectPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-ToolObjectProperty {
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

function Write-ToolAtomicJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value,
        [Parameter()][int]$Depth = 100
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($tempPath, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function ConvertTo-ToolSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-ToolDiscoverySource {
    param(
        [Parameter(Mandatory)][object]$Registry,
        [Parameter(Mandatory)][string]$SourceId
    )

    $source = @($Registry.items | Where-Object { [string]$_.source_id -eq $SourceId } | Select-Object -First 1)
    if ($source.Count -ne 1) {
        throw "Snapshot-Quelle fehlt in Source Registry: $SourceId"
    }
    return $source[0]
}

function Assert-ToolSnapshotSource {
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter(Mandatory)][string]$Kind
    )

    if ([string]::IsNullOrWhiteSpace([string]$Source.allowed_use) -or
        [string]::IsNullOrWhiteSpace([string]$Source.rate_limit_policy) -or
        [string]::IsNullOrWhiteSpace([string]$Source.robots_or_terms_note) -or
        [string]::IsNullOrWhiteSpace([string]$Source.import_mode)) {
        throw "Snapshot-Quelle $($Source.source_id) hat unvollstaendige Nutzungs- oder Rate-Limit-Felder."
    }
    if ([string]$Source.import_mode -eq 'REJECT') {
        throw "Snapshot-Quelle $($Source.source_id) ist blockiert."
    }
    if ([string]$Source.import_mode -notin @('BULK_SNAPSHOT', 'FIXTURE_OR_SNAPSHOT_ONLY')) {
        throw "Snapshot-Quelle $($Source.source_id) ist nicht fuer lokale Snapshot-Hints freigegeben."
    }
    if ([bool]$Source.review_required -ne $true -or [string]$Source.evidence_level -eq 'PRIMARY_OFFICIAL') {
        throw "Snapshot-Quelle $($Source.source_id) darf keine produktive Primaerevidenz erzeugen."
    }
    if ($Kind -eq 'jobboard' -and [string]$Source.source_class -ne 'JOB_BOARD_DISCOVERY') {
        throw "Snapshot-Quelle $($Source.source_id) ist keine Jobboersenquelle."
    }
    if ($Kind -eq 'register' -and [string]$Source.source_class -ne 'OPEN_REGISTER_DUMP') {
        throw "Snapshot-Quelle $($Source.source_id) ist keine Register-Dump-Quelle."
    }
    if ($Kind -eq 'regional' -and [string]$Source.source_class -notin @('REGIONAL_DIRECTORY', 'PUBLIC_INSTITUTION_DIRECTORY')) {
        throw "Snapshot-Quelle $($Source.source_id) ist keine regionale Quelle."
    }
}

function New-ToolDiscoverySnapshotLog {
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    $raw = Get-Content -LiteralPath $InputPath -Raw
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-snapshot/v1'
        status = 'ok'
        ts = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        source_id = [string]$Source.source_id
        source_class = [string]$Source.source_class
        import_kind = $Kind
        import_mode = [string]$Source.import_mode
        allowed_use = [string]$Source.allowed_use
        rate_limit_policy = [string]$Source.rate_limit_policy
        robots_or_terms_note = [string]$Source.robots_or_terms_note
        legal_risk = [string]$Source.legal_risk
        input_path = $InputPath
        input_hash = ConvertTo-ToolSha256 -Value $raw
        records_read = [int](Get-ToolObjectProperty -Object $Result -Name 'records_read' -Default (Get-ToolObjectProperty -Object $Result -Name 'sources_read' -Default 0))
        hints_total = [int](Get-ToolObjectProperty -Object $Result -Name 'hints_total' -Default 0)
        reject_counts = Get-ToolObjectProperty -Object $Result -Name 'reject_counts' -Default ([pscustomobject]@{})
        official_verification_required = $true
        productive_store_write = $false
    }
}

function New-ToolMergedHintStore {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$ExistingHints = @(),
        [Parameter()][AllowEmptyCollection()][object[]]$NewHints = @(),
        [Parameter(Mandatory)][datetime]$GeneratedAt,
        [Parameter()][int]$SearchMatrixCount = 0
    )

    $mergedById = [ordered]@{}
    foreach ($hint in @($ExistingHints) + @($NewHints)) {
        $hintId = [string](Get-ToolObjectProperty -Object $hint -Name 'hint_id' -Default '')
        if (-not [string]::IsNullOrWhiteSpace($hintId)) {
            $mergedById[$hintId] = $hint
        }
    }
    $mergedHints = @($mergedById.Values | Sort-Object hint_id)
    $sourceCounts = [ordered]@{}
    foreach ($hint in $mergedHints) {
        $sourceId = [string](Get-ToolObjectProperty -Object $hint -Name 'source_id' -Default 'UNKNOWN')
        if (-not $sourceCounts.Contains($sourceId)) {
            $sourceCounts[$sourceId] = 0
        }
        $sourceCounts[$sourceId]++
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = $GeneratedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
        search_matrix_count = $SearchMatrixCount
        hints_total = $mergedHints.Count
        known_company_hints = @($mergedHints | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-ToolObjectProperty -Object $_ -Name 'known_company_id' -Default $null)) }).Count
        unverified_hints = @($mergedHints | Where-Object { [string](Get-ToolObjectProperty -Object $_ -Name 'verification_status' -Default 'UNVERIFIED') -eq 'UNVERIFIED' -or [bool](Get-ToolObjectProperty -Object $_ -Name 'official_verification_required' -Default $false) }).Count
        source_counts = [pscustomobject]$sourceCounts
        hints = $mergedHints
    }
}

function Invoke-ToolDiscoverySnapshotLane {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$DataRootPath,
        [Parameter(Mandatory)][string]$LogRootPath,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    $resolvedManifest = Resolve-ToolProjectPath -Root $Root -Path $ManifestPath
    if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
        throw "Snapshot-Manifest fehlt: $resolvedManifest"
    }
    $manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json -Depth 100
    if ($manifest.PSObject.Properties.Name -notcontains 'items' -or @($manifest.items).Count -lt 1) {
        throw "Snapshot-Manifest enthaelt keine items: $resolvedManifest"
    }

    $registryPath = Resolve-ToolProjectPath -Root $Root -Path 'data/jobagent/company-discovery.sources.json'
    $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -Depth 100
    Assert-JobAgentDiscoverySourceRegistry -Registry $registry
    $document = Read-JobAgentStore -ProjectRoot $Root -DataRoot $DataRootPath
    $logRootPath = Resolve-ToolProjectPath -Root $Root -Path $LogRootPath
    New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null

    $newHints = [System.Collections.Generic.List[object]]::new()
    $snapshotLogs = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($manifest.items)) {
        $kind = [string](Get-ToolObjectProperty -Object $item -Name 'kind' -Default '')
        $sourceId = [string](Get-ToolObjectProperty -Object $item -Name 'source_id' -Default '')
        $inputPath = Resolve-ToolProjectPath -Root $Root -Path ([string](Get-ToolObjectProperty -Object $item -Name 'input_path' -Default ''))
        if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
            throw "Snapshot-Eingabe fehlt: $inputPath"
        }
        $source = Get-ToolDiscoverySource -Registry $registry -SourceId $sourceId
        Assert-ToolSnapshotSource -Source $source -Kind $kind

        if ($kind -eq 'register') {
            $snapshotDate = [datetime]::Parse([string](Get-ToolObjectProperty -Object $item -Name 'snapshot_date' -Default ''), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
            $snapshotId = [string](Get-ToolObjectProperty -Object $item -Name 'snapshot_id' -Default ([IO.Path]::GetFileNameWithoutExtension($inputPath)))
            $result = Import-JobAgentRegisterCandidates -InputPath $inputPath -SourceRegistry $registry -SourceId $sourceId -SnapshotId $snapshotId -SnapshotDate $snapshotDate -ObservedAt $ObservedAt
        }
        elseif ($kind -eq 'jobboard') {
            $result = Import-JobAgentJobBoardEmployers -SnapshotPath $inputPath -SourceRegistry $registry -KnownCompanies @($document.companies)
        }
        elseif ($kind -eq 'regional') {
            $result = Import-JobAgentRegionalDirectories -SnapshotPath $inputPath -SourceRegistry $registry
        }
        else {
            throw "Nicht unterstuetzter Snapshot-Kind: $kind"
        }

        foreach ($hint in @($result.hints)) {
            $newHints.Add($hint)
        }
        $logSources = [System.Collections.Generic.List[object]]::new()
        if ($kind -eq 'regional' -and $result.PSObject.Properties.Name -contains 'source_counts') {
            foreach ($property in $result.source_counts.PSObject.Properties) {
                $regionalSource = Get-ToolDiscoverySource -Registry $registry -SourceId ([string]$property.Name)
                Assert-ToolSnapshotSource -Source $regionalSource -Kind $kind
                $logSources.Add([pscustomobject]@{
                        source = $regionalSource
                        hints_total = [int]$property.Value
                    })
            }
        }
        else {
            $logSources.Add([pscustomobject]@{
                    source = $source
                    hints_total = [int](Get-ToolObjectProperty -Object $result -Name 'hints_total' -Default 0)
                })
        }

        foreach ($logSource in @($logSources.ToArray())) {
            $snapshotLog = New-ToolDiscoverySnapshotLog -Source $logSource.source -Kind $kind -InputPath $inputPath -Result $result -ObservedAt $ObservedAt
            $snapshotLog.hints_total = [int]$logSource.hints_total
            $safeSource = [regex]::Replace(([string]$logSource.source.source_id).Substring(16), '[^a-z0-9._-]+', '_')
            $snapshotLogPath = Join-Path $logRootPath ('company-discovery-snapshot-' + $safeSource + '-' + $ObservedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
            Write-ToolAtomicJson -Path $snapshotLogPath -Value $snapshotLog -Depth 30
            $snapshotLogs.Add(($snapshotLog | Add-Member -NotePropertyName log_path -NotePropertyValue $snapshotLogPath -PassThru))
        }
    }

    $hintsPath = Resolve-ToolProjectPath -Root $Root -Path (Join-Path $DataRootPath 'company-discovery.hints.json')
    $existingStore = if (Test-Path -LiteralPath $hintsPath -PathType Leaf) { Get-Content -LiteralPath $hintsPath -Raw | ConvertFrom-Json -Depth 100 } else { $null }
    $existingHints = if ($null -eq $existingStore) { @() } else { @($existingStore.hints) }
    $searchMatrixCount = if ($null -eq $existingStore) { 0 } else { [int](Get-ToolObjectProperty -Object $existingStore -Name 'search_matrix_count' -Default 0) }
    $mergedStore = New-ToolMergedHintStore -ExistingHints $existingHints -NewHints @($newHints.ToArray()) -GeneratedAt $ObservedAt -SearchMatrixCount $searchMatrixCount
    Write-ToolAtomicJson -Path $hintsPath -Value $mergedStore -Depth 100

    $digestPath = Join-Path $logRootPath ('company-discovery-snapshot-digest-' + $ObservedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
    $digest = [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-snapshot-digest/v1'
        status = 'ok'
        ts = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        manifest_path = $resolvedManifest
        merged_hints_path = $hintsPath
        sources_total = @($snapshotLogs.ToArray()).Count
        new_hints_total = @($newHints.ToArray()).Count
        merged_hints_total = [int]$mergedStore.hints_total
        snapshot_logs = @($snapshotLogs.ToArray())
        productive_store_write = $false
        official_verification_required = $true
    }
    Write-ToolAtomicJson -Path $digestPath -Value $digest -Depth 100
    return ($digest | Add-Member -NotePropertyName digest_path -NotePropertyValue $digestPath -PassThru)
}

$importedAt = [datetime]::UtcNow
if ($SnapshotLane) {
    $manifestPath = if ([string]::IsNullOrWhiteSpace($SnapshotManifestPath)) { 'data/jobagent/company-discovery.snapshot.json' } else { $SnapshotManifestPath }
    Invoke-ToolDiscoverySnapshotLane -Root $projectRoot -ManifestPath $manifestPath -DataRootPath $DataRoot -LogRootPath $LogRoot -ObservedAt $importedAt | ConvertTo-Json -Depth 100
    return
}

$nextScanAt = $importedAt.Date.AddDays(1)
$resolvedFeedPath = if ([IO.Path]::IsPathRooted($FeedPath)) { $FeedPath } else { Join-Path $projectRoot $FeedPath }
if (-not (Test-Path -LiteralPath $resolvedFeedPath -PathType Leaf)) {
    throw "Discovery-Feed fehlt: $resolvedFeedPath"
}
$feed = Get-Content -LiteralPath $resolvedFeedPath -Raw | ConvertFrom-Json -Depth 100
$discoveryItems = if ($feed -is [System.Collections.IEnumerable] -and $feed -isnot [string]) { @($feed) } else { @($feed.items) }
if ($discoveryItems.Count -eq 0) {
    throw "Discovery-Feed enthaelt keine Eintraege: $resolvedFeedPath"
}

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRoot -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
    $beforeDocument = $document | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    $importSummary = Import-JobAgentCompanyDiscoveryInventory -Document $document -DiscoveryItems $discoveryItems -ImportedAt $importedAt -NextScanAt $nextScanAt
    $backupPath = $null
    $waveGate = $null
    if (-not [string]::IsNullOrWhiteSpace($WaveId)) {
        $resolvedWaveConfigPath = if ([IO.Path]::IsPathRooted($WaveConfigPath)) { $WaveConfigPath } else { Join-Path $projectRoot $WaveConfigPath }
        if (-not (Test-Path -LiteralPath $resolvedWaveConfigPath -PathType Leaf)) {
            throw "Importwellen-Konfiguration fehlt: $resolvedWaveConfigPath"
        }
        $backupPath = New-ToolStoreBackup -Root $projectRoot -DataRootPath $DataRoot -Reason 'pre-wave-import'
        $waveConfig = Get-Content -Raw -LiteralPath $resolvedWaveConfigPath | ConvertFrom-Json -Depth 100
        $waveGate = Test-JobAgentCompanyImportWaveGate -BeforeDocument $beforeDocument -ImportSummary $importSummary -WaveConfig $waveConfig -WaveId $WaveId -BackupPath $backupPath
        if ([string]$waveGate.status -ne 'passed') {
            Write-ToolImportGateFailureLog -Root $projectRoot -LogRootPath $LogRoot -Timestamp $importedAt -FeedPath $resolvedFeedPath -WaveIdValue $WaveId -WaveGate $waveGate -BackupPath $backupPath | Out-Null
            throw ('Importwellen-Gate fehlgeschlagen: ' + ((@($waveGate.violations) | Sort-Object) -join ', '))
        }
    }
    $storePath = Write-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot -Document $importSummary.document -CreateBackup:([string]::IsNullOrWhiteSpace($WaveId))
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$after = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$feedName = [IO.Path]::GetFileNameWithoutExtension($resolvedFeedPath)
$logPrefix = if ($feedName -match 'regional') { 'company-discovery-regional-import-' } else { 'company-discovery-import-' }
$logPath = Join-Path $logPathRoot ($logPrefix + $importedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    ts = $importedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    feed_path = $resolvedFeedPath
    store_path = $storePath
    imported_company_ids = @($importSummary.imported)
    added_company_ids = @($importSummary.added)
    updated_company_ids = @($importSummary.updated)
    deduplicated = @($importSummary.deduplicated)
    manual_review_required = @($importSummary.manual_review_required)
    wave_id = if ([string]::IsNullOrWhiteSpace($WaveId)) { $null } else { $WaveId }
    wave_gate = $waveGate
    backup_path = $backupPath
    company_count = @($after.companies).Count
    source_count = @($after.job_sources).Count
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 8
