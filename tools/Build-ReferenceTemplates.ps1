#requires -Version 7.4

[CmdletBinding()]
param([switch]$Force)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$templatesRoot = Join-Path $bootstrapRoot 'templates'
$definitions = @(
    [ordered]@{ id = 'ubuntu-web'; source = 'D:\_Scripte\UbuntuVPS_Quiz\web' },
    [ordered]@{ id = 'chess'; source = 'D:\_Scripte\Chess' },
    [ordered]@{ id = 'sound-profile'; source = 'D:\_Scripte\Sound Profile' }
)

function Get-SelectedSourceFiles {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $files = [Collections.Generic.List[IO.FileInfo]]::new()
    foreach ($relative in @('README.md', 'ci.cmd', '.ci\ci.config.json')) {
        $path = Join-Path $SourceRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Referenzdatei fehlt: $path"
        }
        $files.Add((Get-Item -LiteralPath $path -Force))
    }
    $binRoot = Join-Path $SourceRoot '.ci\bin'
    if (-not (Test-Path -LiteralPath $binRoot -PathType Container)) {
        throw "CI-Verzeichnis fehlt: $binRoot"
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $binRoot -Recurse -File -Force | Sort-Object FullName)) {
        $files.Add($file)
    }
    return @($files | Sort-Object FullName -Unique)
}

function Get-SourceSnapshot {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][IO.FileInfo[]]$Files
    )

    $records = foreach ($file in $Files) {
        $relative = [IO.Path]::GetRelativePath($SourceRoot, $file.FullName).Replace('\', '/')
        "$relative|$($file.Length)|$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"
    }
    $head = [string](& git -C $SourceRoot rev-parse HEAD 2>$null)
    if (-not $?) { throw "Git-HEAD konnte nicht gelesen werden: $SourceRoot" }
    $status = @(& git -C $SourceRoot status --porcelain=v1 -z 2>$null) -join ''
    if (-not $?) { throw "Git-Status konnte nicht gelesen werden: $SourceRoot" }
    return @("head|$head", "status|$status") + @($records | Sort-Object)
}

function Get-SelectedGitStatus {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $status = @(& git -C $SourceRoot status --porcelain=v1 -- 'README.md' 'ci.cmd' '.ci/ci.config.json' '.ci/bin' 2>$null)
    if (-not $?) { throw "Git-Status der Referenzdateien konnte nicht gelesen werden: $SourceRoot" }
    return @($status | ForEach-Object { [string]$_ })
}

[IO.Directory]::CreateDirectory($templatesRoot) | Out-Null
$results = [Collections.Generic.List[object]]::new()
foreach ($definition in $definitions) {
    $sourceRoot = [IO.Path]::GetFullPath([string]$definition.source)
    $destinationRoot = [IO.Path]::GetFullPath((Join-Path $templatesRoot ([string]$definition.id)))
    $files = @(Get-SelectedSourceFiles $sourceRoot)
    $before = @(Get-SourceSnapshot -SourceRoot $sourceRoot -Files $files)
    if ((Test-Path -LiteralPath $destinationRoot -PathType Container) -and -not $Force) {
        throw "Template existiert bereits; Aktualisierung erfordert -Force: $destinationRoot"
    }
    [IO.Directory]::CreateDirectory($destinationRoot) | Out-Null

    $expected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $manifestFiles = [Collections.Generic.List[object]]::new()
    foreach ($sourceFile in $files) {
        if (($sourceFile.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse Point ist als Referenz nicht erlaubt: $($sourceFile.FullName)"
        }
        $relative = [IO.Path]::GetRelativePath($sourceRoot, $sourceFile.FullName).Replace('\', '/')
        $null = $expected.Add($relative)
        $destination = Join-Path $destinationRoot $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            (Get-Item -LiteralPath $destination -Force).IsReadOnly = $false
        }
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination -Force
        (Get-Item -LiteralPath $destination -Force).IsReadOnly = $false
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -ne $destinationHash) { throw "Referenzkopie stimmt nicht: $relative" }
        $manifestFiles.Add([ordered]@{
                path = $relative
                sha256 = $sourceHash
                size = [long]$sourceFile.Length
            })
    }

    $unexpected = @(
        Get-ChildItem -LiteralPath $destinationRoot -Recurse -File -Force |
            Where-Object Name -ne 'template.manifest.json' |
            Where-Object {
                $relative = [IO.Path]::GetRelativePath($destinationRoot, $_.FullName).Replace('\', '/')
                -not $expected.Contains($relative)
            }
    )
    if ($unexpected.Count -gt 0) {
        throw "Unerwartete alte Template-Dateien muessen manuell geprueft werden: $(@($unexpected.FullName) -join ', ')"
    }

    $head = [string](& git -C $sourceRoot rev-parse HEAD)
    $selectedGitStatus = @(Get-SelectedGitStatus -SourceRoot $sourceRoot)
    $manifest = [ordered]@{
        schema = 'workflow-bootstrap-reference-template/v1'
        id = [string]$definition.id
        source_root = $sourceRoot
        source_git_head = $head
        source_selected_worktree = $(if ($selectedGitStatus.Count -eq 0) { 'clean' } else { 'modified' })
        source_selected_status = $selectedGitStatus
        captured_utc = [DateTimeOffset]::UtcNow.ToString('o')
        files = @($manifestFiles | Sort-Object path)
    }
    $manifestPath = Join-Path $destinationRoot 'template.manifest.json'
    $json = $manifest | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($manifestPath, $json + "`n", [Text.UTF8Encoding]::new($false))

    $after = @(Get-SourceSnapshot -SourceRoot $sourceRoot -Files $files)
    if (@(Compare-Object -ReferenceObject $before -DifferenceObject $after).Count -gt 0) {
        throw "Quelle wurde waehrend der Referenzerfassung geaendert: $sourceRoot"
    }
    $results.Add([pscustomobject]@{
            profile = [string]$definition.id
            files = $files.Count
            source_git_head = $head
            status = 'byte-equal'
        })
}

$results | Format-Table -AutoSize
