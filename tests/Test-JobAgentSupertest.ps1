#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$testRoot = $PSScriptRoot
$tests = @(
    'Test-JobAgentSchema.ps1',
    'Test-JobAgentPersistence.ps1',
    'Test-JobAgentCompanyInventory.ps1',
    'Test-JobAgentSourceAdapters.ps1',
    'Test-JobAgentSourceVerification.ps1',
    'Test-JobAgentLiveScan.ps1',
    'Test-JobAgentClassification.ps1',
    'Test-JobAgentDeduplication.ps1',
    'Test-JobAgentStatusMachine.ps1',
    'Test-JobAgentDailyRun.ps1',
    'Test-JobAgentReport.ps1',
    'Test-JobAgentOperations.ps1',
    'Test-JobAgentCoverage.ps1',
    'Test-JobAgentRegisterDiscovery.ps1',
    'Test-JobAgentJobBoardDiscovery.ps1',
    'Test-JobAgentRegionalDiscovery.ps1',
    'Test-JobAgentCompanyDedupeScale.ps1',
    'Test-JobAgentTestMatrix.ps1'
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($test in $tests) {
    $path = Join-Path $testRoot $test
    $output = @(& pwsh -NoProfile -File $path 2>&1)
    $exitCode = $LASTEXITCODE
    $results.Add([pscustomobject]@{
        test = $test
        exit = $exitCode
        output_tail = @($output | Select-Object -Last 8)
    })
    if ($exitCode -ne 0) {
        throw "Supertest-Teiltest fehlgeschlagen: $test`n$($output -join "`n")"
    }
}

[pscustomobject]@{
    status = 'ok'
    tests = @($results.ToArray())
} | ConvertTo-Json -Depth 6
