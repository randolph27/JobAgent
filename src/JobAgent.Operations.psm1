#requires -Version 7.4

Set-StrictMode -Version 3.0

function ConvertTo-JobAgentOperationIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-JobAgentOperationStamp {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-JobAgentOperationRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectRoot)

    return [IO.Path]::GetFullPath($ProjectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Assert-JobAgentOperationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $root = Resolve-JobAgentOperationRoot -ProjectRoot $ProjectRoot
    $resolved = [IO.Path]::GetFullPath($Path)
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (($resolved -ne $root) -and (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Pfad liegt ausserhalb des Projektverzeichnisses: $resolved"
    }
    return $resolved
}

function Get-JobAgentOperationPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$LogRoot = 'logs/jobagent'
    )

    $root = Resolve-JobAgentOperationRoot -ProjectRoot $ProjectRoot
    $logPath = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $root $LogRoot }
    $logPath = Assert-JobAgentOperationPath -ProjectRoot $root -Path $logPath
    [pscustomobject]@{
        project_root = $root
        log_root = $logPath
        lock_path = Join-Path $logPath 'daily-run.lock'
        status_path = Join-Path $logPath 'daily-run.status.json'
    }
}

function Write-JobAgentOperationAtomicFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $temporaryPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $encoding = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($temporaryPath, $Content + "`n", $encoding)
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Write-JobAgentDailyRunStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Paths,
        [Parameter(Mandatory)][object]$Status
    )

    Write-JobAgentOperationAtomicFile -Path ([string]$Paths.status_path) -Content ($Status | ConvertTo-Json -Depth 40)
    return [string]$Paths.status_path
}

function Test-JobAgentOperationProcessAlive {
    param([Parameter(Mandatory)][int]$ProcessId)

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        return $null -ne $process
    }
    catch {
        return $false
    }
}

function Get-JobAgentOperationProperty {
    param(
        [Parameter()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()]$Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }
    return $property.Value
}

function Get-JobAgentDailyRunDisplayState {
    param(
        [Parameter(Mandatory)][string]$State,
        [Parameter()][AllowNull()][object]$Result = $null
    )

    if ($State -eq 'RUNNING') {
        return 'laeuft'
    }
    if ($State -eq 'FAILED') {
        return 'fehlgeschlagen'
    }
    $resultStatus = [string](Get-JobAgentOperationProperty -InputObject $Result -Name 'status')
    if ($resultStatus -eq 'PARTIAL') {
        return 'teilweise'
    }
    return 'abgeschlossen'
}

function Get-JobAgentDailyRunReason {
    param([Parameter()][AllowNull()][object]$Result = $null)

    $acquisition = Get-JobAgentOperationProperty -InputObject $Result -Name 'acquisition'
    if ($null -ne $acquisition -and [string](Get-JobAgentOperationProperty -InputObject $acquisition -Name 'status') -eq 'PARTIAL') {
        return [string](Get-JobAgentOperationProperty -InputObject $acquisition -Name 'reason' -Default 'Akquise nur teilweise abgeschlossen.')
    }
    return $null
}

function Get-JobAgentDailyRunWakeAt {
    param([Parameter()][AllowNull()][object]$Result = $null)

    $directWakeAt = Get-JobAgentOperationProperty -InputObject $Result -Name 'wake_at'
    if (-not [string]::IsNullOrWhiteSpace([string]$directWakeAt)) {
        return [string]$directWakeAt
    }
    $acquisition = Get-JobAgentOperationProperty -InputObject $Result -Name 'acquisition'
    $acquisitionWakeAt = Get-JobAgentOperationProperty -InputObject $acquisition -Name 'wake_at'
    if (-not [string]::IsNullOrWhiteSpace([string]$acquisitionWakeAt)) {
        return [string]$acquisitionWakeAt
    }
    return $null
}

function Read-JobAgentDailyRunLockPayload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LockPath)

    if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) {
        return $null
    }
    try {
        return Get-Content -LiteralPath $LockPath -Raw | ConvertFrom-Json -Depth 20
    }
    catch {
        return [pscustomobject]@{
            pid = $null
            acquired_at = $null
            unreadable = $true
        }
    }
}

function Test-JobAgentDailyRunLockStale {
    [CmdletBinding()]
    param(
        [Parameter()][object]$Payload,
        [Parameter()][datetime]$Now = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 10080)][int]$StaleAfterMinutes = 240
    )

    if ($null -eq $Payload) {
        return $false
    }
    if ($Payload.PSObject.Properties['unreadable'] -and $Payload.unreadable -eq $true) {
        return $false
    }
    $pidValue = 0
    $hasPid = [int]::TryParse([string]$Payload.pid, [ref]$pidValue)
    if ($hasPid -and (Test-JobAgentOperationProcessAlive -ProcessId $pidValue)) {
        return $false
    }
    try {
        $acquiredAt = [datetime]::Parse([string]$Payload.acquired_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
        return $acquiredAt.AddMinutes($StaleAfterMinutes) -lt $Now.ToUniversalTime()
    }
    catch {
        return $true
    }
}

function Enter-JobAgentDailyRunLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Paths,
        [Parameter()][ValidateRange(1, 10080)][int]$StaleAfterMinutes = 240
    )

    if (-not (Test-Path -LiteralPath ([string]$Paths.log_root))) {
        New-Item -ItemType Directory -Path ([string]$Paths.log_root) -Force | Out-Null
    }

    try {
        $stream = [IO.File]::Open([string]$Paths.lock_path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    }
    catch [IO.IOException] {
        $payload = Read-JobAgentDailyRunLockPayload -LockPath ([string]$Paths.lock_path)
        if (Test-JobAgentDailyRunLockStale -Payload $payload -StaleAfterMinutes $StaleAfterMinutes) {
            Remove-Item -LiteralPath ([string]$Paths.lock_path) -Force -ErrorAction Stop
            $stream = [IO.File]::Open([string]$Paths.lock_path, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        }
        else {
            throw "Daily-Run laeuft bereits oder Lock ist aktiv: $($Paths.lock_path)"
        }
    }

    $payload = [pscustomobject]@{
        pid = $PID
        acquired_at = ConvertTo-JobAgentOperationIso -Value ([datetime]::UtcNow)
        project_root = [string]$Paths.project_root
    } | ConvertTo-Json -Depth 8
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($payload)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)

    return [pscustomobject]@{
        stream = $stream
        lock_path = [string]$Paths.lock_path
    }
}

function Exit-JobAgentDailyRunLock {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Lock)

    if ($Lock.stream) {
        $Lock.stream.Dispose()
    }
    if ($Lock.lock_path -and (Test-Path -LiteralPath ([string]$Lock.lock_path))) {
        Remove-Item -LiteralPath ([string]$Lock.lock_path) -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-JobAgentLogRotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter()][ValidateRange(1, 1000)][int]$RetainLogs = 30
    )

    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
        return @()
    }
    $candidates = @(Get-ChildItem -LiteralPath $LogRoot -File -Filter 'daily-run-*.log' |
            Sort-Object -Property LastWriteTimeUtc -Descending)
    $removed = New-Object System.Collections.Generic.List[string]
    foreach ($file in @($candidates | Select-Object -Skip $RetainLogs)) {
        Remove-Item -LiteralPath $file.FullName -Force
        $removed.Add($file.FullName)
    }
    return $removed.ToArray()
}

function Get-JobAgentDailyRunOperationalStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter()][string]$LogRoot = 'logs/jobagent'
    )

    $paths = Get-JobAgentOperationPaths -ProjectRoot $ProjectRoot -LogRoot $LogRoot
    $storedStatus = $null
    if (Test-Path -LiteralPath ([string]$paths.status_path) -PathType Leaf) {
        try {
            $storedStatus = Get-Content -LiteralPath ([string]$paths.status_path) -Raw | ConvertFrom-Json -Depth 40
        }
        catch {
            $storedStatus = [pscustomobject]@{
                state = 'CORRUPT'
                error = $_.Exception.Message
            }
        }
    }
    $lockPayload = Read-JobAgentDailyRunLockPayload -LockPath ([string]$paths.lock_path)
    $isRunning = $false
    if ($null -ne $lockPayload) {
        if ($lockPayload.PSObject.Properties['unreadable'] -and $lockPayload.unreadable -eq $true) {
            $isRunning = $true
        }
        else {
            $pidValue = 0
            if ([int]::TryParse([string]$lockPayload.pid, [ref]$pidValue)) {
            $isRunning = Test-JobAgentOperationProcessAlive -ProcessId $pidValue
            }
        }
    }

    [pscustomobject]@{
        state = if ($isRunning) { 'RUNNING' } elseif ($storedStatus) { [string]$storedStatus.state } else { 'UNKNOWN' }
        display_state = if ($isRunning) { 'laeuft' } elseif ($storedStatus -and $storedStatus.PSObject.Properties.Name -contains 'display_state') { [string]$storedStatus.display_state } else { 'unbekannt' }
        is_running = $isRunning
        status_path = [string]$paths.status_path
        lock_path = [string]$paths.lock_path
        lock = $lockPayload
        last_status = $storedStatus
    }
}

function Invoke-JobAgentManagedDailyRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter()][string]$LogRoot = 'logs/jobagent',
        [Parameter()][ValidateRange(1, 1000)][int]$RetainLogs = 30,
        [Parameter()][ValidateRange(1, 10080)][int]$StaleAfterMinutes = 240,
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow
    )

    $paths = Get-JobAgentOperationPaths -ProjectRoot $ProjectRoot -LogRoot $LogRoot
    $stamp = ConvertTo-JobAgentOperationStamp -Value $StartedAt
    $runLogPath = Join-Path ([string]$paths.log_root) ('daily-run-' + $stamp + '.log')
    $lock = Enter-JobAgentDailyRunLock -Paths $paths -StaleAfterMinutes $StaleAfterMinutes
    $previousStatus = $null
    if (Test-Path -LiteralPath ([string]$paths.status_path) -PathType Leaf) {
        try {
            $previousStatus = Get-Content -LiteralPath ([string]$paths.status_path) -Raw | ConvertFrom-Json -Depth 40
        }
        catch {
            $previousStatus = $null
        }
    }
    $runId = 'dailyrun:' + $stamp
    $result = $null
    $errorMessage = $null
    $exitCode = 0

    try {
        $initialStatus = [pscustomobject]@{
            state = 'RUNNING'
            display_state = 'laeuft'
            run_id = $runId
            started_at = ConvertTo-JobAgentOperationIso -Value $StartedAt
            finished_at = $null
            pid = $PID
            run_log_path = $runLogPath
            result_status = $null
            report_path = Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'report_path'
            markdown_report_path = Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'markdown_report_path'
            html_report_path = Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'html_report_path'
            published_at = Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'published_at'
            wake_at = Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'wake_at'
            is_stale = $null -ne $previousStatus
            reason = if ($null -ne $previousStatus) { 'Neuberechnung laeuft; letzter publizierter Stand bleibt sichtbar.' } else { 'Neuberechnung laeuft.' }
            exit_code = $null
            error = $null
        }
        Write-JobAgentDailyRunStatus -Paths $paths -Status $initialStatus | Out-Null
        Write-JobAgentOperationAtomicFile -Path $runLogPath -Content ("started_at=" + $initialStatus.started_at)

        try {
            $result = & $ScriptBlock $runId
            if ($null -ne $result -and [string]$result.status -eq 'FAILED') {
                $exitCode = 1
            }
        }
        catch {
            $exitCode = 1
            $errorMessage = $_.Exception.Message
        }

        $finishedAt = [datetime]::UtcNow
        $finalState = if ($exitCode -eq 0) { 'SUCCEEDED' } else { 'FAILED' }
        $finalStatus = [pscustomobject]@{
            state = $finalState
            display_state = Get-JobAgentDailyRunDisplayState -State $finalState -Result $result
            run_id = $runId
            started_at = ConvertTo-JobAgentOperationIso -Value $StartedAt
            finished_at = ConvertTo-JobAgentOperationIso -Value $finishedAt
            pid = $PID
            run_log_path = $runLogPath
            result_status = [string](Get-JobAgentOperationProperty -InputObject $result -Name 'status')
            scan_run_id = [string](Get-JobAgentOperationProperty -InputObject $result -Name 'scan_run_id')
            report_path = if ($exitCode -eq 0) { [string](Get-JobAgentOperationProperty -InputObject $result -Name 'report_path') } else { Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'report_path' }
            markdown_report_path = if ($exitCode -eq 0) { [string](Get-JobAgentOperationProperty -InputObject $result -Name 'markdown_report_path') } else { Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'markdown_report_path' }
            html_report_path = if ($exitCode -eq 0) { [string](Get-JobAgentOperationProperty -InputObject $result -Name 'html_report_path') } else { Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'html_report_path' }
            published_at = if ($exitCode -eq 0) { ConvertTo-JobAgentOperationIso -Value $finishedAt } else { Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'published_at' }
            wake_at = if ($exitCode -eq 0) { Get-JobAgentDailyRunWakeAt -Result $result } else { Get-JobAgentOperationProperty -InputObject $previousStatus -Name 'wake_at' }
            is_stale = $exitCode -ne 0
            exit_code = $exitCode
            reason = if ($exitCode -ne 0) { 'Neuberechnung fehlgeschlagen; letzter publizierter Stand ist veraltet.' } else { Get-JobAgentDailyRunReason -Result $result }
            error = $errorMessage
        }
        Write-JobAgentDailyRunStatus -Paths $paths -Status $finalStatus | Out-Null
        Add-Content -LiteralPath $runLogPath -Encoding UTF8 -Value ('finished_at=' + $finalStatus.finished_at)
        Add-Content -LiteralPath $runLogPath -Encoding UTF8 -Value ('state=' + $finalStatus.state)
        if ($errorMessage) {
            Add-Content -LiteralPath $runLogPath -Encoding UTF8 -Value ('error=' + $errorMessage)
        }
        Invoke-JobAgentLogRotation -LogRoot ([string]$paths.log_root) -RetainLogs $RetainLogs | Out-Null

        [pscustomobject]@{
            status = $finalStatus.state
            exit_code = $exitCode
            run_log_path = $runLogPath
            status_path = [string]$paths.status_path
            result = $result
            error = $errorMessage
        }
    }
    finally {
        Exit-JobAgentDailyRunLock -Lock $lock
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentDailyRunOperationalStatus',
    'Invoke-JobAgentLogRotation',
    'Invoke-JobAgentManagedDailyRun'
)
