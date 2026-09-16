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

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $npmCache = Join-Path $root '.ci\cache\npm'
    if (-not (Test-Path -LiteralPath $npmCache -PathType Container)) {
        throw 'Projektlokaler npm-Cache fehlt; die Playwright-CLI wird fail-closed nicht nachgeladen.'
    }
    $runtimeConfigPath = Join-Path $root '.ci\playwright-cli.runtime.json'
    if (-not (Test-Path -LiteralPath $runtimeConfigPath -PathType Leaf)) {
        throw 'Playwright-Laufzeitpin fehlt; die CLI wird fail-closed nicht aufgeloest.'
    }
    $runtimeConfig = Get-Content -LiteralPath $runtimeConfigPath -Raw | ConvertFrom-Json -Depth 10
    if ($runtimeConfig.schema_version -ne 'jobagent-playwright-cli-runtime/v1' -or $runtimeConfig.cli_package -ne '@playwright/cli' -or [string]::IsNullOrWhiteSpace([string]$runtimeConfig.cli_version) -or [string]::IsNullOrWhiteSpace([string]$runtimeConfig.playwright_core_version)) {
        throw 'Playwright-Laufzeitpin ist ungueltig; die CLI wird fail-closed nicht aufgeloest.'
    }
    $cliCandidates = @(
        Get-ChildItem -LiteralPath (Join-Path $npmCache '_npx') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'node_modules\@playwright\cli\package.json' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
    $matchingCliPackages = @(
        foreach ($candidate in $cliCandidates) {
            $manifest = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json -Depth 10
            $nodeModulesPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $candidate))
            $coreManifestPath = Join-Path $nodeModulesPath 'playwright-core\package.json'
            if (([string]$manifest.name -eq [string]$runtimeConfig.cli_package) -and ([string]$manifest.version -eq [string]$runtimeConfig.cli_version) -and (Test-Path -LiteralPath $coreManifestPath -PathType Leaf)) {
                $coreManifest = Get-Content -LiteralPath $coreManifestPath -Raw | ConvertFrom-Json -Depth 10
                if ([string]$coreManifest.version -eq [string]$runtimeConfig.playwright_core_version) {
                    [pscustomobject]@{ cli_script = Join-Path (Split-Path -Parent $candidate) 'playwright-cli.js' }
                }
            }
        }
    )
    if ($matchingCliPackages.Count -ne 1 -or -not (Test-Path -LiteralPath $matchingCliPackages[0].cli_script -PathType Leaf)) {
        throw 'Projektlokale Playwright-Laufzeit entspricht nicht dem Pin; die CLI wird fail-closed nicht aufgeloest.'
    }
    $nodeCommand = Get-Command -Name 'node.exe' -ErrorAction SilentlyContinue
    if ($null -eq $nodeCommand) {
        throw 'node.exe fehlt; die gepinnte projektlokale Playwright-CLI kann nicht gestartet werden.'
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

        $output = @(& $nodeCommand.Source $matchingCliPackages[0].cli_script @Arguments 2>&1)
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
