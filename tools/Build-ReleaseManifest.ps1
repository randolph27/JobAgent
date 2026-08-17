#requires -Version 7.4

[CmdletBinding()]
param(
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version = '1.0.0'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = Join-Path $bootstrapRoot 'bootstrap.manifest.json'
$roots = @('runtime', 'schemas', 'catalog', 'profiles', 'templates', 'tests', 'tools', 'docs')
$files = [Collections.Generic.List[IO.FileInfo]]::new()
foreach ($relative in @('Bootstrap.ps1', 'bootstrap.cmd', 'Run.ps1', 'run.cmd', 'README.md', 'CHANGELOG.md')) {
    $path = Join-Path $bootstrapRoot $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) { $files.Add((Get-Item -LiteralPath $path -Force)) }
}
foreach ($relativeRoot in $roots) {
    $path = Join-Path $bootstrapRoot $relativeRoot
    if (Test-Path -LiteralPath $path -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $path -Recurse -File -Force | Sort-Object FullName)) {
            $files.Add($file)
        }
    }
}

$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$records = foreach ($file in @($files | Sort-Object FullName -Unique)) {
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse Point ist im Release nicht erlaubt: $($file.FullName)"
    }
    $relative = [IO.Path]::GetRelativePath($bootstrapRoot, $file.FullName).Replace('\', '/')
    if ($relative -eq 'bootstrap.manifest.json') { continue }
    if (-not $seen.Add($relative)) { throw "Doppelter Release-Pfad: $relative" }
    if ($IsWindows) {
        $streams = @(Get-Item -LiteralPath $file.FullName -Stream * -ErrorAction SilentlyContinue |
                Where-Object Stream -ne ':$DATA')
        if ($streams.Count -gt 0) { throw "Alternate Data Stream ist im Release nicht erlaubt: $relative" }
    }
    [ordered]@{
        path = $relative
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        size = [long]$file.Length
    }
}

$manifest = [ordered]@{
    schema = 'workflow-bootstrap-release/v1'
    version = $Version
    generated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    files = @($records)
}
$json = $manifest | ConvertTo-Json -Depth 10
$temporary = "$manifestPath.tmp.$PID.$([Guid]::NewGuid().ToString('N'))"
try {
    [IO.File]::WriteAllText($temporary, $json + "`n", [Text.UTF8Encoding]::new($false))
    $null = Get-Content -Raw -LiteralPath $temporary | ConvertFrom-Json
    [IO.File]::Move($temporary, $manifestPath, $true)
}
finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
}

[pscustomobject]@{
    version = $Version
    files = @($records).Count
    manifest = $manifestPath
} | Format-List
