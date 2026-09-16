Set-StrictMode -Version 3.0

function New-JobAgentPlaywrightRunEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RunId
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $cacheRoot = Join-Path $root '.ci\cache\playwright'
    $runRoot = Join-Path $cacheRoot $RunId
    $tempRoot = Join-Path $runRoot 'tmp'
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    return [pscustomobject]@{
        cache_root = $cacheRoot
        run_root = $runRoot
        temp_root = $tempRoot
        local_app_data = $runRoot
    }
}

function Invoke-JobAgentPlaywrightCliIsolated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][object]$RunEnvironment,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $npxCommand = Get-Command -Name 'npx.cmd' -ErrorAction SilentlyContinue
    if ($null -eq $npxCommand) {
        throw 'npx.cmd fehlt; der Browser-Audit benoetigt die projektlokal gecachte Playwright-CLI.'
    }

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $npmCache = Join-Path $root '.ci\cache\npm'
    if (-not (Test-Path -LiteralPath $npmCache -PathType Container)) {
        throw 'Projektlokaler npm-Cache fehlt; die Playwright-CLI wird fail-closed nicht nachgeladen.'
    }

    $environmentNames = @('NPM_CONFIG_CACHE', 'TMP', 'TEMP', 'LOCALAPPDATA', 'NO_UPDATE_NOTIFIER', 'CI')
    $previousValues = @{}
    foreach ($name in $environmentNames) {
        $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }

    Push-Location -LiteralPath $WorkingDirectory
    try {
        [Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE', $npmCache, 'Process')
        [Environment]::SetEnvironmentVariable('TMP', $RunEnvironment.temp_root, 'Process')
        [Environment]::SetEnvironmentVariable('TEMP', $RunEnvironment.temp_root, 'Process')
        [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $RunEnvironment.local_app_data, 'Process')
        [Environment]::SetEnvironmentVariable('NO_UPDATE_NOTIFIER', '1', 'Process')
        [Environment]::SetEnvironmentVariable('CI', '1', 'Process')

        $output = @(& $npxCommand.Source --no-install --package '@playwright/cli' playwright-cli @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw ('Playwright-CLI fehlgeschlagen: ' + ($output -join [Environment]::NewLine))
        }
        return ($output -join [Environment]::NewLine)
    }
    finally {
        Pop-Location
        foreach ($name in $environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process')
        }
    }
}

function Remove-JobAgentPlaywrightRunEnvironment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$RunEnvironment)

    if (Test-Path -LiteralPath $RunEnvironment.run_root) {
        Remove-Item -LiteralPath $RunEnvironment.run_root -Recurse -Force -ErrorAction Stop
    }
}

Export-ModuleMember -Function New-JobAgentPlaywrightRunEnvironment, Invoke-JobAgentPlaywrightCliIsolated, Remove-JobAgentPlaywrightRunEnvironment
