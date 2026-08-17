#requires -Version 7.4

[CmdletBinding()]
param(
    [ValidateSet('ubuntu-web', 'chess', 'sound-profile')]
    [string[]]$Profile = @('ubuntu-web', 'chess', 'sound-profile'),
    [switch]$KeepArtifacts
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manager = Join-Path $bootstrapRoot 'Bootstrap.ps1'
$runner = Join-Path $bootstrapRoot 'Run.ps1'
$pwsh = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
$testParent = Join-Path ([IO.Path]::GetTempPath()) 'workflow-bootstrap-tests'
$testRoot = Join-Path $testParent ([Guid]::NewGuid().ToString('N'))
$initialTransactions = @()
$transactionsRoot = Join-Path $bootstrapRoot 'state\transactions'
if (Test-Path -LiteralPath $transactionsRoot -PathType Container) {
    $initialTransactions = @(Get-ChildItem -LiteralPath $transactionsRoot -Directory -Force | ForEach-Object FullName)
}

function Get-ProjectId {
    param([Parameter(Mandatory)][string]$TargetRoot)

    $canonical = [IO.Path]::GetFullPath($TargetRoot)
    $root = [IO.Path]::GetPathRoot($canonical)
    if (-not $canonical.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        $canonical = $canonical.TrimEnd([char[]]@('\', '/'))
    }
    if ($IsWindows) { $canonical = $canonical.ToLowerInvariant() }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($canonical)
        return (-join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })).Substring(0, 24)
    }
    finally { $sha.Dispose() }
}

function Invoke-Manager {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$ExpectedExit
    )

    $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $manager @Arguments 2>&1)
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExpectedExit) {
        throw "Manager Exitcode $actualExit statt $ExpectedExit fuer: $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return @($output | ForEach-Object { [string]$_ })
}

function Invoke-Runner {
    param(
        [Parameter(Mandatory)][string]$TargetRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$ExpectedExit
    )

    $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $runner $TargetRoot @Arguments 2>&1)
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $ExpectedExit) {
        throw "Runner Exitcode $actualExit statt $ExpectedExit fuer: $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return @($output | ForEach-Object { [string]$_ })
}

function Remove-GeneratedPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$AllowedParent
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolved = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetFullPath($AllowedParent).TrimEnd([char[]]@('\', '/'))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $resolved.StartsWith($parent + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw "Test-Cleanup verweigert Pfad ausserhalb des erlaubten Bereichs: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$projectIds = [Collections.Generic.List[string]]::new()
$results = [Collections.Generic.List[object]]::new()
try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    foreach ($profileId in $Profile) {
        $target = Join-Path $testRoot $profileId
        [IO.Directory]::CreateDirectory((Join-Path $target '.ci')) | Out-Null
        $configPath = Join-Path $target '.ci\ci.config.json'
        $configText = "{`n  `"test_marker`": `"preserve-$profileId`"`n}`n"
        [IO.File]::WriteAllText($configPath, $configText, [Text.UTF8Encoding]::new($false))
        $configHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
        $projectId = Get-ProjectId $target
        $projectIds.Add($projectId)

        $beforePlan = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
        $null = Invoke-Manager -Arguments @('Plan', '-TargetRoot', $target, '-Profile', $profileId) -ExpectedExit 0
        if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $beforePlan) {
            throw "${profileId}: Plan hat das Ziel veraendert."
        }

        $null = Invoke-Manager -Arguments @('Install', '-TargetRoot', $target, '-Profile', $profileId, '-Confirm:$false') -ExpectedExit 0
        if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $configHash) {
            throw "${profileId}: Install hat die mutable Konfiguration ersetzt."
        }
        $managedPath = Join-Path $target '.ci\bin\ci.ps1'
        if (-not (Get-Item -LiteralPath $managedPath -Force).IsReadOnly) {
            throw "${profileId}: Install hat die verwaltete Runtime nicht schreibgeschuetzt."
        }
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 0
        $verifyOutput = Invoke-Runner -TargetRoot $target -Arguments @('bootstrap-verify') -ExpectedExit 0
        if (($verifyOutput -join "`n") -notmatch '"status"\s*:\s*"ok"') {
            throw "${profileId}: bootstrap-verify meldet keinen OK-Status."
        }

        (Get-Item -LiteralPath $managedPath -Force).IsReadOnly = $false
        [IO.File]::AppendAllText($managedPath, "`n# lifecycle-tamper`n", [Text.UTF8Encoding]::new($false))
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 1
        $null = Invoke-Manager -Arguments @('Repair', '-TargetRoot', $target, '-Confirm:$false') -ExpectedExit 0
        if (-not (Get-Item -LiteralPath $managedPath -Force).IsReadOnly) {
            throw "${profileId}: Repair hat den Schreibschutz der Runtime nicht restauriert."
        }
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 0

        $targetManifest = Join-Path $target '.ci\bootstrap\runtime.manifest.json'
        [IO.File]::AppendAllText($targetManifest, " `n", [Text.UTF8Encoding]::new($false))
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 1
        $null = Invoke-Manager -Arguments @('Repair', '-TargetRoot', $target, '-Confirm:$false') -ExpectedExit 0

        $unexpectedPath = Join-Path $target '.ci\bin\unexpected-test.ps1'
        [IO.File]::WriteAllText($unexpectedPath, "throw 'must never execute'`n", [Text.UTF8Encoding]::new($false))
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 1
        Remove-Item -LiteralPath $unexpectedPath -Force
        $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 0

        foreach ($compatibilityCommand in @('restore-immutables', 'repin-immutables', 'runtime-update')) {
            $null = Invoke-Runner -TargetRoot $target -Arguments @($compatibilityCommand) -ExpectedExit 0
            $null = Invoke-Manager -Arguments @('Audit', '-TargetRoot', $target) -ExpectedExit 0
            if (-not (Get-Item -LiteralPath $managedPath -Force).IsReadOnly) {
                throw "${profileId}: $compatibilityCommand hat den Schreibschutz der Runtime nicht erhalten."
            }
        }
        if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $configHash) {
            throw "${profileId}: Repair/Tamper-/Kompatibilitaetstest hat die mutable Konfiguration veraendert."
        }
        $results.Add([pscustomobject]@{
                profile = $profileId
                install = 'ok'
                audit = 'ok'
                tamper_detection = 'ok'
                repair = 'ok'
                recovery_compatibility = 'ok'
                managed_readonly = 'ok'
                mutable_config = 'preserved'
            })
    }

    [pscustomobject]@{
        status = 'ok'
        profiles = @($results)
        artifacts = $(if ($KeepArtifacts) { $testRoot } else { $null })
    } | ConvertTo-Json -Depth 8
}
finally {
    if (-not $KeepArtifacts) {
        foreach ($projectId in @($projectIds)) {
            $binding = Join-Path $bootstrapRoot "state\projects\$projectId.json"
            if (Test-Path -LiteralPath $binding -PathType Leaf) { Remove-Item -LiteralPath $binding -Force }
            $lock = Join-Path $bootstrapRoot "state\locks\$projectId.lock"
            if (Test-Path -LiteralPath $lock -PathType Leaf) { Remove-Item -LiteralPath $lock -Force }
            Remove-GeneratedPath -Path (Join-Path $bootstrapRoot "backups\$projectId") -AllowedParent (Join-Path $bootstrapRoot 'backups')
        }
        if (Test-Path -LiteralPath $transactionsRoot -PathType Container) {
            foreach ($directory in @(Get-ChildItem -LiteralPath $transactionsRoot -Directory -Force)) {
                if ($directory.FullName -notin $initialTransactions) {
                    Remove-GeneratedPath -Path $directory.FullName -AllowedParent $transactionsRoot
                }
            }
        }
        Remove-GeneratedPath -Path $testRoot -AllowedParent $testParent
        if ((Test-Path -LiteralPath $testParent -PathType Container) -and
            @(Get-ChildItem -LiteralPath $testParent -Force).Count -eq 0) {
            Remove-Item -LiteralPath $testParent -Force
        }
    }
}
