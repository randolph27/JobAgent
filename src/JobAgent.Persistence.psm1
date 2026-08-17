#requires -Version 7.4

Set-StrictMode -Version 3.0

$script:SchemaVersion = 'jobagent/v1'
$script:StoreFileName = 'store.json'
$script:LockFileName = 'store.lock'

function Resolve-JobAgentStoreRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    $resolved = [IO.Path]::GetFullPath($RootPath)
    return $resolved.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function New-JobAgentEmptyDocument {
    [CmdletBinding()]
    param(
        [Parameter()][datetime]$GeneratedAt = [datetime]::UtcNow
    )

    [pscustomobject]@{
        schema_version = $script:SchemaVersion
        generated_at = $GeneratedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        companies = @()
        jobs = @()
        job_sources = @()
        scan_runs = @()
        scan_attempts = @()
        job_snapshots = @()
        change_events = @()
    }
}

function Assert-JobAgentStorePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $root = Resolve-JobAgentStoreRoot -RootPath $ProjectRoot
    $resolved = [IO.Path]::GetFullPath($Path)
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (($resolved -ne $root) -and (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Pfad liegt ausserhalb des Projektverzeichnisses: $resolved"
    }
    return $resolved
}

function Get-JobAgentStorePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$DataRoot = 'data/jobagent'
    )

    $root = Resolve-JobAgentStoreRoot -RootPath $ProjectRoot
    $dataPath = if ([IO.Path]::IsPathRooted($DataRoot)) { $DataRoot } else { Join-Path $root $DataRoot }
    $dataPath = Assert-JobAgentStorePath -ProjectRoot $root -Path $dataPath
    [pscustomobject]@{
        project_root = $root
        data_root = $dataPath
        store_path = Join-Path $dataPath $script:StoreFileName
        lock_path = Join-Path $dataPath $script:LockFileName
        backup_root = Join-Path $dataPath 'backups'
        migration_log_path = Join-Path $dataPath 'migration.log.jsonl'
    }
}

function ConvertTo-JobAgentJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document
    )

    return ($Document | ConvertTo-Json -Depth 100)
}

function Test-JobAgentId {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][string]$Prefix
    )

    return $Value -match ('^' + [regex]::Escape($Prefix) + ':[A-Za-z0-9][A-Za-z0-9._:-]*$')
}

function Assert-JobAgentDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document
    )

    foreach ($property in @('schema_version', 'generated_at', 'companies', 'jobs', 'job_sources', 'scan_runs', 'scan_attempts', 'job_snapshots', 'change_events')) {
        if ($Document.PSObject.Properties.Name -notcontains $property) {
            throw "JobAgent-Dokument fehlt Pflichtfeld $property."
        }
    }
    if ($Document.schema_version -ne $script:SchemaVersion) {
        throw "Nicht unterstuetzte schema_version: $($Document.schema_version)"
    }

    foreach ($company in @($Document.companies)) {
        if (-not (Test-JobAgentId -Value ([string]$company.company_id) -Prefix 'company')) {
            throw "Ungueltige company_id: $($company.company_id)"
        }
    }
    foreach ($source in @($Document.job_sources)) {
        if (-not (Test-JobAgentId -Value ([string]$source.source_id) -Prefix 'source')) {
            throw "Ungueltige source_id: $($source.source_id)"
        }
        if ($source.is_official -ne $true) {
            throw "JobSource ist nicht offiziell: $($source.source_id)"
        }
    }
    foreach ($job in @($Document.jobs)) {
        if (-not (Test-JobAgentId -Value ([string]$job.job_id) -Prefix 'job')) {
            throw "Ungueltige job_id: $($job.job_id)"
        }
        if ([string]::IsNullOrWhiteSpace([string]$job.official_url)) {
            throw "Job ohne official_url: $($job.job_id)"
        }
        if ([string]::IsNullOrWhiteSpace([string]$job.source_id)) {
            throw "Job ohne source_id: $($job.job_id)"
        }
    }
    foreach ($attempt in @($Document.scan_attempts)) {
        if (-not (Test-JobAgentId -Value ([string]$attempt.scan_attempt_id) -Prefix 'scanattempt')) {
            throw "Ungueltige scan_attempt_id: $($attempt.scan_attempt_id)"
        }
    }
    foreach ($snapshot in @($Document.job_snapshots)) {
        if (-not (Test-JobAgentId -Value ([string]$snapshot.snapshot_id) -Prefix 'snapshot')) {
            throw "Ungueltige snapshot_id: $($snapshot.snapshot_id)"
        }
    }
}

function Read-JobAgentStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$DataRoot = 'data/jobagent'
    )

    $paths = Get-JobAgentStorePaths -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    if (-not (Test-Path -LiteralPath $paths.store_path)) {
        return New-JobAgentEmptyDocument
    }

    try {
        $document = Get-Content -LiteralPath $paths.store_path -Raw | ConvertFrom-Json -Depth 100
        Assert-JobAgentDocument -Document $document
        return $document
    }
    catch {
        throw "JobAgent-Store kann nicht geladen werden: $($paths.store_path): $($_.Exception.Message)"
    }
}

function Add-JobAgentMigrationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Paths,
        [Parameter(Mandatory)][string]$FromVersion,
        [Parameter(Mandatory)][string]$ToVersion,
        [Parameter()][string]$BackupPath
    )

    $entry = [pscustomobject]@{
        ts = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        from_version = $FromVersion
        to_version = $ToVersion
        backup_path = $BackupPath
    } | ConvertTo-Json -Compress -Depth 6
    $directory = Split-Path -Parent $Paths.migration_log_path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    Add-Content -LiteralPath $Paths.migration_log_path -Value $entry -Encoding UTF8
}

function ConvertTo-JobAgentV1Document {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document
    )

    $version = [string]$Document.schema_version
    if ($version -eq $script:SchemaVersion) {
        Assert-JobAgentDocument -Document $Document
        return $Document
    }
    if ($version -ne 'jobagent/v0') {
        throw "Keine Migration fuer schema_version $version verfuegbar."
    }

    $migrated = New-JobAgentEmptyDocument
    foreach ($property in @('companies', 'jobs', 'job_sources', 'scan_runs', 'scan_attempts', 'job_snapshots', 'change_events')) {
        if ($Document.PSObject.Properties.Name -contains $property) {
            $migrated.$property = @($Document.$property)
        }
    }
    Assert-JobAgentDocument -Document $migrated
    return $migrated
}

function Update-JobAgentStoreMigration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$DataRoot = 'data/jobagent'
    )

    $paths = Get-JobAgentStorePaths -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    if (-not (Test-Path -LiteralPath $paths.store_path)) {
        $empty = New-JobAgentEmptyDocument
        Write-JobAgentStore -ProjectRoot $ProjectRoot -DataRoot $DataRoot -Document $empty | Out-Null
        return [pscustomobject]@{
            migrated = $false
            from_version = $null
            to_version = $script:SchemaVersion
            backup_path = $null
            store_path = $paths.store_path
        }
    }

    $raw = Get-Content -LiteralPath $paths.store_path -Raw | ConvertFrom-Json -Depth 100
    $fromVersion = [string]$raw.schema_version
    $migrated = ConvertTo-JobAgentV1Document -Document $raw
    if ($fromVersion -eq $script:SchemaVersion) {
        return [pscustomobject]@{
            migrated = $false
            from_version = $fromVersion
            to_version = $script:SchemaVersion
            backup_path = $null
            store_path = $paths.store_path
        }
    }

    $backupPath = Backup-JobAgentStore -Paths $paths -Reason ('migrate-' + ($fromVersion -replace '[^A-Za-z0-9._-]', '_'))
    Write-JobAgentAtomicFile -Path $paths.store_path -Content (ConvertTo-JobAgentJson -Document $migrated)
    Add-JobAgentMigrationLog -Paths $paths -FromVersion $fromVersion -ToVersion $script:SchemaVersion -BackupPath $backupPath
    [pscustomobject]@{
        migrated = $true
        from_version = $fromVersion
        to_version = $script:SchemaVersion
        backup_path = $backupPath
        store_path = $paths.store_path
    }
}

function Write-JobAgentAtomicFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $tempPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content + "`n")
    $stream = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }

    if (Test-Path -LiteralPath $Path) {
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    else {
        Move-Item -LiteralPath $tempPath -Destination $Path
    }
}

function Backup-JobAgentStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Paths,
        [Parameter()][string]$Reason = 'write'
    )

    if (-not (Test-Path -LiteralPath $Paths.store_path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Paths.backup_root)) {
        New-Item -ItemType Directory -Path $Paths.backup_root -Force | Out-Null
    }
    $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
    $backupPath = Join-Path $Paths.backup_root ("store-$stamp-$Reason.json")
    Copy-Item -LiteralPath $Paths.store_path -Destination $backupPath -Force
    return $backupPath
}

function Write-JobAgentStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$Document,
        [Parameter()][string]$DataRoot = 'data/jobagent',
        [Parameter()][switch]$CreateBackup
    )

    $paths = Get-JobAgentStorePaths -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    Assert-JobAgentDocument -Document $Document
    if ($CreateBackup) {
        Backup-JobAgentStore -Paths $paths -Reason 'pre-write' | Out-Null
    }
    Write-JobAgentAtomicFile -Path $paths.store_path -Content (ConvertTo-JobAgentJson -Document $Document)
    return $paths.store_path
}

function Enter-JobAgentStoreLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$DataRoot = 'data/jobagent'
    )

    $paths = Get-JobAgentStorePaths -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    if (-not (Test-Path -LiteralPath $paths.data_root)) {
        New-Item -ItemType Directory -Path $paths.data_root -Force | Out-Null
    }

    try {
        $stream = [IO.File]::Open($paths.lock_path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    }
    catch {
        throw "JobAgent-Store ist gesperrt: $($paths.lock_path)"
    }

    $payload = [pscustomobject]@{
        pid = $PID
        acquired_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        project_root = $paths.project_root
    } | ConvertTo-Json -Depth 4
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($payload)
    $stream.SetLength(0)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)

    [pscustomobject]@{
        stream = $stream
        lock_path = $paths.lock_path
    }
}

function Exit-JobAgentStoreLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Lock
    )

    if ($Lock.stream) {
        $Lock.stream.Dispose()
    }
}

function Invoke-JobAgentStoreTransaction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter()][string]$DataRoot = 'data/jobagent',
        [Parameter()][switch]$CreateBackup
    )

    $lock = Enter-JobAgentStoreLock -ProjectRoot $ProjectRoot -DataRoot $DataRoot
    try {
        $document = Read-JobAgentStore -ProjectRoot $ProjectRoot -DataRoot $DataRoot
        $updated = & $ScriptBlock $document
        if ($null -eq $updated) {
            $updated = $document
        }
        $path = Write-JobAgentStore -ProjectRoot $ProjectRoot -DataRoot $DataRoot -Document $updated -CreateBackup:$CreateBackup
        [pscustomobject]@{
            store_path = $path
            document = $updated
        }
    }
    finally {
        Exit-JobAgentStoreLock -Lock $lock
    }
}

function Upsert-JobAgentItem {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][object]$Item,
        [Parameter(Mandatory)][string]$IdProperty
    )

    $list = New-Object System.Collections.Generic.List[object]
    $found = $false
    foreach ($existing in @($Items)) {
        if ([string]$existing.$IdProperty -eq [string]$Item.$IdProperty) {
            $list.Add($Item)
            $found = $true
        }
        else {
            $list.Add($existing)
        }
    }
    if (-not $found) {
        $list.Add($Item)
    }
    return $list.ToArray()
}

function Upsert-JobAgentCompany {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$Company
    )

    if (-not (Test-JobAgentId -Value ([string]$Company.company_id) -Prefix 'company')) {
        throw "Ungueltige company_id: $($Company.company_id)"
    }
    $Document.companies = @(Upsert-JobAgentItem -Items @($Document.companies) -Item $Company -IdProperty 'company_id')
    return $Document
}

function Upsert-JobAgentJobSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$JobSource
    )

    if ($JobSource.is_official -ne $true) {
        throw "JobSource muss offiziell sein."
    }
    $Document.job_sources = @(Upsert-JobAgentItem -Items @($Document.job_sources) -Item $JobSource -IdProperty 'source_id')
    return $Document
}

function Upsert-JobAgentJobSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$Job,
        [Parameter(Mandatory)][object]$Snapshot,
        [Parameter()][object]$ChangeEvent
    )

    $Document.jobs = @(Upsert-JobAgentItem -Items @($Document.jobs) -Item $Job -IdProperty 'job_id')
    $Document.job_snapshots = @(Upsert-JobAgentItem -Items @($Document.job_snapshots) -Item $Snapshot -IdProperty 'snapshot_id')
    if ($null -ne $ChangeEvent) {
        $Document.change_events = @(Upsert-JobAgentItem -Items @($Document.change_events) -Item $ChangeEvent -IdProperty 'change_event_id')
    }
    return $Document
}

function Record-JobAgentScanAttempt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$ScanAttempt
    )

    $Document.scan_attempts = @(Upsert-JobAgentItem -Items @($Document.scan_attempts) -Item $ScanAttempt -IdProperty 'scan_attempt_id')
    return $Document
}

function Upsert-JobAgentScanRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$ScanRun
    )

    $Document.scan_runs = @(Upsert-JobAgentItem -Items @($Document.scan_runs) -Item $ScanRun -IdProperty 'scan_run_id')
    return $Document
}

function Mark-JobAgentMissingJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$SeenJobIds,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][string]$ChangedAt
    )

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $SeenJobIds) {
        [void]$seen.Add($id)
    }
    $jobs = New-Object System.Collections.Generic.List[object]
    $events = New-Object System.Collections.Generic.List[object]
    foreach ($event in @($Document.change_events)) {
        $events.Add($event)
    }

    foreach ($job in @($Document.jobs)) {
        if (($job.company_id -eq $CompanyId) -and (-not $seen.Contains([string]$job.job_id)) -and (@('NEW', 'ACTIVE', 'UPDATED') -contains [string]$job.status)) {
            $oldStatus = [string]$job.status
            $job.status = 'REMOVED'
            $job.changed_at = $ChangedAt
            $eventId = ('change:' + ([string]$job.job_id).Substring(4) + '_removed_' + ($ChangedAt -replace '[^0-9A-Za-z]', ''))
            $events.Add([pscustomobject]@{
                change_event_id = $eventId
                job_id = $job.job_id
                scan_run_id = $ScanRunId
                event_type = 'JOB_REMOVED'
                created_at = $ChangedAt
                old_status = $oldStatus
                new_status = 'REMOVED'
                changed_fields = @('status', 'changed_at')
                reason = 'Nach erfolgreichem offiziellem Scan nicht mehr auffindbar.'
            })
        }
        $jobs.Add($job)
    }

    $Document.jobs = $jobs.ToArray()
    $Document.change_events = $events.ToArray()
    return $Document
}

function Get-JobAgentDailyOutputCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document
    )

    @($Document.jobs) |
        Where-Object { @('NEW', 'UPDATED', 'CLOSED', 'REMOVED') -contains [string]$_.status } |
        Sort-Object -Property company_id, priority, title
}

Export-ModuleMember -Function @(
    'Assert-JobAgentDocument',
    'Backup-JobAgentStore',
    'Enter-JobAgentStoreLock',
    'Exit-JobAgentStoreLock',
    'Get-JobAgentDailyOutputCandidates',
    'Get-JobAgentStorePaths',
    'Invoke-JobAgentStoreTransaction',
    'Mark-JobAgentMissingJobs',
    'New-JobAgentEmptyDocument',
    'Read-JobAgentStore',
    'Record-JobAgentScanAttempt',
    'Resolve-JobAgentStoreRoot',
    'Update-JobAgentStoreMigration',
    'Upsert-JobAgentCompany',
    'Upsert-JobAgentJobSnapshot',
    'Upsert-JobAgentJobSource',
    'Upsert-JobAgentScanRun',
    'Write-JobAgentStore'
)
