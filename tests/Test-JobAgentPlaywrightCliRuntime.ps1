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

function Write-Utf8File {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)
    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

$runId = 'cli-runtime-' + [guid]::NewGuid().ToString('N')
$environment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $root -RunId $runId
$variables = @('NPM_CONFIG_CACHE', 'TMP', 'TEMP', 'LOCALAPPDATA', 'NO_UPDATE_NOTIFIER', 'CI')
$before = @{}
foreach ($name in $variables) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }

try {
    $configPath = Join-Path $environment.run_root 'playwright-cli.config.json'
    Write-Utf8File -Path $configPath -Content (@{
            browser = @{
                launchOptions = @{
                    channel = 'chrome'
                    headless = $true
                    args = @('--no-sandbox')
                }
            }
        } | ConvertTo-Json -Depth 10)

    $sessionName = 'jobagent-cli-runtime-' + [guid]::NewGuid().ToString('N')
    $openOutput = Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $environment -WorkingDirectory $environment.run_root -Arguments @('--session', $sessionName, '--config', $configPath, 'open', 'about:blank')
    Assert-True -Condition ($openOutput -match 'opened with pid') -Message 'Die projektlokale Playwright-CLI konnte keine Chrome-Sitzung oeffnen.'

    $snapshotOutput = Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $environment -WorkingDirectory $environment.run_root -Arguments @('--session', $sessionName, 'snapshot')
    Assert-True -Condition ($snapshotOutput -match 'Page URL: about:blank') -Message 'Die geoeffnete Playwright-Sitzung liefert keinen Snapshot fuer about:blank.'

    $closeOutput = Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $environment -WorkingDirectory $environment.run_root -Arguments @('--session', $sessionName, 'close')
    Assert-True -Condition ($closeOutput -match 'closed') -Message 'Die projektlokale Playwright-Sitzung konnte nicht geschlossen werden.'

    foreach ($name in $variables) {
        Assert-True -Condition (([string][Environment]::GetEnvironmentVariable($name, 'Process')) -eq ([string]$before[$name])) -Message "Prozessumgebung '$name' wurde nicht wiederhergestellt."
    }
}
finally {
    Remove-JobAgentPlaywrightRunEnvironment -RunEnvironment $environment
}

Assert-True -Condition (-not (Test-Path -LiteralPath $environment.run_root)) -Message 'Projektlokale Playwright-CLI-Artefakte wurden nicht bereinigt.'
[pscustomobject]@{ status = 'ok'; cases = @('local_cli_open', 'local_cli_snapshot', 'local_cli_close', 'environment_restoration', 'cleanup') } | ConvertTo-Json -Depth 5
