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
        session_names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        daemon_pids = [Collections.Generic.HashSet[int]]::new()
    }
}

function Get-JobAgentPlaywrightSessionName {
    param([Parameter(Mandatory)][string[]]$Arguments)

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        if ($Arguments[$index] -eq '--session' -and $index + 1 -lt $Arguments.Count) {
            return $Arguments[$index + 1]
        }
        if ($Arguments[$index] -like '--session=*') {
            return $Arguments[$index].Substring('--session='.Length)
        }
    }
    return 'default'
}

function Invoke-JobAgentPlaywrightProcess {
    param(
        [Parameter(Mandatory)][string]$NodePath,
        [Parameter(Mandatory)][string]$CliScript,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][object]$RunEnvironment,
        [int]$TimeoutSeconds = 120
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $NodePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Environment['NPM_CONFIG_CACHE'] = Join-Path $RunEnvironment.repository_root '.ci\cache\npm'
    $startInfo.Environment['TMP'] = $RunEnvironment.temp_root
    $startInfo.Environment['TEMP'] = $RunEnvironment.temp_root
    $startInfo.Environment['LOCALAPPDATA'] = $RunEnvironment.local_app_data
    $startInfo.Environment['NO_UPDATE_NOTIFIER'] = '1'
    $startInfo.Environment['CI'] = '1'
    $startInfo.ArgumentList.Add($CliScript)
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Die projektlokale Playwright-CLI konnte nicht gestartet werden.'
    }

    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        $process.WaitForExit()
        [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))
        throw "Playwright-CLI-Ueberlauf nach $TimeoutSeconds Sekunden: $($Arguments -join ' ')."
    }
    [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))

    [pscustomobject]@{
        exit_code = $process.ExitCode
        output = (($stdout.GetAwaiter().GetResult(), $stderr.GetAwaiter().GetResult() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine)
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

    if ($RunEnvironment.PSObject.Properties.Match('repository_root').Count -eq 0) {
        $RunEnvironment | Add-Member -NotePropertyName repository_root -NotePropertyValue $root
        $RunEnvironment | Add-Member -NotePropertyName node_path -NotePropertyValue $nodeCommand.Source
        $RunEnvironment | Add-Member -NotePropertyName cli_script -NotePropertyValue $matchingCliPackages[0].cli_script
    }

    $effectiveArguments = [Collections.Generic.List[string]]::new([string[]]$Arguments)
    $openIndex = $effectiveArguments.IndexOf('open')
    $sessionName = Get-JobAgentPlaywrightSessionName -Arguments $effectiveArguments.ToArray()
    if ($openIndex -ge 0) {
        $RunEnvironment.session_names.Add($sessionName) | Out-Null
        if (-not (@($effectiveArguments | Where-Object { $_ -like '--idle-timeout=*' -or $_ -eq '--idle-timeout' }).Count -gt 0)) {
            $effectiveArguments.Insert($openIndex, '--idle-timeout=120000')
        }
    }

    $result = Invoke-JobAgentPlaywrightProcess -NodePath $nodeCommand.Source -CliScript $matchingCliPackages[0].cli_script -WorkingDirectory $WorkingDirectory -Arguments $effectiveArguments.ToArray() -RunEnvironment $RunEnvironment
    if ($result.exit_code -ne 0) {
        throw ('Playwright-CLI fehlgeschlagen: ' + $result.output)
    }
    if ($openIndex -ge 0) {
        foreach ($match in [regex]::Matches($result.output, '(?i)\bpid[= ](?<pid>\d+)')) {
            $RunEnvironment.daemon_pids.Add([int]$match.Groups['pid'].Value) | Out-Null
        }
    }
    return $result.output
}

function Remove-JobAgentPlaywrightRunEnvironment {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$RunEnvironment)

    if ($RunEnvironment.PSObject.Properties.Match('node_path').Count -gt 0 -and $RunEnvironment.PSObject.Properties.Match('cli_script').Count -gt 0) {
        foreach ($sessionName in @($RunEnvironment.session_names)) {
            try {
                Invoke-JobAgentPlaywrightProcess -NodePath $RunEnvironment.node_path -CliScript $RunEnvironment.cli_script -WorkingDirectory $RunEnvironment.run_root -Arguments @('--session', $sessionName, 'close') -RunEnvironment $RunEnvironment -TimeoutSeconds 15 | Out-Null
            }
            catch {
                Write-Warning "Playwright-Sitzung '$sessionName' konnte nicht regulaer geschlossen werden: $($_.Exception.Message)"
            }
        }
        foreach ($processId in @($RunEnvironment.daemon_pids)) {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($null -ne $process -and -not $process.HasExited) {
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            }
        }
    }
    if (Test-Path -LiteralPath $RunEnvironment.run_root) {
        Remove-Item -LiteralPath $RunEnvironment.run_root -Recurse -Force -ErrorAction Stop
    }
}

Export-ModuleMember -Function New-JobAgentPlaywrightRunEnvironment, Invoke-JobAgentPlaywrightCliIsolated, Remove-JobAgentPlaywrightRunEnvironment
