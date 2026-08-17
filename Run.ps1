#requires -Version 7.4

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if ($args.Count -lt 1) {
    [Console]::Error.WriteLine('[BOOTSTRAP] Run erfordert als erstes Argument den Projektpfad.')
    exit 2
}

$targetRoot = [string]$args[0]
$ciArguments = if ($args.Count -gt 1) { @($args[1..($args.Count - 1)]) } else { @() }
$manager = Join-Path $PSScriptRoot 'Bootstrap.ps1'
$managerParameters = @{
    Command = 'Run'
    TargetRoot = $targetRoot
    CiArguments = [string[]]$ciArguments
}

& $manager @managerParameters
exit $LASTEXITCODE
