#requires -Version 7.4

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$Command = if ($args.Count -gt 0) { [string]$args[0] } else { 'menu' }
$CommandArguments = if ($args.Count -gt 1) {
    [string[]]$args[1..($args.Count - 1)]
}
else {
    [string[]]@()
}

$script:RuntimeSchema = 'workflow-bootstrap-runtime/v1'
$script:ScriptRoot = $PSScriptRoot
$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $script:ScriptRoot '..\..'))
$script:CiRoot = Join-Path $script:RepoRoot '.ci'
$script:BootstrapRoot = Join-Path $script:CiRoot 'bootstrap'
$script:ManifestPath = Join-Path $script:BootstrapRoot 'runtime.manifest.json'
$script:ObjectsRoot = Join-Path $script:BootstrapRoot 'objects'

function ConvertTo-NormalizedRelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $normalized = $Path.Replace('\', '/').Trim()
    if (-not $normalized -or [IO.Path]::IsPathRooted($normalized)) {
        throw "Runtime-Pfad ist nicht relativ: $Path"
    }
    if ($normalized -match '(^|/)\.\.(/|$)') {
        throw "Runtime-Pfad verlaesst das Repository: $Path"
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

    $relative = ConvertTo-NormalizedRelativePath $RelativePath
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
        throw "Runtime-Pfad verlaesst das Repository: $RelativePath"
    }
    return $candidate
}

function Test-PathContainsReparsePoint {
    param([Parameter(Mandatory)][string]$Path)

    $candidate = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($candidate)
    $relative = $candidate.Substring($root.Length)
    $current = $root
    foreach ($segment in $relative.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)) {
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

function Read-RuntimeManifest {
    if (-not (Test-Path -LiteralPath $script:ManifestPath -PathType Leaf)) {
        throw "Runtime-Manifest fehlt: $script:ManifestPath"
    }

    try {
        $manifest = Get-Content -Raw -LiteralPath $script:ManifestPath | ConvertFrom-Json
    }
    catch {
        throw "Runtime-Manifest ist unlesbar: $($_.Exception.Message)"
    }

    if ([string]$manifest.schema -ne $script:RuntimeSchema) {
        throw "Unbekanntes Runtime-Manifest-Schema: $($manifest.schema)"
    }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.profile)) {
        throw 'Runtime-Manifest enthaelt kein Profil.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.entrypoint)) {
        throw 'Runtime-Manifest enthaelt keinen Entry-Point.'
    }

    $records = @($manifest.files)
    if ($records.Count -eq 0) {
        throw 'Runtime-Manifest enthaelt keine Dateien.'
    }

    $allowedRoles = @(
        'launcher',
        'trusted-loader',
        'profile-entrypoint',
        'profile-module',
        'profile-helper',
        'bootstrap-module',
        'catalog'
    )
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $recordsByPath = @{}
    foreach ($record in $records) {
        $relative = ConvertTo-NormalizedRelativePath ([string]$record.path)
        if (-not $seen.Add($relative)) {
            throw "Doppelter Runtime-Pfad: $relative"
        }
        $hash = ([string]$record.sha256).ToLowerInvariant()
        if ($hash -notmatch '^[a-f0-9]{64}$') {
            throw "Ungueltiger SHA-256 fuer $relative"
        }
        if ([long]$record.size -lt 0) {
            throw "Ungueltige Dateigroesse fuer $relative"
        }
        $role = [string]$record.role
        if ($role -notin $allowedRoles) {
            throw "Unbekannte Runtime-Rolle fuer ${relative}: $role"
        }
        $source = ConvertTo-NormalizedRelativePath ([string]$record.source)
        if (-not $source) {
            throw "Runtime-Quelle fehlt fuer $relative"
        }
        $null = Resolve-ContainedPath -BasePath $script:RepoRoot -RelativePath $relative
        $recordsByPath[$relative.ToLowerInvariant()] = $record
    }

    $entrypoint = ConvertTo-NormalizedRelativePath ([string]$manifest.entrypoint)
    $commandCatalog = ConvertTo-NormalizedRelativePath ([string]$manifest.command_catalog)
    $workflowModule = ConvertTo-NormalizedRelativePath ([string]$manifest.workflow_audit_module)
    $requiredReferences = @(
        @{ path = $entrypoint; role = 'profile-entrypoint'; name = 'Entry-Point' },
        @{ path = $commandCatalog; role = 'catalog'; name = 'Command-Katalog' },
        @{ path = $workflowModule; role = 'bootstrap-module'; name = 'Workflow-Audit-Modul' },
        @{ path = '.ci/bin/ci.ps1'; role = 'trusted-loader'; name = 'Trusted Loader' }
    )
    foreach ($reference in $requiredReferences) {
        $key = ([string]$reference.path).ToLowerInvariant()
        if (-not $recordsByPath.ContainsKey($key)) {
            throw "$($reference.name) ist nicht im Runtime-Manifest enthalten: $($reference.path)"
        }
        if ([string]$recordsByPath[$key].role -ne [string]$reference.role) {
            throw "$($reference.name) besitzt die falsche Rolle: $($recordsByPath[$key].role)"
        }
    }
    if ([string]$manifest.minimum_pwsh -notmatch '^7\.[0-9]+$') {
        throw "Ungueltige minimum_pwsh-Angabe: $($manifest.minimum_pwsh)"
    }
    return $manifest
}

function Get-IntegrityIssues {
    param([Parameter(Mandatory)]$Manifest)

    $issues = [Collections.Generic.List[string]]::new()
    $manifestPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($record in @($Manifest.files)) {
        $relative = ConvertTo-NormalizedRelativePath ([string]$record.path)
        $null = $manifestPaths.Add($relative)
        $path = Resolve-ContainedPath -BasePath $script:RepoRoot -RelativePath $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $issues.Add("missing:$relative")
            continue
        }
        if (Test-PathContainsReparsePoint $path) {
            $issues.Add("reparse_point:$relative")
            continue
        }
        $item = Get-Item -LiteralPath $path -Force
        if ([long]$item.Length -ne [long]$record.size) {
            $issues.Add("size_mismatch:$relative")
            continue
        }
        if ((Get-Sha256 $path) -ne ([string]$record.sha256).ToLowerInvariant()) {
            $issues.Add("hash_mismatch:$relative")
        }
        if ($IsWindows) {
            $alternateStreams = @(Get-Item -LiteralPath $path -Stream * -ErrorAction SilentlyContinue |
                    Where-Object Stream -ne ':$DATA')
            if ($alternateStreams.Count -gt 0) {
                $issues.Add("alternate_data_stream:$relative")
            }
        }
    }

    $binRoot = Join-Path $script:CiRoot 'bin'
    if (Test-Path -LiteralPath $binRoot -PathType Container) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $binRoot -Recurse -Directory -Force)) {
            if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $relative = [IO.Path]::GetRelativePath($script:RepoRoot, $directory.FullName).Replace('\', '/')
                $issues.Add("unexpected_reparse_directory:$relative")
            }
        }
        foreach ($file in @(Get-ChildItem -LiteralPath $binRoot -Recurse -File -Force)) {
            $relative = [IO.Path]::GetRelativePath($script:RepoRoot, $file.FullName).Replace('\', '/')
            if (-not $manifestPaths.Contains($relative)) {
                $issues.Add("unexpected_bin_file:$relative")
            }
        }
    }

    return @($issues | Sort-Object -Unique)
}

function Assert-RuntimeIntegrity {
    param([Parameter(Mandatory)]$Manifest)

    $issues = @(Get-IntegrityIssues -Manifest $Manifest)
    if ($issues.Count -gt 0) {
        throw "Runtime-Integritaetspruefung fehlgeschlagen: $($issues -join ', ')"
    }
}

function Show-CommandCatalog {
    param([Parameter(Mandatory)]$Manifest)

    $catalogRelative = ConvertTo-NormalizedRelativePath ([string]$Manifest.command_catalog)
    $catalogPath = Resolve-ContainedPath -BasePath $script:RepoRoot -RelativePath $catalogRelative
    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json
    if (@($CommandArguments) -contains '--json') {
        $catalog | ConvertTo-Json -Depth 20
        return
    }
    @($catalog.commands) |
        Sort-Object name |
        Select-Object name, origin, implementation |
        Format-Table -AutoSize | Out-String | Write-Output
}

function Invoke-WorkflowAuditCommand {
    param([Parameter(Mandatory)]$Manifest)

    $moduleRelative = ConvertTo-NormalizedRelativePath ([string]$Manifest.workflow_audit_module)
    $modulePath = Resolve-ContainedPath -BasePath $script:RepoRoot -RelativePath $moduleRelative
    . $modulePath
    if (-not (Get-Command -Name Invoke-WorkflowAudit -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "Workflow-Audit-Modul exportiert Invoke-WorkflowAudit nicht: $moduleRelative"
    }
    Invoke-WorkflowAudit -RepoRoot $script:RepoRoot -AsJson:(@($CommandArguments) -contains '--json')
}

$normalizedCommand = ([string]$Command).Trim()
if ($normalizedCommand -match '^\s*#ci\s+(.+)$') {
    $normalizedCommand = $Matches[1].Trim()
}
$commandKey = $normalizedCommand.ToLowerInvariant()

try {
    $manifest = Read-RuntimeManifest

    Assert-RuntimeIntegrity -Manifest $manifest

    switch ($commandKey) {
        'bootstrap-verify' {
            [pscustomobject]@{
                schema = 'workflow-bootstrap-integrity-report/v1'
                status = 'ok'
                profile = [string]$manifest.profile
                file_count = @($manifest.files).Count
                mutable_paths = @($manifest.mutable_paths)
            } | ConvertTo-Json -Depth 8
            exit 0
        }
        'bootstrap-profile' {
            Write-Output ([string]$manifest.profile)
            exit 0
        }
        'bootstrap-commands' {
            Show-CommandCatalog -Manifest $manifest
            exit 0
        }
        'workflow-audit' {
            Invoke-WorkflowAuditCommand -Manifest $manifest
            exit 0
        }
    }

    $entrypoint = Resolve-ContainedPath -BasePath $script:RepoRoot -RelativePath ([string]$manifest.entrypoint)
    $env:CI_BOOTSTRAP_PREVERIFIED = '1'
    & $entrypoint $normalizedCommand @CommandArguments
    exit $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine("[BOOTSTRAP] $($_.Exception.Message)")
    exit 1
}
