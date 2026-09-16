#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'JobAgent.PlaywrightEnvironment.psm1') -Force

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$runId = 'tooling-' + [guid]::NewGuid().ToString('N')
$environment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $root -RunId $runId
$variables = @('NPM_CONFIG_CACHE', 'TMP', 'TEMP', 'LOCALAPPDATA', 'NO_UPDATE_NOTIFIER', 'CI')
$before = @{}
foreach ($name in $variables) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

try {
    Assert-True -Condition ($environment.run_root.StartsWith((Join-Path $root '.ci\cache\playwright'), [StringComparison]::OrdinalIgnoreCase)) -Message 'Playwright-Laufpfad liegt nicht im projektlokalen Cache.'
    Assert-True -Condition ($environment.local_app_data -eq $environment.run_root) -Message 'LOCALAPPDATA ist nicht auf den projektlokalen Laufpfad begrenzt.'
    Assert-True -Condition (Test-Path -LiteralPath $environment.temp_root -PathType Container) -Message 'Projektlokaler Playwright-Temppfad fehlt.'

    $version = Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $environment -WorkingDirectory $root -Arguments @('--version')
    Assert-True -Condition ($version -match '\d+\.\d+\.\d+') -Message 'Projektlokale Playwright-CLI liefert keine Version.'
    foreach ($name in $variables) {
        Assert-True -Condition (([string][Environment]::GetEnvironmentVariable($name, 'Process')) -eq ([string]$before[$name])) -Message "Prozessumgebung '$name' wurde nicht wiederhergestellt."
    }

    $missingRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-missing-playwright-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.Directory]::CreateDirectory($missingRoot) | Out-Null
        $missingEnvironment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $missingRoot -RunId 'missing'
        $failedClosed = $false
        try { Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $missingRoot -RunEnvironment $missingEnvironment -WorkingDirectory $missingRoot -Arguments @('--version') | Out-Null } catch { $failedClosed = $_.Exception.Message -match 'npm-Cache fehlt' }
        Assert-True -Condition $failedClosed -Message 'Fehlender projektlokaler Playwright-Cache wird nicht fail-closed abgelehnt.'
    }
    finally {
        if (Test-Path -LiteralPath $missingRoot) { Remove-Item -LiteralPath $missingRoot -Recurse -Force }
    }
}
finally {
    Remove-JobAgentPlaywrightRunEnvironment -RunEnvironment $environment
}

Assert-True -Condition (-not (Test-Path -LiteralPath $environment.run_root)) -Message 'Projektlokale Playwright-Tempartefakte wurden nicht bereinigt.'
[pscustomobject]@{ status = 'ok'; cases = @('project_local_daemon_and_temp_paths', 'environment_restoration', 'missing_local_cli_cache_fail_closed', 'cleanup') } | ConvertTo-Json -Depth 5
