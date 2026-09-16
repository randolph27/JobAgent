#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Supertest.psm1') -Force
$tests = @(Get-JobAgentSupertestPlan -RepositoryRoot $root)

$results = New-Object System.Collections.Generic.List[object]
foreach ($test in $tests) {
    $path = Join-Path $root ([string]$test.test_file)
    $output = @(& pwsh -NoProfile -File $path 2>&1)
    $exitCode = $LASTEXITCODE
    $results.Add([pscustomobject]@{
        roadmap_id = [string]$test.roadmap_id
        test = [string]$test.test_file
        command = [string]$test.command
        exit = $exitCode
        output_tail = @($output | Select-Object -Last 8)
    })
    if ($exitCode -ne 0) {
        throw "Supertest-Teiltest fehlgeschlagen: $($test.test_file)`n$($output -join "`n")"
    }
}

[pscustomobject]@{
    status = 'ok'
    planned_test_count = @($tests).Count
    tests = @($results.ToArray())
} | ConvertTo-Json -Depth 6
