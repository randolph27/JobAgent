#requires -Version 7.4

[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rootReadmePath = Join-Path $bootstrapRoot 'README.md'
$definitions = @(
    [ordered]@{ id = 'ubuntu-web'; source = 'D:\_Scripte\UbuntuVPS_Quiz\web' },
    [ordered]@{ id = 'chess'; source = 'D:\_Scripte\Chess' },
    [ordered]@{ id = 'sound-profile'; source = 'D:\_Scripte\Sound Profile' }
)

function Get-ExpectedFiles {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $files = [Collections.Generic.List[IO.FileInfo]]::new()
    foreach ($relative in @('README.md', 'ci.cmd', '.ci\ci.config.json')) {
        $files.Add((Get-Item -LiteralPath (Join-Path $SourceRoot $relative) -Force))
    }
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot '.ci\bin') -Recurse -File -Force)) {
        $files.Add($file)
    }
    return @($files | Sort-Object FullName -Unique)
}

function Assert-OrderedLinesPresent {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Expected,
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Actual,
        [Parameter(Mandatory)][string]$Label
    )

    $cursor = 0
    foreach ($line in $Expected) {
        $found = $false
        while ($cursor -lt $Actual.Count) {
            if ($Actual[$cursor] -ceq $line) {
                $found = $true
                $cursor++
                break
            }
            $cursor++
        }
        if (-not $found) { throw "$Label fehlt oder Reihenfolge stimmt nicht: $line" }
    }
}

function Get-SelectedGitStatus {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $status = @(& git -C $SourceRoot status --porcelain=v1 -- 'README.md' 'ci.cmd' '.ci/ci.config.json' '.ci/bin' 2>$null)
    if (-not $?) { throw "Git-Status der Referenzdateien konnte nicht gelesen werden: $SourceRoot" }
    return @($status | ForEach-Object { [string]$_ })
}

try {
    $rootReadmeLines = [IO.File]::ReadAllLines($rootReadmePath)
    $rootReadmeText = [IO.File]::ReadAllText($rootReadmePath)
    $fenceCount = @($rootReadmeLines | Where-Object { $_ -match '^```' }).Count
    if (($fenceCount % 2) -ne 0) { throw 'Universelle README besitzt eine ungerade Code-Fence-Anzahl.' }

    $results = [Collections.Generic.List[object]]::new()
    foreach ($definition in $definitions) {
        $sourceRoot = [IO.Path]::GetFullPath([string]$definition.source)
        $templateRoot = Join-Path $bootstrapRoot ("templates\{0}" -f [string]$definition.id)
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $templateRoot 'template.manifest.json') | ConvertFrom-Json
        $head = [string](& git -C $sourceRoot rev-parse HEAD 2>$null)
        if (-not $? -or $head -ne [string]$manifest.source_git_head) {
            throw "$($definition.id): Template-Provenienz weicht vom aktuellen Git-HEAD ab."
        }
        $currentSelectedStatus = @(Get-SelectedGitStatus -SourceRoot $sourceRoot)
        $manifestSelectedStatus = @($manifest.source_selected_status | ForEach-Object { [string]$_ })
        if (@(Compare-Object -ReferenceObject $manifestSelectedStatus -DifferenceObject $currentSelectedStatus).Count -gt 0) {
            throw "$($definition.id): Git-Status der erfassten Referenzdateien wurde veraendert."
        }

        $expectedFiles = @(Get-ExpectedFiles $sourceRoot)
        $manifestPaths = @($manifest.files.path | Sort-Object)
        $expectedPaths = @($expectedFiles | ForEach-Object {
                [IO.Path]::GetRelativePath($sourceRoot, $_.FullName).Replace('\', '/')
            } | Sort-Object)
        if (@(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $manifestPaths).Count -gt 0) {
            throw "$($definition.id): Template-Dateimenge stimmt nicht."
        }
        foreach ($sourceFile in $expectedFiles) {
            $relative = [IO.Path]::GetRelativePath($sourceRoot, $sourceFile.FullName).Replace('\', '/')
            $templatePath = Join-Path $templateRoot $relative
            if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) { throw "$($definition.id): Template-Datei fehlt: $relative" }
            $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $templateHash = (Get-FileHash -LiteralPath $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($sourceHash -ne $templateHash) { throw "$($definition.id): Template ist nicht bytegleich: $relative" }
        }

        $begin = "<!-- BEGIN FULL PROFILE CONTRACT: $($definition.id) -->"
        $end = "<!-- END FULL PROFILE CONTRACT: $($definition.id) -->"
        $beginIndex = [Array]::IndexOf($rootReadmeLines, $begin)
        $endIndex = [Array]::IndexOf($rootReadmeLines, $end)
        if ($beginIndex -lt 0 -or $endIndex -le $beginIndex) { throw "$($definition.id): Vollstaendiger README-Abschnitt fehlt." }
        $segment = [string[]]$rootReadmeLines[($beginIndex + 1)..($endIndex - 1)]
        Assert-OrderedLinesPresent -Expected ([IO.File]::ReadAllLines((Join-Path $templateRoot 'README.md'))) -Actual $segment -Label $definition.id

        $results.Add([pscustomobject]@{
                profile = [string]$definition.id
                files = $expectedFiles.Count
                byte_equal = $true
                readme_complete = $true
                source_worktree = [string]$manifest.source_selected_worktree
            })
    }
    foreach ($required in @(
            'Verbindliche Dateiverantwortung',
            'Verlustfreiheitsregel',
            'Standardablauf pro Arbeitseinheit',
            'Roadmap-Vertrag',
            'Todo-, Checkpoint- und Handoff-Vertrag',
            'Referenz- und Managed-Modus'
        )) {
        if (-not $rootReadmeText.Contains($required, [StringComparison]::Ordinal)) {
            throw "Universeller README-Vertrag fehlt: $required"
        }
    }
    if (-not $Quiet) {
        [pscustomobject]@{
            status = 'ok'
            profiles = @($results)
            universal_readme_lines = $rootReadmeLines.Count
            universal_readme_bytes = (Get-Item -LiteralPath $rootReadmePath).Length
        } | ConvertTo-Json -Depth 8
    }
}
catch {
    [Console]::Error.WriteLine("[REFERENCE] $($_.Exception.Message)")
    exit 1
}
