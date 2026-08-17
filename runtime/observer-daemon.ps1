#requires -Version 7.4

[CmdletBinding()]
param(
    [ValidateRange(5, 86400)]
    [int]$IntervalSeconds = 120
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$ciCmd = Join-Path $repoRoot 'ci.cmd'
if (-not (Test-Path -LiteralPath $ciCmd -PathType Leaf)) {
    throw "CI-Launcher fehlt: $ciCmd"
}

while ($true) {
    try {
        & $ciCmd tick
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[OBSERVER] tick exit=$LASTEXITCODE")
        }
    }
    catch {
        [Console]::Error.WriteLine("[OBSERVER] $($_.Exception.Message)")
    }
    Start-Sleep -Seconds $IntervalSeconds
}
