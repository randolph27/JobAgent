function NowIso() { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK") }
function TsId()   { (Get-Date).ToString("yyyyMMdd-HHmmss") }

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Atomic-WriteTextUtf8([string]$path, [string]$content) {
  Ensure-Dir (Split-Path -Parent $path)
  $dir = Split-Path -Parent $path
  $name = Split-Path -Leaf $path
  $tmp = Join-Path $dir ($name + "." + ([guid]::NewGuid().ToString("N")) + ".tmp")
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  try {
    [System.IO.File]::WriteAllText($tmp, $content, $utf8)
    if (Test-Path -LiteralPath $path) {
      try {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.IsReadOnly) { $item.IsReadOnly = $false }
      } catch { $null = $_ }
      try {
        [System.IO.File]::Replace($tmp, $path, $null, $true)
      } catch {
        if (Test-Path -LiteralPath $path) {
          Remove-Item -Force -LiteralPath $path -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $tmp) {
          [System.IO.File]::Move($tmp, $path)
        }
      }
    } else {
      [System.IO.File]::Move($tmp, $path)
    }
  } finally {
    if (Test-Path -LiteralPath $tmp) {
      Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

function To-RelPath([string]$absPath) {
  if (-not $absPath) { return $absPath }
  try {
    $root = [string]$RepoRoot
    $p = [string](Resolve-Path -LiteralPath $absPath -ErrorAction Stop)
    if ($p.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
      $rel = $p.Substring($root.Length)
      return $rel.TrimStart("\","/")
    }
  } catch { $null = $_ }
  return $absPath
}

function Sha256Path([string]$path) {
  $stream = [System.IO.File]::OpenRead($path)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($stream)
    return (-join ($hash | ForEach-Object { $_.ToString("x2") }))
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function To-Json([object]$obj) { $obj | ConvertTo-Json -Depth 80 -Compress }

function Try-ReadJson([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
  catch {
    Ensure-Dir (Join-Path $LogsRoot "corrupt")
    $bak = Join-Path $LogsRoot ("corrupt\" + (Split-Path $path -Leaf) + "-" + (TsId) + ".copy")
    try { Copy-Item -Force -LiteralPath $path -Destination $bak } catch { $null = $_ }
    return $null
  }
}

function Write-Json([string]$path, [object]$obj) { Atomic-WriteTextUtf8 $path (To-Json $obj) }

function Get-ConfigPath() { Join-Path $CiRoot "ci.config.json" }

function Get-AgentId() {
  $p = Join-Path $CiRoot "run\agent.id"
  if (Test-Path -LiteralPath $p) { return (Get-Content -LiteralPath $p -Raw).Trim() }
  Ensure-Dir (Split-Path -Parent $p)
  $machine = $env:COMPUTERNAME
  $date = (Get-Date).ToString("yyyyMMdd")
  $seed = "$machine|$date|$PID|$([Environment]::TickCount)"
  $hex = (Sha256Text $seed).Substring(0,4)
  $id = "$machine-$date-$hex"
  Atomic-WriteTextUtf8 $p $id
  return $id
}

function Get-Prop([object]$obj, [string]$name, $default=$null) {
  if ($null -eq $obj) { return $default }
  try {
    if ($obj -is [System.Collections.IDictionary]) {
      try { if ($obj.ContainsKey($name)) { return $obj[$name] } } catch { $null = $_ }
      try { if ($obj.Contains($name))   { return $obj[$name] } } catch { $null = $_ }
    }
  } catch { $null = $_ }
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p) { return $default }
  return $p.Value
}

function CI-Info([string]$msg)    { Write-Host ("[CI] " + $msg) }
function CI-Warn([string]$msg)    { Write-Host ("[CI] WARN: " + $msg) -ForegroundColor Yellow }
function CI-Verbose([string]$msg) { if (Get-Variable -Name CiVerbose -ErrorAction SilentlyContinue) { if ($CiVerbose) { Write-Host ("[CI] " + $msg) } } }

$script:CiCommands = @{}

function Register-CiCommand([string]$name, [scriptblock]$action) {
  $script:CiCommands[$name.ToLowerInvariant()] = $action
}

function Tail-File([string]$path, [int]$maxLines=60) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  try { return (Get-Content -LiteralPath $path -Tail $maxLines) } catch { return @() }
}

function Set-ObjProp([object]$o, [string]$name, $value) {
  if ($null -eq $o) { return }
  if ($o -is [hashtable]) { $o[$name] = $value; return }
  $o | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

function HGet([hashtable]$h, [string]$k, $default=$null) {
  if ($null -eq $h) { return $default }
  try { if ($h.ContainsKey($k)) { return $h[$k] } } catch { $null = $_ }
  return $default
}

function Sha256Text([string]$text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($text)
  $h = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return (-join ($h | ForEach-Object { $_.ToString("x2") }))
}

function Quote-IfNeeded([string]$s) {
  if (-not $s) { return $s }
  if ($s.StartsWith('"') -and $s.EndsWith('"')) { return $s }
  if ($s -match '\s') { return '"' + $s + '"' }
  return $s
}

function Ensure-NonInteractiveEnv() {
  $defaults = @{
    "CI"="true"
    "GIT_TERMINAL_PROMPT"="0"
    "GIT_ASKPASS"="echo"
    "PAGER"="cat"
    "TERM"="dumb"
    "NO_COLOR"="1"
    "NPM_CONFIG_FUND"="false"
    "NPM_CONFIG_AUDIT"="false"
    "NPM_CONFIG_UPDATE_NOTIFIER"="false"
  }
  foreach ($k in $defaults.Keys) {
    try {
      $cur = [string][Environment]::GetEnvironmentVariable($k, "Process")
      if (-not $cur) { [Environment]::SetEnvironmentVariable($k, [string]$defaults[$k], "Process") }
    } catch { $null = $_ }
  }
  try {
    $cur = [string][Environment]::GetEnvironmentVariable("GRADLE_OPTS", "Process")
    $need = "-Dorg.gradle.daemon=false -Dorg.gradle.console=plain"
    if (-not $cur) { [Environment]::SetEnvironmentVariable("GRADLE_OPTS", $need, "Process") }
    elseif ($cur -notmatch "org\.gradle\.daemon") { [Environment]::SetEnvironmentVariable("GRADLE_OPTS", (($cur + " " + $need).Trim()), "Process") }
  } catch { $null = $_ }
}

function Run-Cmd([string]$cmd, [string]$logPath, [hashtable]$envMap=$null, [string]$cwd=$RepoRoot) {
  Ensure-Dir (Split-Path -Parent $logPath)
  $runStartedAt = Get-Date
  $script:LastCmdLogPath = $logPath
  $script:LastExecCmd = [string]$cmd
  if (-not $script:LastExecRunner) { $script:LastExecRunner = "pending" }
  $header = "## $(TsId)`r`nCMD: $cmd`r`nPWD: $($cwd)`r`nRUNNER: $($script:LastExecRunner)`r`n"
  Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  CI-Info ("BEGIN: " + $cmd)
  $script:LastExecRunner = ""
  $timeoutSec = 900
  $promptKillSec = 60
  $noOutSec = 180
  $hbSec = 15
  try {
    $cfg = Try-ReadJson (Join-Path $CiRoot "ci.config.json")
    $t = Get-Prop $cfg "terminal" $null
    if ($t) {
      $timeoutSec = [int](Get-Prop $t "default_timeout_seconds" $timeoutSec)
      $promptKillSec = [int](Get-Prop $t "prompt_kill_timeout_seconds" $promptKillSec)
      $noOutSec = [int](Get-Prop $t "no_output_timeout_seconds" $noOutSec)
      $hbSec = [int](Get-Prop $t "heartbeat_seconds" $hbSec)
    }
  } catch { $null = $_ }
  try {
    $timeoutOverride = [string][Environment]::GetEnvironmentVariable("CI_RUN_CMD_TIMEOUT_SECONDS", "Process")
    if (-not [string]::IsNullOrWhiteSpace($timeoutOverride)) {
      $timeoutSec = [int]$timeoutOverride
    }
  } catch { $null = $_ }
  if ($timeoutSec -lt 5) { $timeoutSec = 5 }
  if ($promptKillSec -lt 1) { $promptKillSec = 1 }
  $cmdTrim = ""; try { $cmdTrim = ([string]$cmd).Trim() } catch { $cmdTrim = "" }
  $force = ""
  if ($cmdTrim -match '^(?i)ps:\s*') { $force = "powershell"; $cmd = $cmdTrim.Substring(3).Trim(); $cmdTrim = $cmd }
  elseif ($cmdTrim -match '^(?i)cmd:\s*') { $force = "cmd"; $cmd = $cmdTrim.Substring(4).Trim(); $cmdTrim = $cmd }
  $psLike = $false
  if ($cmdTrim -match '^(?i)if\s*\(') { $psLike = $true }
  elseif ($cmdTrim -match '^(?i)if\b' -and $cmdTrim -match '(\{|\$|\-not\b|Test-Path\b|\()') { $psLike = $true }
  elseif ($cmdTrim -match '^(?i)(foreach|for|while|try|switch)\b') { $psLike = $true }
  elseif ($cmdTrim -match '^\s*\$') { $psLike = $true }
  elseif ($cmd -match "`r" -or $cmd -match "`n") { $psLike = $true }
  elseif ($cmdTrim -match '(?i)\b(Test-Path|Get-Item|Get-FileHash|Set-Content|ConvertTo-Json|Select-String)\b') { $psLike = $true }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  if ($force -eq "powershell") { $psLike = $true }
  elseif ($force -eq "cmd") { $psLike = $false }
  if ($psLike) {
    $psExe = "powershell.exe"
    try { if (Get-Command pwsh -ErrorAction SilentlyContinue) { $psExe = "pwsh.exe" } } catch { $null = $_ }
    $psi.FileName = $psExe
    $bytes = [Text.Encoding]::Unicode.GetBytes([string]$cmd)
    $enc = [Convert]::ToBase64String($bytes)
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $enc"
    $script:LastExecRunner = "powershell"
  } else {
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/d /c $cmd"
    $script:LastExecRunner = "cmd"
  }
  $psi.WorkingDirectory = $cwd
  try { Add-Content -LiteralPath $logPath -Value ("RUNNER: " + $script:LastExecRunner + "`r`n") -Encoding UTF8 } catch { $null = $_ }
  $defaults = @{
    "CI"="true"
    "GIT_TERMINAL_PROMPT"="0"
    "GIT_ASKPASS"="echo"
    "PAGER"="cat"
    "TERM"="dumb"
    "NO_COLOR"="1"
    "NPM_CONFIG_FUND"="false"
    "NPM_CONFIG_AUDIT"="false"
    "NPM_CONFIG_UPDATE_NOTIFIER"="false"
    "GRADLE_OPTS"="-Dorg.gradle.daemon=false -Dorg.gradle.console=plain"
  }
  foreach ($k in $defaults.Keys) { try { $psi.EnvironmentVariables[$k] = [string]$defaults[$k] } catch { $null = $_ } }
  # Explicitly set GIT_LFS_PATH for the process
  $psi.EnvironmentVariables["GIT_LFS_PATH"] = "C:\Program Files\Git LFS"
  if ($envMap) { foreach ($k in $envMap.Keys) { try { $psi.EnvironmentVariables[$k] = [string]$envMap[$k] } catch { $null = $_ } } }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.RedirectStandardInput  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $outSb = New-Object System.Text.StringBuilder
  $errSb = New-Object System.Text.StringBuilder
  $shared = [hashtable]::Synchronized(@{ lastOutput = Get-Date; promptDetected = $false; promptLine = $null })
  $promptPatterns = @("enter passphrase", "password for", "username for", "are you sure you want to continue connecting", "press any key", "hit enter to continue", "\[y/n\]", "\[y\/n\]", "\[y\/n\/\?\]", "\[y\/n\/\w+\]", "\[y\/N\]", "\[Y\/n\]")
  $sw = New-Object System.IO.StreamWriter($logPath, $true, [Text.Encoding]::UTF8)
  $sw.AutoFlush = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $evtData = @{ shared=$shared; sw=$sw; outSb=$outSb; errSb=$errSb; promptPatterns=$promptPatterns }
  $outEvent = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -Action {
    $d = $Event.MessageData; $e = $EventArgs
    if ($null -ne $e.Data) {
      $line = [string]$e.Data; $d.shared.lastOutput = Get-Date; $d.sw.WriteLine($line); $d.outSb.AppendLine($line) | Out-Null
      if (-not $d.shared.promptDetected) { $lc = $line.ToLowerInvariant(); foreach ($pat in $d.promptPatterns) { if ($lc -match $pat) { $d.shared.promptDetected = $true; $d.shared.promptLine = $line; break } } }
    }
  } -MessageData $evtData
  $errEvent = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action {
    $d = $Event.MessageData; $e = $EventArgs
    if ($null -ne $e.Data) {
      $line = [string]$e.Data; $d.shared.lastOutput = Get-Date; $d.sw.WriteLine($line); $d.errSb.AppendLine($line) | Out-Null
      if (-not $d.shared.promptDetected) { $lc = $line.ToLowerInvariant(); foreach ($pat in $d.promptPatterns) { if ($lc -match $pat) { $d.shared.promptDetected = $true; $d.shared.promptLine = $line; break } } }
    }
  } -MessageData $evtData
  $null = $p.Start()
  try { $p.StandardInput.Close() } catch { $null = $_ }
  $p.BeginOutputReadLine(); $p.BeginErrorReadLine()
  $timedOut = $false; $killedForPrompt = $false; $start = Get-Date; $nextHb = $hbSec
  while ($true) {
    if ($shared.promptDetected) { $killedForPrompt = $true; $sw.WriteLine("## PROMPT DETECTED (killing in CI): " + $shared.promptLine); try { cmd.exe /d /c ("taskkill /PID " + $p.Id + " /T /F >nul 2>&1") } catch { $null = $_ }; break }
    if ($p.HasExited) { break }
    $age = ((Get-Date) - $start).TotalSeconds; $idle = ((Get-Date) - $shared.lastOutput).TotalSeconds
    if ($hbSec -gt 0 -and $age -ge $nextHb) { try { $sw.WriteLine("## HEARTBEAT: age=" + [int]$age + "s idle=" + [int]$idle + "s") } catch { $null = $_ }; CI-Verbose ("still running: age=" + [int]$age + "s idle=" + [int]$idle + "s"); $nextHb = $nextHb + $hbSec }
    if ($noOutSec -gt 0 -and $idle -ge $noOutSec) { $timedOut = $true; $sw.WriteLine("## NO-OUTPUT TIMEOUT (killing in CI): " + $noOutSec + "s"); try { cmd.exe /d /c ("taskkill /PID " + $p.Id + " /T /F >nul 2>&1") } catch { $null = $_ }; break }
    if ($age -ge $timeoutSec) { $timedOut = $true; $sw.WriteLine("## TIMEOUT (killing in CI): " + $timeoutSec + "s"); try { cmd.exe /d /c ("taskkill /PID " + $p.Id + " /T /F >nul 2>&1") } catch { $null = $_ }; break }
    Start-Sleep -Milliseconds 200
  }
  try { $p.WaitForExit(2000) | Out-Null } catch { $null = $_ }
  try { $p.CancelOutputRead() } catch { $null = $_ }
  try { $p.CancelErrorRead() } catch { $null = $_ }
  try { Unregister-Event -SourceIdentifier $outEvent.Name -ErrorAction SilentlyContinue } catch { $null = $_ }
  try { Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue } catch { $null = $_ }
  try { $sw.Flush(); $sw.Close() } catch { $null = $_ }
  $exit = 0; try { $exit = [int]$p.ExitCode } catch { $exit = 1 }
  if ($timedOut -or $killedForPrompt) { $exit = 1 }
  $durationSeconds = [Math]::Round(((Get-Date) - $runStartedAt).TotalSeconds, 2)
  $durationLabel = [string]::Format([Globalization.CultureInfo]::InvariantCulture, "{0:0.##}", $durationSeconds)
  if ($exit -eq 0) {
    CI-Info ("OK: " + $cmd + " (" + $durationLabel + "s) | log: " + $logPath)
  } else {
    CI-Info ("FAIL: " + $cmd + " (" + $durationLabel + "s) | log: " + $logPath)
    $failureReason = if ($killedForPrompt) {
      "interactive prompt detected"
    } elseif ($timedOut) {
      "timeout"
    } else {
      "exit code " + $exit
    }
    Write-Error ("Run-Cmd failed: " + $cmd + " (" + $failureReason + ") log: " + $logPath)
  }
  return @{ exit=$exit; out=$outSb.ToString(); err=$errSb.ToString(); timed_out=$timedOut; prompt_detected=$killedForPrompt; duration_seconds=$durationSeconds }
}
