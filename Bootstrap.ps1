#requires -Version 7.4

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)]
    [ValidateSet('List', 'Audit', 'Plan', 'Install', 'Update', 'Repair', 'Run')]
    [string]$Command = 'List',

    [string]$TargetRoot,

    [ValidateSet('ubuntu-web', 'chess', 'sound-profile')]
    [string]$Profile,

    [switch]$Force,

    [switch]$ReplaceConfig,

    [switch]$CompareSources,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CiArguments
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:BootstrapRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:ProfilesRoot = Join-Path $script:BootstrapRoot 'profiles'
$script:StateRoot = Join-Path $script:BootstrapRoot 'state'
$script:TransactionsRoot = Join-Path $script:StateRoot 'transactions'
$script:LocksRoot = Join-Path $script:StateRoot 'locks'
$script:ProjectsRoot = Join-Path $script:StateRoot 'projects'
$script:BackupsRoot = Join-Path $script:BootstrapRoot 'backups'
$script:CentralManifestPath = Join-Path $script:BootstrapRoot 'bootstrap.manifest.json'
$script:RuntimeSchema = 'workflow-bootstrap-runtime/v1'
$script:ProfileSchema = 'workflow-bootstrap-profile/v1'
$script:CentralReleaseRecords = $null
$script:AtomicCleanupIssues = [Collections.Generic.List[object]]::new()
$script:LegacyMutablePaths = @(
    '.ci/ci.config.json',
    'README.md',
    'Roadmap.md',
    'Roadmap_archive.md',
    'Roadmap_index.md',
    'todo.events.jsonl',
    'todo.state.json',
    'todo.current.md',
    'todo.master.index.json',
    'todo.history.digest.json',
    'todo.checkpoint.json',
    'handoff.latest.json',
    'handoff.latest.md'
)

function ConvertTo-RelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $normalized = $Path.Replace('\', '/').Trim()
    if (-not $normalized -or [IO.Path]::IsPathRooted($normalized)) {
        throw "Pfad ist nicht relativ: $Path"
    }
    if ($normalized -match '(^|/)\.\.(/|$)' -or $normalized -match '^[^/]+:') {
        throw "Pfad ist nicht erlaubt: $Path"
    }
    if ($IsWindows) {
        foreach ($segment in $normalized.Split('/')) {
            $baseName = [IO.Path]::GetFileNameWithoutExtension($segment)
            if ($segment.Contains(':') -or $segment -match '[. ]$' -or
                $baseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
                throw "Windows-Pfadsegment ist nicht erlaubt: $segment"
            }
        }
    }
    return $normalized.TrimStart('/')
}

function Resolve-ContainedPath {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $relative = ConvertTo-RelativePath $RelativePath
    $baseFull = [IO.Path]::GetFullPath($BasePath)
    $baseRoot = [IO.Path]::GetPathRoot($baseFull)
    $comparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    $base = if ($baseFull.Equals($baseRoot, $comparison)) {
        $baseRoot
    }
    else {
        $baseFull.TrimEnd([char[]]@('\', '/'))
    }
    $candidate = [IO.Path]::GetFullPath((Join-Path $base $relative))
    $prefix = if ($base.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $base
    }
    else {
        $base + [IO.Path]::DirectorySeparatorChar
    }
    if (-not $candidate.StartsWith($prefix, $comparison)) {
        throw "Pfad verlaesst den erlaubten Bereich: $RelativePath"
    }
    return $candidate
}

function Test-ContainsReparsePoint {
    param([Parameter(Mandatory)][string]$Path)

    $candidate = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($candidate)
    $current = $root
    foreach ($segment in $candidate.Substring($root.Length).Split(
            [char[]]@('\', '/'),
            [StringSplitOptions]::RemoveEmptyEntries
        )) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { continue }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $true
        }
    }
    return $false
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return -join ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ProjectId {
    param([Parameter(Mandatory)][string]$ResolvedTargetRoot)

    $normalized = if ($IsWindows) {
        $ResolvedTargetRoot.ToLowerInvariant()
    }
    else {
        $ResolvedTargetRoot
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($normalized)
    return (Get-BytesSha256 $bytes).Substring(0, 24)
}

function Write-BytesAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $temporary = "$Path.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
    $backup = "$Path.bak.$PID.$([Guid]::NewGuid().ToString('N'))"
    $existed = Test-Path -LiteralPath $Path -PathType Leaf
    $wasReadOnly = $false
    if ($existed) { $wasReadOnly = (Get-Item -LiteralPath $Path -Force).IsReadOnly }
    $published = $false
    try {
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            $stream.Write($Bytes, 0, $Bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }

        if ($existed) {
            $destination = Get-Item -LiteralPath $Path -Force
            if ($destination.IsReadOnly) { $destination.IsReadOnly = $false }
            [IO.File]::Replace($temporary, $Path, $backup)
        }
        else {
            [IO.File]::Move($temporary, $Path)
        }
        if ((Get-BytesSha256 $Bytes) -ne (Get-Sha256 $Path)) {
            throw "Atomare Publikation konnte nicht verifiziert werden: $Path"
        }
        if ($existed) { (Get-Item -LiteralPath $Path -Force).IsReadOnly = $wasReadOnly }
        $published = $true
    }
    catch {
        $publishError = $_
        $recoveryErrors = [Collections.Generic.List[string]]::new()
        if (Test-Path -LiteralPath $backup -PathType Leaf) {
            if (Test-Path -LiteralPath $Path -PathType Leaf) {
                $failed = "$Path.failed.$PID.$([Guid]::NewGuid().ToString('N'))"
                try {
                    $destination = Get-Item -LiteralPath $Path -Force
                    if ($destination.IsReadOnly) { $destination.IsReadOnly = $false }
                    [IO.File]::Replace($backup, $Path, $failed)
                }
                catch {
                    $recoveryErrors.Add("Inhalt konnte nicht aus internem Backup restauriert werden: $($_.Exception.Message)")
                }
                if (Test-Path -LiteralPath $failed -PathType Leaf) {
                    try { Remove-Item -LiteralPath $failed -Force }
                    catch { $recoveryErrors.Add("Fehlgeschlagene Ersatzdatei konnte nicht entfernt werden: $($_.Exception.Message)") }
                }
            }
            else {
                try { [IO.File]::Move($backup, $Path) }
                catch { $recoveryErrors.Add("Internes Backup konnte nicht zurueckverschoben werden: $($_.Exception.Message)") }
            }
        }
        elseif (-not $existed -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            try { Remove-Item -LiteralPath $Path -Force }
            catch { $recoveryErrors.Add("Neu publizierte Datei konnte nicht entfernt werden: $($_.Exception.Message)") }
        }
        if ($existed -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            try { (Get-Item -LiteralPath $Path -Force).IsReadOnly = $wasReadOnly }
            catch { $recoveryErrors.Add("ReadOnly-Attribut konnte nicht restauriert werden: $($_.Exception.Message)") }
        }
        if ($recoveryErrors.Count -gt 0) {
            throw "Atomare Publikation fehlgeschlagen: $($publishError.Exception.Message). Interne Rollbackfehler: $($recoveryErrors -join ' | ')"
        }
        throw $publishError
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            try { Remove-Item -LiteralPath $temporary -Force }
            catch {
                $script:AtomicCleanupIssues.Add([pscustomobject]@{
                        kind = 'temporary'
                        path = $temporary
                        message = $_.Exception.Message
                    })
            }
        }
        if ($published -and (Test-Path -LiteralPath $backup -PathType Leaf)) {
            try { Remove-Item -LiteralPath $backup -Force }
            catch {
                $script:AtomicCleanupIssues.Add([pscustomobject]@{
                        kind = 'backup'
                        path = $backup
                        message = $_.Exception.Message
                    })
            }
        }
    }
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 40
    Write-BytesAtomic -Path $Path -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($json + "`n"))
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        throw "JSON ist unlesbar ($Path): $($_.Exception.Message)"
    }
}

function Assert-CentralPackage {
    if (-not (Test-Path -LiteralPath $script:CentralManifestPath -PathType Leaf)) {
        throw "Zentrales Release-Manifest fehlt: $script:CentralManifestPath"
    }
    $manifest = Read-JsonFile $script:CentralManifestPath
    if ([string]$manifest.schema -ne 'workflow-bootstrap-release/v1') {
        throw "Unbekanntes zentrales Release-Schema: $($manifest.schema)"
    }
    if ([string]$manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "Ungueltige zentrale Release-Version: $($manifest.version)"
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $records = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($manifest.files)) {
        $relative = ConvertTo-RelativePath ([string]$record.path)
        if (-not $seen.Add($relative)) { throw "Doppelter zentraler Release-Pfad: $relative" }
        $expected = ([string]$record.sha256).ToLowerInvariant()
        if ($expected -notmatch '^[a-f0-9]{64}$') { throw "Ungueltiger Release-Hash: $relative" }
        $path = Resolve-ContainedPath -BasePath $script:BootstrapRoot -RelativePath $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Release-Datei fehlt: $relative" }
        if (Test-ContainsReparsePoint $path) { throw "Reparse Point im zentralen Release: $relative" }
        if ((Get-Item -LiteralPath $path -Force).Length -ne [long]$record.size) {
            throw "Release-Groesse stimmt nicht: $relative"
        }
        if ((Get-Sha256 $path) -ne $expected) { throw "Release-Hash stimmt nicht: $relative" }
        if ($IsWindows) {
            $alternateStreams = @(Get-Item -LiteralPath $path -Stream * -ErrorAction SilentlyContinue |
                    Where-Object Stream -ne ':$DATA')
            if ($alternateStreams.Count -gt 0) { throw "Alternate Data Stream im zentralen Release: $relative" }
        }
        $records[$relative] = $record
    }
    foreach ($required in @(
            'Bootstrap.ps1',
            'bootstrap.cmd',
            'Run.ps1',
            'run.cmd',
            'runtime/ci.ps1',
            'runtime/ci.cmd',
            'runtime/root-ci.cmd',
            'runtime/observer-daemon.ps1',
            'runtime/workflow-audit.ps1',
            'catalog/compatibility.json',
            'profiles/ubuntu-web/profile.json',
            'profiles/chess/profile.json',
            'profiles/sound-profile/profile.json'
        )) {
        if (-not $seen.Contains($required)) { throw "Zentrales Release ist unvollstaendig: $required" }
    }
    $script:CentralReleaseRecords = $records
    return $manifest
}

function Get-CentralReleaseRecord {
    param([Parameter(Mandatory)][string]$RelativePath)

    $relative = ConvertTo-RelativePath $RelativePath
    if ($null -eq $script:CentralReleaseRecords -or -not $script:CentralReleaseRecords.ContainsKey($relative)) {
        throw "Datei ist nicht Teil des verifizierten zentralen Releases: $relative"
    }
    return $script:CentralReleaseRecords[$relative]
}

function Get-ProfileManifest {
    param([Parameter(Mandatory)][string]$ProfileId)

    $profileRoot = Resolve-ContainedPath -BasePath $script:ProfilesRoot -RelativePath $ProfileId
    $manifestPath = Join-Path $profileRoot 'profile.json'
    $profileManifestRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $manifestPath).Replace('\', '/')
    $null = Get-CentralReleaseRecord $profileManifestRelative
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Profil existiert nicht: $ProfileId"
    }
    $manifest = Read-JsonFile $manifestPath
    if ([string]$manifest.schema -ne $script:ProfileSchema -or [string]$manifest.id -ne $ProfileId) {
        throw "Profilmanifest ist ungueltig: $manifestPath"
    }
    if ([string]$manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "Profilversion ist ungueltig: $($manifest.version)"
    }

    $destinations = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($manifest.payload)) {
        $sourceRelative = ConvertTo-RelativePath ([string]$record.source)
        $destination = ConvertTo-RelativePath ([string]$record.destination)
        if (-not $destinations.Add($destination)) { throw "Doppeltes Profilziel: $destination" }
        if (-not $destination.StartsWith('.ci/bin/', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Profilpayload darf nur .ci/bin verwalten: $destination"
        }
        $source = Resolve-ContainedPath -BasePath $profileRoot -RelativePath $sourceRelative
        $centralRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $source).Replace('\', '/')
        $null = Get-CentralReleaseRecord $centralRelative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Profildatei fehlt: $sourceRelative" }
        if (Test-ContainsReparsePoint $source) { throw "Reparse Point im Profil: $sourceRelative" }
        if ((Get-Sha256 $source) -ne ([string]$record.sha256).ToLowerInvariant()) {
            throw "Profilhash stimmt nicht: $sourceRelative"
        }
        if ((Get-Item -LiteralPath $source -Force).Length -ne [long]$record.size) {
            throw "Profilgroesse stimmt nicht: $sourceRelative"
        }
        if ([IO.Path]::GetExtension($source) -eq '.ps1') {
            $tokens = $null
            $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
            if (@($parseErrors).Count -gt 0) {
                throw "PowerShell-Parsefehler im Profil: $sourceRelative"
            }
        }
    }
    foreach ($reference in @($manifest.default_config, $manifest.function_catalog, $manifest.command_catalog)) {
        $referencedPath = Resolve-ContainedPath -BasePath $profileRoot -RelativePath ([string]$reference)
        $centralRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $referencedPath).Replace('\', '/')
        $null = Get-CentralReleaseRecord $centralRelative
    }

    return [pscustomobject]@{
        Root = $profileRoot
        Manifest = $manifest
    }
}

function New-Mapping {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$SourceRelative,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Role
    )

    $releaseRecord = Get-CentralReleaseRecord $SourceRelative
    return [pscustomobject]@{
        Source = [IO.Path]::GetFullPath($Source)
        SourceRelative = (ConvertTo-RelativePath $SourceRelative)
        Destination = (ConvertTo-RelativePath $Destination)
        Role = $Role
        Hash = ([string]$releaseRecord.sha256).ToLowerInvariant()
        Size = [long]$releaseRecord.size
    }
}

function Get-ExpectedMappings {
    param([Parameter(Mandatory)]$ProfilePackage)

    $mappings = [Collections.Generic.List[object]]::new()
    $common = @(
        @{ source = 'runtime/ci.ps1'; destination = '.ci/bin/ci.ps1'; role = 'trusted-loader' },
        @{ source = 'runtime/ci.cmd'; destination = '.ci/bin/ci.cmd'; role = 'launcher' },
        @{ source = 'runtime/root-ci.cmd'; destination = 'ci.cmd'; role = 'launcher' },
        @{ source = 'runtime/observer-daemon.ps1'; destination = '.ci/tools/observer-daemon.ps1'; role = 'bootstrap-module' },
        @{ source = 'runtime/workflow-audit.ps1'; destination = '.ci/bootstrap/modules/workflow-audit.ps1'; role = 'bootstrap-module' },
        @{ source = 'catalog/compatibility.json'; destination = '.ci/bootstrap/catalog/compatibility.json'; role = 'catalog' }
    )
    foreach ($item in $common) {
        $source = Resolve-ContainedPath -BasePath $script:BootstrapRoot -RelativePath $item.source
        $mappings.Add((New-Mapping -Source $source -SourceRelative $item.source -Destination $item.destination -Role $item.role))
    }

    foreach ($schema in @(Get-ChildItem -LiteralPath (Join-Path $script:BootstrapRoot 'schemas') -Filter '*.json' -File | Sort-Object Name)) {
        $sourceRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $schema.FullName).Replace('\', '/')
        $destination = '.ci/bootstrap/schemas/' + $schema.Name
        $mappings.Add((New-Mapping -Source $schema.FullName -SourceRelative $sourceRelative -Destination $destination -Role 'catalog'))
    }

    $profileManifest = $ProfilePackage.Manifest
    foreach ($record in @($profileManifest.payload)) {
        $source = Resolve-ContainedPath -BasePath $ProfilePackage.Root -RelativePath ([string]$record.source)
        $sourceRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $source).Replace('\', '/')
        $mappings.Add((New-Mapping -Source $source -SourceRelative $sourceRelative -Destination ([string]$record.destination) -Role ([string]$record.role)))
    }

    $catalogMappings = @(
        @{ source = [string]$profileManifest.command_catalog; destination = '.ci/bootstrap/catalog/commands.json' },
        @{ source = [string]$profileManifest.function_catalog; destination = '.ci/bootstrap/catalog/functions.json' }
    )
    foreach ($item in $catalogMappings) {
        $source = Resolve-ContainedPath -BasePath $ProfilePackage.Root -RelativePath $item.source
        $sourceRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $source).Replace('\', '/')
        $mappings.Add((New-Mapping -Source $source -SourceRelative $sourceRelative -Destination $item.destination -Role 'catalog'))
    }

    $destinations = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($mapping in $mappings) {
        if (-not $destinations.Add($mapping.Destination)) {
            throw "Doppeltes Installationsziel: $($mapping.Destination)"
        }
    }
    return @($mappings | Sort-Object Destination)
}

function Resolve-TargetRoot {
    if ([string]::IsNullOrWhiteSpace($TargetRoot)) {
        throw "Command $Command erfordert -TargetRoot."
    }
    $resolved = [IO.Path]::GetFullPath($TargetRoot)
    $pathRoot = [IO.Path]::GetPathRoot($resolved)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $resolved.Equals($pathRoot, $comparison)) {
        $resolved = $resolved.TrimEnd([char[]]@('\', '/'))
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Projektverzeichnis existiert nicht: $resolved"
    }
    if (Test-ContainsReparsePoint $resolved) {
        throw "Projektpfad enthaelt einen Reparse Point: $resolved"
    }
    $bootstrapPrefix = $script:BootstrapRoot.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
    if ($resolved.Equals($script:BootstrapRoot, $comparison) -or $resolved.StartsWith($bootstrapPrefix, $comparison)) {
        throw 'Bootstrap darf nicht in sich selbst installiert werden.'
    }
    return $resolved
}

function Get-BindingPath {
    param([Parameter(Mandatory)][string]$ResolvedTargetRoot)

    return Join-Path $script:ProjectsRoot ((Get-ProjectId $ResolvedTargetRoot) + '.json')
}

function Read-ProjectBinding {
    param([Parameter(Mandatory)][string]$ResolvedTargetRoot)

    $path = Get-BindingPath $ResolvedTargetRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $binding = Read-JsonFile $path
    if ([string]$binding.schema -ne 'workflow-bootstrap-project-binding/v1') {
        throw "Projektbindung hat ein unbekanntes Schema: $path"
    }
    if (Test-ContainsReparsePoint $path) {
        throw "Projektbindung liegt auf einem Reparse Point: $path"
    }
    if (-not ([IO.Path]::GetFullPath([string]$binding.target_root)).Equals(
            $ResolvedTargetRoot,
            $(if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal })
        )) {
        throw "Projektbindung passt nicht zum Zielpfad: $path"
    }
    if ([string]$binding.project_id -ne (Get-ProjectId $ResolvedTargetRoot)) {
        throw "Projekt-ID der Bindung passt nicht zum Zielpfad: $path"
    }
    if ([string]$binding.profile -notin @('ubuntu-web', 'chess', 'sound-profile')) {
        throw "Projektbindung enthaelt ein unbekanntes Profil: $($binding.profile)"
    }
    if ([string]$binding.profile_version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "Projektbindung enthaelt eine ungueltige Profilversion: $($binding.profile_version)"
    }
    if ([string]$binding.target_manifest_sha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Projektbindung enthaelt keinen gueltigen Runtime-Manifest-Hash.'
    }
    return $binding
}

function Get-LegacyPinReport {
    param([Parameter(Mandatory)][string]$ResolvedTargetRoot)

    $pinsPath = Join-Path $ResolvedTargetRoot '.ci\pins\immutable.hashes.json'
    $report = [ordered]@{
        status = 'none'
        path = '.ci/pins/immutable.hashes.json'
        pinned_files = 0
        readonly_mutable_files = @()
        issues = @()
    }
    if (-not (Test-Path -LiteralPath $pinsPath -PathType Leaf)) { return $report }
    if (Test-ContainsReparsePoint $pinsPath) {
        $report.status = 'invalid'
        $report.issues = @('legacy_pin_manifest_reparse_point')
        return $report
    }

    try {
        $pins = Read-JsonFile $pinsPath
        $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($relative in $script:LegacyMutablePaths) { $null = $allowed.Add($relative) }
        $readonly = [Collections.Generic.List[string]]::new()
        $records = @($pins.files)
        foreach ($record in $records) {
            $relative = ConvertTo-RelativePath ([string]$record.path)
            $path = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $relative
            if (Test-ContainsReparsePoint $path) { throw "Legacy-Pin zeigt auf einen Reparse Point: $relative" }
            if ($allowed.Contains($relative) -and (Test-Path -LiteralPath $path -PathType Leaf) -and
                (Get-Item -LiteralPath $path -Force).IsReadOnly) {
                $readonly.Add($relative)
            }
        }
        $report.status = 'valid'
        $report.pinned_files = $records.Count
        $report.readonly_mutable_files = @($readonly | Sort-Object -Unique)
    }
    catch {
        $report.status = 'invalid'
        $report.issues = @($_.Exception.Message)
    }
    return $report
}

function Get-TargetIssues {
    param(
        [Parameter(Mandatory)][string]$ResolvedTargetRoot,
        [Parameter(Mandatory)][object[]]$Mappings,
        $Binding
    )

    $issues = [Collections.Generic.List[string]]::new()
    $expected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($mapping in $Mappings) {
        $null = $expected.Add($mapping.Destination)
        $destination = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $mapping.Destination
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            $issues.Add("missing:$($mapping.Destination)")
            continue
        }
        if (Test-ContainsReparsePoint $destination) {
            $issues.Add("reparse_point:$($mapping.Destination)")
            continue
        }
        if ((Get-Item -LiteralPath $destination -Force).Length -ne $mapping.Size) {
            $issues.Add("size_mismatch:$($mapping.Destination)")
            continue
        }
        if ((Get-Sha256 $destination) -ne $mapping.Hash) {
            $issues.Add("hash_mismatch:$($mapping.Destination)")
        }
        if ($IsWindows) {
            $alternateStreams = @(Get-Item -LiteralPath $destination -Stream * -ErrorAction SilentlyContinue |
                    Where-Object Stream -ne ':$DATA')
            if ($alternateStreams.Count -gt 0) {
                $issues.Add("alternate_data_stream:$($mapping.Destination)")
            }
        }
    }

    $binRoot = Join-Path $ResolvedTargetRoot '.ci\bin'
    if (Test-Path -LiteralPath $binRoot -PathType Container) {
        foreach ($item in @(Get-ChildItem -LiteralPath $binRoot -Recurse -Force)) {
            $relative = [IO.Path]::GetRelativePath($ResolvedTargetRoot, $item.FullName).Replace('\', '/')
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $issues.Add("reparse_point:$relative")
            }
            if (-not $item.PSIsContainer -and -not $expected.Contains($relative)) {
                $issues.Add("unexpected_bin_file:$relative")
            }
        }
    }
    $toolsRoot = Join-Path $ResolvedTargetRoot '.ci\tools'
    if (Test-Path -LiteralPath $toolsRoot -PathType Container) {
        $scriptExtensions = @('.ps1', '.psm1', '.psd1', '.cmd', '.bat')
        foreach ($file in @(Get-ChildItem -LiteralPath $toolsRoot -File -Force)) {
            $relative = [IO.Path]::GetRelativePath($ResolvedTargetRoot, $file.FullName).Replace('\', '/')
            if ($file.Extension -in $scriptExtensions -and -not $expected.Contains($relative)) {
                $issues.Add("unexpected_tool_script:$relative")
            }
        }
    }
    if ($null -ne $Binding) {
        $targetManifestPath = Join-Path $ResolvedTargetRoot '.ci\bootstrap\runtime.manifest.json'
        if (-not (Test-Path -LiteralPath $targetManifestPath -PathType Leaf)) {
            $issues.Add('missing:.ci/bootstrap/runtime.manifest.json')
        }
        elseif (Test-ContainsReparsePoint $targetManifestPath) {
            $issues.Add('reparse_point:.ci/bootstrap/runtime.manifest.json')
        }
        elseif ((Get-Sha256 $targetManifestPath) -ne ([string]$Binding.target_manifest_sha256).ToLowerInvariant()) {
            $issues.Add('hash_mismatch:.ci/bootstrap/runtime.manifest.json')
        }
        else {
            try {
                $targetManifest = Read-JsonFile $targetManifestPath
                if ([string]$targetManifest.schema -ne $script:RuntimeSchema) {
                    $issues.Add('schema_mismatch:.ci/bootstrap/runtime.manifest.json')
                }
                if ([string]$targetManifest.profile -ne [string]$Binding.profile -or
                    [string]$targetManifest.profile_version -ne [string]$Binding.profile_version) {
                    $issues.Add('binding_mismatch:.ci/bootstrap/runtime.manifest.json')
                }
            }
            catch {
                $issues.Add('invalid_json:.ci/bootstrap/runtime.manifest.json')
            }
        }
    }
    return @($issues | Sort-Object -Unique)
}

function Get-PlanReport {
    param(
        [Parameter(Mandatory)][string]$ResolvedTargetRoot,
        [Parameter(Mandatory)][object[]]$Mappings,
        [Parameter(Mandatory)]$ProfilePackage
    )

    $changes = foreach ($mapping in $Mappings) {
        $destination = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $mapping.Destination
        $status = if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            'create'
        }
        elseif ((Get-Sha256 $destination) -eq $mapping.Hash) {
            'unchanged'
        }
        else {
            'replace'
        }
        [ordered]@{
            path = $mapping.Destination
            status = $status
            role = $mapping.Role
            sha256 = $mapping.Hash
        }
    }

    $configSource = Resolve-ContainedPath -BasePath $ProfilePackage.Root -RelativePath ([string]$ProfilePackage.Manifest.default_config)
    $configDestination = Join-Path $ResolvedTargetRoot '.ci\ci.config.json'
    $configStatus = if (-not (Test-Path -LiteralPath $configDestination -PathType Leaf)) {
        'create'
    }
    elseif ($ReplaceConfig) {
        if ((Get-Sha256 $configDestination) -eq (Get-Sha256 $configSource)) { 'unchanged' } else { 'replace-explicit' }
    }
    else {
        'preserve-mutable'
    }

    return [ordered]@{
        schema = 'workflow-bootstrap-plan/v1'
        target_root = $ResolvedTargetRoot
        profile = [string]$ProfilePackage.Manifest.id
        version = [string]$ProfilePackage.Manifest.version
        creates = @($changes | Where-Object status -eq 'create').Count
        replacements = @($changes | Where-Object status -like 'replace*').Count
        unchanged = @($changes | Where-Object status -eq 'unchanged').Count
        config = $configStatus
        legacy_pin_migration = Get-LegacyPinReport $ResolvedTargetRoot
        changes = @($changes)
    }
}

function New-TargetManifest {
    param(
        [Parameter(Mandatory)]$ProfilePackage,
        [Parameter(Mandatory)][object[]]$Mappings
    )

    return [ordered]@{
        schema = $script:RuntimeSchema
        profile = [string]$ProfilePackage.Manifest.id
        profile_version = [string]$ProfilePackage.Manifest.version
        installed_utc = [DateTimeOffset]::UtcNow.ToString('o')
        minimum_pwsh = '7.4'
        entrypoint = '.ci/bin/legacy-ci.ps1'
        command_catalog = '.ci/bootstrap/catalog/commands.json'
        workflow_audit_module = '.ci/bootstrap/modules/workflow-audit.ps1'
        mutable_paths = @(
            '.ci/ci.config.json',
            'README.md',
            'Roadmap.md',
            'Roadmap_archive.md',
            'Roadmap_index.md',
            'todo.events.jsonl',
            'todo.state.json',
            'todo.current.md',
            'todo.master.index.json',
            'todo.history.digest.json',
            'todo.checkpoint.json',
            'handoff.latest.json',
            'handoff.latest.md',
            'logs'
        )
        files = @($Mappings | ForEach-Object {
                [ordered]@{
                    path = $_.Destination
                    sha256 = $_.Hash
                    size = [long]$_.Size
                    role = $_.Role
                    source = $_.SourceRelative
                }
            })
    }
}

function Remove-ValidatedTransactionDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedTransactions = [IO.Path]::GetFullPath($script:TransactionsRoot).TrimEnd([char[]]@('\', '/'))
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $resolvedPath.StartsWith($resolvedTransactions + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw "Transaktionspfad ist nicht loeschbar: $resolvedPath"
    }
    if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }
}

function Publish-Profile {
    param(
        [Parameter(Mandatory)][string]$ResolvedTargetRoot,
        [Parameter(Mandatory)]$ProfilePackage,
        [Parameter(Mandatory)][object[]]$Mappings,
        [Parameter(Mandatory)][string]$Operation
    )

    $plan = Get-PlanReport -ResolvedTargetRoot $ResolvedTargetRoot -Mappings $Mappings -ProfilePackage $ProfilePackage
    if ($Operation -eq 'Install' -and -not $Force) {
        foreach ($mapping in $Mappings) {
            $destination = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $mapping.Destination
            if ((Test-Path -LiteralPath $destination -PathType Leaf) -and (Get-Sha256 $destination) -ne $mapping.Hash) {
                throw "Bestehende abweichende Datei erfordert -Force: $($mapping.Destination)"
            }
        }
    }
    if (-not $PSCmdlet.ShouldProcess($ResolvedTargetRoot, "$Operation Profil $($ProfilePackage.Manifest.id) $($ProfilePackage.Manifest.version)")) {
        $plan | ConvertTo-Json -Depth 10
        return
    }

    $lock = Enter-ProjectLock $ResolvedTargetRoot
    try {
    $currentBinding = Read-ProjectBinding $ResolvedTargetRoot
    if ($Operation -eq 'Install' -and $null -ne $currentBinding) {
        throw 'Das Projekt wurde parallel gebunden. Install wird abgebrochen; Update oder Repair verwenden.'
    }
    if ($Operation -in @('Update', 'Repair') -and $null -eq $currentBinding) {
        throw "$Operation erfordert eine bestehende zentrale Projektbindung."
    }
    if ($Operation -eq 'Repair' -and [string]$currentBinding.profile -ne [string]$ProfilePackage.Manifest.id) {
        throw 'Repair darf das gebundene Profil nicht wechseln.'
    }
    if ($Operation -eq 'Update' -and [string]$currentBinding.profile -ne [string]$ProfilePackage.Manifest.id -and -not $Force) {
        throw 'Profilwechsel per Update erfordert -Force.'
    }

    $profileManifestPath = Join-Path $ProfilePackage.Root 'profile.json'
    $profileManifestRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $profileManifestPath).Replace('\', '/')
    $profileManifestRecord = Get-CentralReleaseRecord $profileManifestRelative
    if ((Get-Sha256 $profileManifestPath) -ne ([string]$profileManifestRecord.sha256).ToLowerInvariant()) {
        throw "Profilmanifest wurde waehrend der Transaktion geaendert: $profileManifestRelative"
    }

    $legacyPinReport = Get-LegacyPinReport $ResolvedTargetRoot
    if ([string]$legacyPinReport.status -eq 'invalid') {
        throw "Legacy-Pin-Migration ist nicht sicher moeglich: $(@($legacyPinReport.issues) -join ' | ')"
    }

    foreach ($mapping in $Mappings) {
        $destination = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $mapping.Destination
        if (Test-ContainsReparsePoint $destination) {
            throw "Schreibziel enthaelt einen Reparse Point: $($mapping.Destination)"
        }
        if ($Operation -eq 'Install' -and -not $Force -and
            (Test-Path -LiteralPath $destination -PathType Leaf) -and
            (Get-Sha256 $destination) -ne $mapping.Hash) {
            throw "Bestehende abweichende Datei erfordert -Force: $($mapping.Destination)"
        }
    }
    $projectId = Get-ProjectId $ResolvedTargetRoot
    $transactionId = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N')
    $transactionRoot = Join-Path $script:TransactionsRoot $transactionId
    $stagingRoot = Join-Path $transactionRoot 'staging'
    $backupRoot = Join-Path $script:BackupsRoot (Join-Path $projectId $transactionId)
    [IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    [IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    if ([string]$legacyPinReport.status -eq 'valid') {
        $legacyPinsSource = Join-Path $ResolvedTargetRoot '.ci\pins\immutable.hashes.json'
        $legacyPinsBackup = Join-Path $backupRoot 'legacy-pins\immutable.hashes.json'
        [IO.Directory]::CreateDirectory((Split-Path -Parent $legacyPinsBackup)) | Out-Null
        [IO.File]::Copy($legacyPinsSource, $legacyPinsBackup, $true)
    }

    $publishItems = [Collections.Generic.List[object]]::new()
    $managedAttributeStates = [Collections.Generic.List[object]]::new()
    foreach ($mapping in $Mappings) {
        $destination = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath $mapping.Destination
        $existed = Test-Path -LiteralPath $destination -PathType Leaf
        $wasReadOnly = $existed -and (Get-Item -LiteralPath $destination -Force).IsReadOnly
        $managedAttributeStates.Add([pscustomobject]@{
                RelativePath = [string]$mapping.Destination
                Destination = $destination
                Existed = $existed
                WasReadOnly = $wasReadOnly
            })
        $matches = $existed -and ((Get-Sha256 $destination) -eq $mapping.Hash)
        if ($matches) { continue }

        $stage = Resolve-ContainedPath -BasePath $stagingRoot -RelativePath $mapping.Destination
        [IO.Directory]::CreateDirectory((Split-Path -Parent $stage)) | Out-Null
        [IO.File]::Copy($mapping.Source, $stage, $true)
        if ((Get-Sha256 $stage) -ne $mapping.Hash) { throw "Staging-Hash stimmt nicht: $($mapping.Destination)" }

        $backup = Resolve-ContainedPath -BasePath $backupRoot -RelativePath $mapping.Destination
        if ($existed) {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $backup)) | Out-Null
            [IO.File]::Copy($destination, $backup, $true)
        }
        $publishItems.Add([pscustomobject]@{
                Mapping = $mapping
                Stage = $stage
                Destination = $destination
                Backup = $backup
                Existed = $existed
                WasReadOnly = $wasReadOnly
            })
    }

    $configSource = Resolve-ContainedPath -BasePath $ProfilePackage.Root -RelativePath ([string]$ProfilePackage.Manifest.default_config)
    $configDestination = Join-Path $ResolvedTargetRoot '.ci\ci.config.json'
    if (Test-ContainsReparsePoint $configDestination) { throw 'Schreibziel enthaelt einen Reparse Point: .ci/ci.config.json' }
    if (Test-Path -LiteralPath $configDestination -PathType Leaf) { $null = Read-JsonFile $configDestination }
    $publishConfig = (-not (Test-Path -LiteralPath $configDestination -PathType Leaf)) -or $ReplaceConfig
    $configBackup = Join-Path $backupRoot '.ci\ci.config.json'
    $configExisted = Test-Path -LiteralPath $configDestination -PathType Leaf
    if ($publishConfig -and $configExisted) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $configBackup)) | Out-Null
        [IO.File]::Copy($configDestination, $configBackup, $true)
    }
    $configStage = Join-Path $stagingRoot '.ci\ci.config.json'
    if ($publishConfig) {
        $configRelative = [IO.Path]::GetRelativePath($script:BootstrapRoot, $configSource).Replace('\', '/')
        $configRecord = Get-CentralReleaseRecord $configRelative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $configStage)) | Out-Null
        [IO.File]::Copy($configSource, $configStage, $true)
        if ((Get-Item -LiteralPath $configStage -Force).Length -ne [long]$configRecord.size -or
            (Get-Sha256 $configStage) -ne ([string]$configRecord.sha256).ToLowerInvariant()) {
            throw "Staging-Hash der Standardkonfiguration stimmt nicht: $configRelative"
        }
        $null = Read-JsonFile $configStage
    }

    $targetManifestPath = Join-Path $ResolvedTargetRoot '.ci\bootstrap\runtime.manifest.json'
    if (Test-ContainsReparsePoint $targetManifestPath) { throw 'Schreibziel enthaelt einen Reparse Point: .ci/bootstrap/runtime.manifest.json' }
    $targetManifestBackup = Join-Path $backupRoot 'metadata\runtime.manifest.json'
    $targetManifestExisted = Test-Path -LiteralPath $targetManifestPath -PathType Leaf
    if ($targetManifestExisted) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $targetManifestBackup)) | Out-Null
        [IO.File]::Copy($targetManifestPath, $targetManifestBackup, $true)
    }
    $bindingPath = Get-BindingPath $ResolvedTargetRoot
    $bindingBackup = Join-Path $backupRoot 'metadata\project-binding.json'
    $bindingExisted = Test-Path -LiteralPath $bindingPath -PathType Leaf
    if ($bindingExisted) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $bindingBackup)) | Out-Null
        [IO.File]::Copy($bindingPath, $bindingBackup, $true)
    }

    $published = [Collections.Generic.List[object]]::new()
    $legacyAttributesChanged = [Collections.Generic.List[string]]::new()
    $targetManifestPublished = $false
    $bindingPublished = $false
    $atomicCleanupIssueStart = $script:AtomicCleanupIssues.Count
    try {
        foreach ($item in $publishItems) {
            Write-BytesAtomic -Path $item.Destination -Bytes ([IO.File]::ReadAllBytes($item.Stage))
            $published.Add($item)
        }
        if ($publishConfig) {
            Write-BytesAtomic -Path $configDestination -Bytes ([IO.File]::ReadAllBytes($configStage))
        }

        $targetManifest = New-TargetManifest -ProfilePackage $ProfilePackage -Mappings $Mappings
        Write-JsonAtomic -Path $targetManifestPath -Value $targetManifest
        $targetManifestPublished = $true
        $targetManifestHash = Get-Sha256 $targetManifestPath

        $binding = [ordered]@{
            schema = 'workflow-bootstrap-project-binding/v1'
            project_id = $projectId
            target_root = $ResolvedTargetRoot
            profile = [string]$ProfilePackage.Manifest.id
            profile_version = [string]$ProfilePackage.Manifest.version
            installed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            target_manifest_sha256 = $targetManifestHash
            backup_root = $backupRoot
        }
        [IO.Directory]::CreateDirectory($script:ProjectsRoot) | Out-Null
        Write-JsonAtomic -Path $bindingPath -Value $binding
        $bindingPublished = $true

        $commitCleanupIssues = @($script:AtomicCleanupIssues | Select-Object -Skip $atomicCleanupIssueStart)
        if ($commitCleanupIssues.Count -gt 0) {
            throw "Atomarer Datei-Cleanup ist unvollstaendig: $(@($commitCleanupIssues.path) -join ', ')"
        }

        $issues = @(Get-TargetIssues -ResolvedTargetRoot $ResolvedTargetRoot -Mappings $Mappings -Binding $binding)
        if ($issues.Count -gt 0) { throw "Zielverifikation fehlgeschlagen: $($issues -join ', ')" }

        foreach ($state in $managedAttributeStates) {
            $destinationItem = Get-Item -LiteralPath $state.Destination -Force
            $destinationItem.IsReadOnly = $true
            if (-not (Get-Item -LiteralPath $state.Destination -Force).IsReadOnly) {
                throw "ReadOnly-Attribut konnte nicht gesetzt werden: $($state.RelativePath)"
            }
        }
        foreach ($relative in @($legacyPinReport.readonly_mutable_files)) {
            $mutablePath = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath ([string]$relative)
            $mutableItem = Get-Item -LiteralPath $mutablePath -Force
            if ($mutableItem.IsReadOnly) {
                $mutableItem.IsReadOnly = $false
                $legacyAttributesChanged.Add([string]$relative)
            }
        }
        Remove-ValidatedTransactionDirectory $transactionRoot
        [pscustomobject]@{
            status = 'ok'
            operation = $Operation
            target_root = $ResolvedTargetRoot
            profile = [string]$ProfilePackage.Manifest.id
            version = [string]$ProfilePackage.Manifest.version
            changed_files = $publishItems.Count
            config = $plan.config
            legacy_readonly_released = $legacyAttributesChanged.Count
            backup_root = $backupRoot
        } | ConvertTo-Json -Depth 6
    }
    catch {
        $publishError = $_
        $rollbackErrors = [Collections.Generic.List[string]]::new()
        foreach ($relative in @($legacyAttributesChanged)) {
            try {
                $mutablePath = Resolve-ContainedPath -BasePath $ResolvedTargetRoot -RelativePath ([string]$relative)
                (Get-Item -LiteralPath $mutablePath -Force).IsReadOnly = $true
            }
            catch { $rollbackErrors.Add("readonly:${relative}: $($_.Exception.Message)") }
        }
        $rollbackItems = @($published)
        [array]::Reverse($rollbackItems)
        foreach ($item in $rollbackItems) {
            try {
                if ($item.Existed -and (Test-Path -LiteralPath $item.Backup -PathType Leaf)) {
                    Write-BytesAtomic -Path $item.Destination -Bytes ([IO.File]::ReadAllBytes($item.Backup))
                    (Get-Item -LiteralPath $item.Destination -Force).IsReadOnly = [bool]$item.WasReadOnly
                }
                elseif (-not $item.Existed -and (Test-Path -LiteralPath $item.Destination -PathType Leaf)) {
                    $destinationItem = Get-Item -LiteralPath $item.Destination -Force
                    if ($destinationItem.IsReadOnly) { $destinationItem.IsReadOnly = $false }
                    Remove-Item -LiteralPath $item.Destination -Force
                }
            }
            catch {
                $rollbackErrors.Add("$($item.Mapping.Destination): $($_.Exception.Message)")
            }
        }
        foreach ($state in @($managedAttributeStates | Where-Object Existed)) {
            try {
                if (-not (Test-Path -LiteralPath $state.Destination -PathType Leaf)) {
                    throw "Urspruengliche Datei fehlt"
                }
                (Get-Item -LiteralPath $state.Destination -Force).IsReadOnly = [bool]$state.WasReadOnly
            }
            catch {
                $rollbackErrors.Add("readonly:$($state.RelativePath): $($_.Exception.Message)")
            }
        }
        if ($publishConfig) {
            try {
                if ($configExisted -and (Test-Path -LiteralPath $configBackup -PathType Leaf)) {
                    Write-BytesAtomic -Path $configDestination -Bytes ([IO.File]::ReadAllBytes($configBackup))
                }
                elseif (-not $configExisted -and (Test-Path -LiteralPath $configDestination -PathType Leaf)) {
                    Remove-Item -LiteralPath $configDestination -Force
                }
            }
            catch { $rollbackErrors.Add(".ci/ci.config.json: $($_.Exception.Message)") }
        }
        if ($targetManifestPublished) {
            try {
                if ($targetManifestExisted -and (Test-Path -LiteralPath $targetManifestBackup -PathType Leaf)) {
                    Write-BytesAtomic -Path $targetManifestPath -Bytes ([IO.File]::ReadAllBytes($targetManifestBackup))
                }
                elseif (-not $targetManifestExisted -and (Test-Path -LiteralPath $targetManifestPath -PathType Leaf)) {
                    Remove-Item -LiteralPath $targetManifestPath -Force
                }
            }
            catch { $rollbackErrors.Add(".ci/bootstrap/runtime.manifest.json: $($_.Exception.Message)") }
        }
        if ($bindingPublished) {
            try {
                if ($bindingExisted -and (Test-Path -LiteralPath $bindingBackup -PathType Leaf)) {
                    Write-BytesAtomic -Path $bindingPath -Bytes ([IO.File]::ReadAllBytes($bindingBackup))
                }
                elseif (-not $bindingExisted -and (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
                    Remove-Item -LiteralPath $bindingPath -Force
                }
            }
            catch { $rollbackErrors.Add("project-binding: $($_.Exception.Message)") }
        }
        $atomicCleanupIssues = @($script:AtomicCleanupIssues | Select-Object -Skip $atomicCleanupIssueStart)
        foreach ($issue in $atomicCleanupIssues) {
            try {
                if (Test-Path -LiteralPath $issue.path -PathType Leaf) {
                    $cleanupItem = Get-Item -LiteralPath $issue.path -Force
                    if ($cleanupItem.IsReadOnly) { $cleanupItem.IsReadOnly = $false }
                    Remove-Item -LiteralPath $issue.path -Force
                }
            }
            catch {
                $rollbackErrors.Add("atomic-cleanup:$($issue.kind):$($issue.path): $($_.Exception.Message)")
            }
        }
        $rollbackSuffix = if ($rollbackErrors.Count -gt 0) {
            " Rollbackfehler: $($rollbackErrors -join ' | ')."
        }
        else {
            ' Rollback erfolgreich.'
        }
        throw "Publikation fehlgeschlagen. $($publishError.Exception.Message).$rollbackSuffix Backup=$backupRoot; Transaktion=$transactionRoot"
    }
    }
    finally {
        $lock.Dispose()
    }
}

function Enter-ProjectLock {
    param([Parameter(Mandatory)][string]$ResolvedTargetRoot)

    [IO.Directory]::CreateDirectory($script:LocksRoot) | Out-Null
    $lockPath = Join-Path $script:LocksRoot ((Get-ProjectId $ResolvedTargetRoot) + '.lock')
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ($true) {
        try {
            $stream = [IO.File]::Open(
                $lockPath,
                [IO.FileMode]::OpenOrCreate,
                [IO.FileAccess]::ReadWrite,
                [IO.FileShare]::None
            )
            $owner = "pid=$PID;utc=$([DateTimeOffset]::UtcNow.ToString('o'));target=$ResolvedTargetRoot`n"
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes($owner)
            $stream.SetLength(0)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
            return $stream
        }
        catch [IO.IOException] {
            if ([DateTime]::UtcNow -ge $deadline) { throw "Bootstrap-Lock Timeout: $lockPath" }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Invoke-ProfileRun {
    param(
        [Parameter(Mandatory)][string]$ResolvedTargetRoot,
        [Parameter(Mandatory)]$ProfilePackage,
        [Parameter(Mandatory)][object[]]$Mappings,
        [Parameter(Mandatory)]$Binding
    )

    $issues = @(Get-TargetIssues -ResolvedTargetRoot $ResolvedTargetRoot -Mappings $Mappings -Binding $Binding)
    if ($issues.Count -gt 0) {
        throw "Installierte Runtime weicht vom zentralen Release ab: $($issues -join ', '). Repair ausfuehren."
    }
    $configPath = Join-Path $ResolvedTargetRoot '.ci\ci.config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) { $null = Read-JsonFile $configPath }

    $lock = Enter-ProjectLock $ResolvedTargetRoot
    $previousVerified = [Environment]::GetEnvironmentVariable('CI_BOOTSTRAP_PREVERIFIED', 'Process')
    $previousBootstrapRoot = [Environment]::GetEnvironmentVariable('CI_BOOTSTRAP_ROOT', 'Process')
    try {
        $issues = @(Get-TargetIssues -ResolvedTargetRoot $ResolvedTargetRoot -Mappings $Mappings -Binding $Binding)
        if ($issues.Count -gt 0) { throw "Runtime wurde vor dem Start geaendert: $($issues -join ', ')" }
        [Environment]::SetEnvironmentVariable('CI_BOOTSTRAP_PREVERIFIED', '1', 'Process')
        [Environment]::SetEnvironmentVariable('CI_BOOTSTRAP_ROOT', $script:BootstrapRoot, 'Process')
        $entrypoint = Join-Path $ResolvedTargetRoot '.ci\bin\ci.ps1'
        $pwsh = Join-Path $PSHOME 'pwsh.exe'
        if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) { $pwsh = Join-Path $PSHOME 'pwsh' }
        Push-Location -LiteralPath $ResolvedTargetRoot
        try {
            & $pwsh -NoLogo -NoProfile -NonInteractive -File $entrypoint @CiArguments
            $script:RunExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        $issues = @(Get-TargetIssues -ResolvedTargetRoot $ResolvedTargetRoot -Mappings $Mappings -Binding $Binding)
        if ($issues.Count -gt 0) {
            throw "Runtime wurde waehrend der Ausfuehrung geaendert: $($issues -join ', '). Repair ausfuehren."
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('CI_BOOTSTRAP_PREVERIFIED', $previousVerified, 'Process')
        [Environment]::SetEnvironmentVariable('CI_BOOTSTRAP_ROOT', $previousBootstrapRoot, 'Process')
        $lock.Dispose()
    }
}

try {
    $centralManifest = Assert-CentralPackage

    switch ($Command) {
        'List' {
            Get-ChildItem -LiteralPath $script:ProfilesRoot -Directory | Sort-Object Name | ForEach-Object {
                $package = Get-ProfileManifest $_.Name
                [pscustomobject]@{
                    profile = [string]$package.Manifest.id
                    version = [string]$package.Manifest.version
                    commands = (Read-JsonFile (Join-Path $package.Root ([string]$package.Manifest.command_catalog))).command_count
                    functions = (Read-JsonFile (Join-Path $package.Root ([string]$package.Manifest.function_catalog))).unique_function_count
                    description = [string]$package.Manifest.description
                }
            } | Format-Table -AutoSize
            break
        }
        'Audit' {
            $profiles = @(Get-ChildItem -LiteralPath $script:ProfilesRoot -Directory | Sort-Object Name)
            foreach ($directory in $profiles) { $null = Get-ProfileManifest $directory.Name }
            $result = [ordered]@{
                status = 'ok'
                central_release = [string]$centralManifest.version
                profiles = $profiles.Count
                target = $null
                target_issues = @()
            }
            if ($TargetRoot) {
                $resolvedTarget = Resolve-TargetRoot
                $binding = Read-ProjectBinding $resolvedTarget
                if ($null -eq $binding) { throw "Keine zentrale Projektbindung fuer $resolvedTarget" }
                $package = Get-ProfileManifest ([string]$binding.profile)
                $mappings = @(Get-ExpectedMappings $package)
                $result.target = $resolvedTarget
                $result.target_issues = @(Get-TargetIssues -ResolvedTargetRoot $resolvedTarget -Mappings $mappings -Binding $binding)
                if (@($result.target_issues).Count -gt 0) { $result.status = 'error' }
            }
            if ($CompareSources) {
                $testRelative = 'tests/Test-Compatibility.ps1'
                $null = Get-CentralReleaseRecord $testRelative
                $testPath = Resolve-ContainedPath -BasePath $script:BootstrapRoot -RelativePath $testRelative
                $pwsh = Join-Path $PSHOME 'pwsh.exe'
                if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) { $pwsh = Join-Path $PSHOME 'pwsh' }
                & $pwsh -NoLogo -NoProfile -NonInteractive -File $testPath -Quiet
                if ($LASTEXITCODE -ne 0) { throw 'Quellkompatibilitaet ist verletzt.' }
            }
            $result | ConvertTo-Json -Depth 8
            if ($result.status -ne 'ok') { exit 1 }
            break
        }
        { $_ -in @('Plan', 'Install', 'Update', 'Repair') } {
            $resolvedTarget = Resolve-TargetRoot
            $binding = Read-ProjectBinding $resolvedTarget
            $selectedProfile = $Profile
            if (-not $selectedProfile -and $null -ne $binding) { $selectedProfile = [string]$binding.profile }
            if (-not $selectedProfile) { throw "Command $Command erfordert -Profile."
            }
            if ($Command -eq 'Install' -and $null -ne $binding) {
                throw 'Das Projekt ist bereits gebunden. Fuer Aktualisierungen Update, fuer Wiederherstellung Repair verwenden.'
            }
            if ($Command -eq 'Update' -and $null -eq $binding) {
                throw 'Update erfordert eine bestehende zentrale Projektbindung. Fuer die Erstinstallation Install verwenden.'
            }
            if ($Command -eq 'Repair' -and $null -eq $binding) { throw 'Repair erfordert eine bestehende zentrale Projektbindung.' }
            if ($null -ne $binding -and $Command -eq 'Repair' -and [string]$binding.profile -ne $selectedProfile) {
                throw 'Repair darf das gebundene Profil nicht wechseln. Fuer einen Profilwechsel Update -Force verwenden.'
            }
            if ($null -ne $binding -and $Command -eq 'Update' -and [string]$binding.profile -ne $selectedProfile -and -not $Force) {
                throw 'Profilwechsel per Update erfordert -Force.'
            }
            $package = Get-ProfileManifest $selectedProfile
            $mappings = @(Get-ExpectedMappings $package)
            if ($Command -eq 'Plan') {
                Get-PlanReport -ResolvedTargetRoot $resolvedTarget -Mappings $mappings -ProfilePackage $package |
                    ConvertTo-Json -Depth 10
            }
            else {
                Publish-Profile -ResolvedTargetRoot $resolvedTarget -ProfilePackage $package -Mappings $mappings -Operation $Command
            }
            break
        }
        'Run' {
            $resolvedTarget = Resolve-TargetRoot
            $binding = Read-ProjectBinding $resolvedTarget
            if ($null -eq $binding) { throw "Keine zentrale Projektbindung. Zuerst Install ausfuehren: $resolvedTarget" }
            if ($Profile -and $Profile -ne [string]$binding.profile) { throw 'Angegebenes Profil widerspricht der zentralen Projektbindung.' }
            $package = Get-ProfileManifest ([string]$binding.profile)
            $mappings = @(Get-ExpectedMappings $package)
            $requestedCommand = if (@($CiArguments).Count -gt 0) { [string]$CiArguments[0] } else { 'menu' }
            if ($requestedCommand -match '^\s*#ci\s+(.+)$') { $requestedCommand = $Matches[1] }
            $requestedCommand = $requestedCommand.Trim().ToLowerInvariant()
            if ($requestedCommand -in @('restore-immutables', 'repin-immutables', 'runtime-update')) {
                $maintenanceOperation = if ($requestedCommand -eq 'runtime-update') { 'Update' } else { 'Repair' }
                $previousConfirmPreference = $ConfirmPreference
                try {
                    $ConfirmPreference = 'None'
                    Publish-Profile -ResolvedTargetRoot $resolvedTarget -ProfilePackage $package -Mappings $mappings -Operation $maintenanceOperation
                }
                finally {
                    $ConfirmPreference = $previousConfirmPreference
                }
                exit 0
            }
            if ([string]$binding.profile_version -ne [string]$package.Manifest.version) {
                throw "Installierte Profilversion $($binding.profile_version) ist nicht das zentrale Release $($package.Manifest.version). Update ausfuehren."
            }
            $script:RunExitCode = 1
            Invoke-ProfileRun -ResolvedTargetRoot $resolvedTarget -ProfilePackage $package -Mappings $mappings -Binding $binding
            exit $script:RunExitCode
        }
    }
}
catch {
    [Console]::Error.WriteLine("[BOOTSTRAP] $($_.Exception.Message)")
    exit 1
}
