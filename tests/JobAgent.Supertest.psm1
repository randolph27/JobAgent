Set-StrictMode -Version 3.0

function Get-JobAgentSupertestPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $matrixPath = Join-Path $root 'docs\test-matrix.json'
    if (-not (Test-Path -LiteralPath $matrixPath -PathType Leaf)) { throw "Supertest-Matrix fehlt: $matrixPath" }

    $matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json -Depth 100
    $selected = @($matrix.items | Where-Object {
            $_.include_in_supertest -eq $true -and [string]$_.status -eq 'done'
        } | Sort-Object @{ Expression = { [int]$_.supertest_order } }, roadmap_id)
    if ($selected.Count -eq 0) { throw 'Supertest-Matrix enthält keine freigegebenen abgeschlossenen Tests.' }

    $seenFiles = @{}
    foreach ($entry in $selected) {
        foreach ($property in @('roadmap_id', 'test_file', 'command', 'status', 'include_in_supertest', 'lane', 'supertest_order')) {
            if (-not ($entry.PSObject.Properties.Name -contains $property)) { throw "Supertest-Matrixeintrag $($entry.roadmap_id) fehlt $property." }
        }
        if ([int]$entry.supertest_order -lt 1) { throw "Supertest-Matrixeintrag $($entry.roadmap_id) hat keine positive supertest_order." }
        $relativePath = [string]$entry.test_file
        $fileName = Split-Path -Leaf $relativePath
        if ($fileName -eq 'Test-JobAgentSupertest.ps1') { throw 'Supertest darf sich nicht selbst aufnehmen.' }
        if ($seenFiles.ContainsKey($fileName)) { throw "Supertest-Matrix enthält den Test doppelt: $fileName" }
        if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) { throw "Supertest-Matrix referenziert fehlende Testdatei: $relativePath" }
        $seenFiles[$fileName] = $true
    }
    $orders = @($selected | ForEach-Object { [int]$_.supertest_order })
    if (@($orders | Select-Object -Unique).Count -ne $orders.Count) { throw 'Supertest-Matrix enthält doppelte supertest_order-Werte.' }
    return @($selected)
}

function Write-JobAgentSupertestReport {
    param([Parameter(Mandatory)]$Report, [Parameter(Mandatory)][string]$ReportPath)

    $directory = Split-Path -Parent $ReportPath
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporaryPath = Join-Path $directory (".{0}.{1}.tmp" -f (Split-Path -Leaf $ReportPath), [guid]::NewGuid().ToString('N'))
    try {
        $Report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryPath -Encoding utf8NoBOM
        Move-Item -LiteralPath $temporaryPath -Destination $ReportPath -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}

function Invoke-JobAgentSupertestChild {
    param(
        [Parameter(Mandatory)][string]$TestPath,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )

    $start = [DateTimeOffset]::UtcNow
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'pwsh'
    $info.Arguments = "-NoProfile -File `"$TestPath`""
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw 'Child-Prozess konnte nicht gestartet werden.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            $process.WaitForExit()
            $status = 'blocked'; $errorKind = 'timeout'; $exitCode = $null
        } else {
            $status = if ($process.ExitCode -eq 0) { 'passed' } elseif ($process.ExitCode -eq 130) { 'blocked' } else { 'failed' }
            $errorKind = if ($process.ExitCode -eq 130) { 'aborted' } elseif ($process.ExitCode -eq 0) { $null } else { 'nonzero-exit' }
            $exitCode = $process.ExitCode
        }
        [pscustomobject]@{
            status = $status; error_kind = $errorKind; exit = $exitCode
            stdout = $stdoutTask.GetAwaiter().GetResult(); stderr = $stderrTask.GetAwaiter().GetResult()
            started_at = $start.ToString('o'); ended_at = [DateTimeOffset]::UtcNow.ToString('o')
            pwsh_version = $PSVersionTable.PSVersion.ToString(); working_directory = $WorkingDirectory
        }
    } finally { $process.Dispose() }
}

function Invoke-JobAgentSupertestRunner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$TestPlan,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$ReportPath,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 600
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $results = [Collections.Generic.List[object]]::new()
    $failureSeen = $false
    for ($index = 0; $index -lt $TestPlan.Count; $index++) {
        $test = $TestPlan[$index]
        $relativePath = if ($null -ne $test -and $test.PSObject.Properties.Name -contains 'test_file') { [string]$test.test_file } else { '' }
        $roadmapId = if ($null -ne $test -and $test.PSObject.Properties.Name -contains 'roadmap_id') { [string]$test.roadmap_id } else { "plan-$index" }
        if ($failureSeen) {
            $results.Add([pscustomobject]@{ roadmap_id = $roadmapId; test = $relativePath; status = 'not-run'; reason = 'Vorheriger Pflichtfall ist fehlgeschlagen oder blockiert.' })
            continue
        }
        $testPath = if ([string]::IsNullOrWhiteSpace($relativePath)) { $null } else { Join-Path $root $relativePath }
        if ($null -eq $testPath -or -not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
            $result = [pscustomobject]@{ roadmap_id = $roadmapId; test = $relativePath; status = 'failed'; error_kind = 'invalid-result-data'; reason = 'Testplan referenziert keine vorhandene Testdatei.'; command = $null; exit = $null; stdout = ''; stderr = ''; started_at = [DateTimeOffset]::UtcNow.ToString('o'); ended_at = [DateTimeOffset]::UtcNow.ToString('o'); pwsh_version = $PSVersionTable.PSVersion.ToString(); working_directory = $root }
        } else {
            $child = Invoke-JobAgentSupertestChild -TestPath $testPath -WorkingDirectory $root -TimeoutSeconds $TimeoutSeconds
            $result = [pscustomobject]@{ roadmap_id = $roadmapId; test = $relativePath; command = "pwsh -NoProfile -File $relativePath"; status = $child.status; error_kind = $child.error_kind; exit = $child.exit; stdout = $child.stdout; stderr = $child.stderr; started_at = $child.started_at; ended_at = $child.ended_at; pwsh_version = $child.pwsh_version; working_directory = $child.working_directory }
        }
        $results.Add($result)
        if ($result.status -ne 'passed') { $failureSeen = $true }
    }
    $status = if (@($results | Where-Object { $_.status -eq 'failed' }).Count -gt 0) { 'failed' } elseif (@($results | Where-Object { $_.status -eq 'blocked' }).Count -gt 0) { 'blocked' } else { 'passed' }
    $report = [pscustomobject]@{ schema_version = 'jobagent-supertest/v2'; status = $status; planned_test_count = $TestPlan.Count; passed = @($results | Where-Object status -eq 'passed').Count; failed = @($results | Where-Object status -eq 'failed').Count; blocked = @($results | Where-Object status -eq 'blocked').Count; not_run = @($results | Where-Object status -eq 'not-run').Count; generated_at = [DateTimeOffset]::UtcNow.ToString('o'); tests = @($results) }
    Write-JobAgentSupertestReport -Report $report -ReportPath $ReportPath
    return $report
}

Export-ModuleMember -Function Get-JobAgentSupertestPlan, Invoke-JobAgentSupertestRunner
