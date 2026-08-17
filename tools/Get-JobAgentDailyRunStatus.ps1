#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))),
    [Parameter()][string]$LogRoot = 'logs/jobagent'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repoRoot 'src\JobAgent.Operations.psm1') -Force -DisableNameChecking

Get-JobAgentDailyRunOperationalStatus -ProjectRoot $ProjectRoot -LogRoot $LogRoot |
    ConvertTo-Json -Depth 40
