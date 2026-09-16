Set-StrictMode -Version 3.0

function Get-JobAgentAjvCliPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $cliPath = Join-Path $root 'node_modules\.bin\ajv.cmd'
    if (-not (Test-Path -LiteralPath $cliPath -PathType Leaf)) {
        throw 'Lokale AJV-CLI fehlt. Ausführung nur nach "npm ci --ignore-scripts --offline --cache .ci\\cache\\npm" zulässig.'
    }
    return $cliPath
}

function Invoke-JobAgentAjvCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CliPath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $cachePath = Join-Path $root '.ci\cache\ajv-cli'
    $environmentNames = @('NPM_CONFIG_CACHE', 'TMP', 'TEMP')
    $previousValues = @{}
    foreach ($name in $environmentNames) {
        $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }

    try {
        [Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE', $cachePath, 'Process')
        [Environment]::SetEnvironmentVariable('TMP', $cachePath, 'Process')
        [Environment]::SetEnvironmentVariable('TEMP', $cachePath, 'Process')
        $output = @(& $CliPath @Arguments 2>&1)
        return [pscustomobject]@{
            exit = $LASTEXITCODE
            output = @($output | ForEach-Object { [string]$_ })
            cache_path = $cachePath
        }
    }
    finally {
        foreach ($name in $environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process')
        }
    }
}

Export-ModuleMember -Function Get-JobAgentAjvCliPath, Invoke-JobAgentAjvCli
