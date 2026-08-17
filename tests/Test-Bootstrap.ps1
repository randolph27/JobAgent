#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$SkipLifecycle,
    [switch]$SkipSourceComparison
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manager = Join-Path $bootstrapRoot 'Bootstrap.ps1'
$pwsh = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
$sourceProfiles = @(
    @{ id = 'ubuntu-web'; root = 'D:\_Scripte\UbuntuVPS_Quiz\web' },
    @{ id = 'chess'; root = 'D:\_Scripte\Chess' },
    @{ id = 'sound-profile'; root = 'D:\_Scripte\Sound Profile' }
)

function Invoke-Child {
    param(
        [Parameter(Mandatory)][string]$Script,
        [string[]]$Arguments = @(),
        [int]$ExpectedExit = 0
    )

    $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    if ($LASTEXITCODE -ne $ExpectedExit) {
        throw "Child Exitcode $LASTEXITCODE statt ${ExpectedExit}: $Script $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return @($output | ForEach-Object { [string]$_ })
}

function Get-SourceSnapshot {
    $records = [Collections.Generic.List[string]]::new()
    foreach ($source in $sourceProfiles) {
        $root = [string]$source.root
        $paths = [Collections.Generic.List[IO.FileInfo]]::new()
        $bin = Join-Path $root '.ci\bin'
        foreach ($file in @(Get-ChildItem -LiteralPath $bin -Recurse -File -Force)) { $paths.Add($file) }
        foreach ($relative in @(
                '.ci\ci.config.json', 'README.md', 'Roadmap.md', 'Roadmap_archive.md', 'Roadmap_index.md',
                'todo.events.jsonl', 'todo.state.json', 'todo.current.md', 'todo.master.index.json',
                'todo.history.digest.json', 'todo.checkpoint.json', 'handoff.latest.json', 'handoff.latest.md'
            )) {
            $path = Join-Path $root $relative
            if (Test-Path -LiteralPath $path -PathType Leaf) { $paths.Add((Get-Item -LiteralPath $path -Force)) }
        }
        foreach ($file in @($paths | Sort-Object FullName -Unique)) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $records.Add("$($source.id)|$relative|$hash|$($file.Length)|readonly=$($file.IsReadOnly)")
        }
        $statusOutput = @(& git -C $root status --porcelain=v1 -z 2>$null)
        $gitSucceeded = $?
        $status = $statusOutput -join ''
        if (-not $gitSucceeded) { throw "Git-Status konnte nicht gelesen werden: $root" }
        $records.Add("$($source.id)|git-status|$status")
    }
    return @($records | Sort-Object)
}

function Assert-ReleaseClosure {
    $manifestPath = Join-Path $bootstrapRoot 'bootstrap.manifest.json'
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ([string]$manifest.schema -ne 'workflow-bootstrap-release/v1') { throw 'Release-Manifest-Schema ist ungueltig.' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($manifest.files)) {
        $relative = [string]$record.path
        if (-not $seen.Add($relative)) { throw "Doppelter Release-Pfad: $relative" }
        $path = Join-Path $bootstrapRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Release-Datei fehlt: $relative" }
        if ((Get-Item -LiteralPath $path -Force).Length -ne [long]$record.size) { throw "Release-Groesse stimmt nicht: $relative" }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$record.sha256) {
            throw "Release-Hash stimmt nicht: $relative"
        }
    }
    foreach ($rootName in @('runtime', 'schemas', 'catalog', 'profiles', 'templates', 'tests', 'tools', 'docs')) {
        $root = Join-Path $bootstrapRoot $rootName
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force)) {
            $relative = [IO.Path]::GetRelativePath($bootstrapRoot, $file.FullName).Replace('\', '/')
            if (-not $seen.Contains($relative)) { throw "Datei fehlt in der Release-Closure: $relative" }
        }
    }
    foreach ($relative in @('Bootstrap.ps1', 'bootstrap.cmd', 'Run.ps1', 'run.cmd', 'README.md', 'CHANGELOG.md')) {
        $path = Join-Path $bootstrapRoot $relative
        if ((Test-Path -LiteralPath $path -PathType Leaf) -and -not $seen.Contains($relative)) {
            throw "Root-Datei fehlt in der Release-Closure: $relative"
        }
    }
    return @($manifest.files).Count
}

try {
    $powerShellFiles = @(Get-ChildItem -LiteralPath $bootstrapRoot -Recurse -Filter '*.ps1' -File -Force)
    $rawArgumentScripts = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $null = $rawArgumentScripts.Add((Join-Path $bootstrapRoot 'Run.ps1'))
    $null = $rawArgumentScripts.Add((Join-Path $bootstrapRoot 'runtime\ci.ps1'))
    foreach ($file in $powerShellFiles) {
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if (@($errors).Count -gt 0) { throw "PowerShell-Parsefehler in $($file.FullName): $(@($errors.Message) -join ' | ')" }
        if ($rawArgumentScripts.Contains($file.FullName) -and $null -ne $ast.ParamBlock) {
            throw "Raw-Argument-Launcher darf keinen ParamBlock besitzen: $($file.FullName)"
        }
    }
    $jsonFiles = @(Get-ChildItem -LiteralPath $bootstrapRoot -Recurse -Filter '*.json' -File -Force)
    foreach ($file in $jsonFiles) {
        try { $null = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json }
        catch { throw "JSON-Parsefehler in $($file.FullName): $($_.Exception.Message)" }
    }

    foreach ($profile in $sourceProfiles) {
        $profileRoot = Join-Path $bootstrapRoot ("profiles\$($profile.id)")
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $profileRoot 'profile.json') | ConvertFrom-Json
        if ([string]$manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw "Profilversion ungueltig: $($profile.id)" }
        foreach ($record in @($manifest.payload)) {
            $path = Join-Path $profileRoot ([string]$record.source)
            if ((Get-Item -LiteralPath $path -Force).Length -ne [long]$record.size -or
                (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$record.sha256) {
                throw "Profilpayload stimmt nicht: $($profile.id)/$($record.source)"
            }
        }
    }

    $runtimeLauncher = [IO.File]::ReadAllText((Join-Path $bootstrapRoot 'runtime\ci.cmd'))
    foreach ($requiredLauncherFragment in @('DisableDelayedExpansion', 'legacy-ci.ps1', 'WindowsPowerShell\v1.0\powershell.exe')) {
        if (-not $runtimeLauncher.Contains($requiredLauncherFragment)) {
            throw "Runtime-Launcher-Fallback fehlt: $requiredLauncherFragment"
        }
    }
    $managerText = [IO.File]::ReadAllText($manager)
    foreach ($requiredManagerFragment in @(
            "@('restore-immutables', 'repin-immutables', 'runtime-update')",
            "if (`$requestedCommand -eq 'runtime-update') { 'Update' } else { 'Repair' }"
        )) {
        if (-not $managerText.Contains($requiredManagerFragment, [StringComparison]::Ordinal)) {
            throw "Zentrale Recovery-Kompatibilitaet fehlt: $requiredManagerFragment"
        }
    }

    $releaseFileCount = Assert-ReleaseClosure
    $sourceBefore = if ($SkipSourceComparison) { @() } else { @(Get-SourceSnapshot) }
    $null = Invoke-Child -Script (Join-Path $bootstrapRoot 'tests\Test-ReferenceTemplates.ps1') -Arguments @('-Quiet')
    $null = Invoke-Child -Script (Join-Path $bootstrapRoot 'tests\Test-Compatibility.ps1') -Arguments @('-Quiet')
    if ($IsWindows) {
        $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
            throw "Windows-PowerShell-Fallback fehlt: $windowsPowerShell"
        }
        $legacyTest = Join-Path $bootstrapRoot 'tests\Test-LegacyPowerShell.ps1'
        $legacyOutput = @(& $windowsPowerShell -NoLogo -NoProfile -NonInteractive -File $legacyTest -Quiet 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "PowerShell-5.1-Kompatibilitaetstest fehlgeschlagen: $($legacyOutput -join "`n")"
        }
    }
    $null = Invoke-Child -Script $manager -Arguments @('List')
    $null = Invoke-Child -Script $manager -Arguments @('Audit', '-CompareSources')
    foreach ($profile in $sourceProfiles) {
        $null = Invoke-Child -Script $manager -Arguments @('Plan', '-TargetRoot', [string]$profile.root, '-Profile', [string]$profile.id)
    }
    if (-not $SkipSourceComparison) {
        $sourceAfter = @(Get-SourceSnapshot)
        $difference = @(Compare-Object -ReferenceObject $sourceBefore -DifferenceObject $sourceAfter)
        if ($difference.Count -gt 0) {
            $sample = @($difference | Select-Object -First 20 | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ' | '
            throw "Mindestens ein Quellprojekt wurde waehrend der Quelltests veraendert: $sample"
        }
    }
    if (-not $SkipLifecycle) {
        $null = Invoke-Child -Script (Join-Path $bootstrapRoot 'tests\Test-Lifecycle.ps1')
    }

    [pscustomobject]@{
        status = 'ok'
        powershell_files = $powerShellFiles.Count
        json_files = $jsonFiles.Count
        release_files = $releaseFileCount
        source_compatibility = $(if ($SkipSourceComparison) { 'skipped' } else { 'ok-read-only' })
        lifecycle = $(if ($SkipLifecycle) { 'skipped' } else { 'ok' })
    } | ConvertTo-Json -Depth 5
}
catch {
    [Console]::Error.WriteLine("[TEST] $($_.Exception.Message)")
    exit 1
}
