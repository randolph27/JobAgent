#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Supertest.psm1') -Force
$plan = @(Get-JobAgentSupertestPlan -RepositoryRoot $root)
$runId = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$reportPath = Join-Path $root ("logs\jobagent\QA-006\$runId\summary.json")
$report = Invoke-JobAgentSupertestRunner -TestPlan $plan -RepositoryRoot $root -ReportPath $reportPath
$report | ConvertTo-Json -Depth 12
if ($report.status -ne 'passed') { exit 1 }
