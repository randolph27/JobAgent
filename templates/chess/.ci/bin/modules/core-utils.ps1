function NowIso() { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK") }
function TsId()   { (Get-Date).ToString("yyyyMMdd-HHmmss") }

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Atomic-WriteTextUtf8([string]$path, [string]$content) {
  Ensure-Dir (Split-Path -Parent $path)
  $tmp = "$path.tmp"
  Set-Content -LiteralPath $tmp -Value $content -Encoding UTF8
  $lastErr = $null
  if (Test-Path -LiteralPath $path) {
    try {
      Remove-Item -Force -LiteralPath $path -ErrorAction Stop
    } catch {
      $lastErr = $_
    }
  }

  try {
    Move-Item -Force -LiteralPath $tmp -Destination $path -ErrorAction Stop
    return
  } catch {
    $lastErr = $_
  }

  try {
    Copy-Item -Force -LiteralPath $tmp -Destination $path -ErrorAction Stop
    Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    return
  } catch {
    $lastErr = $_
  }

  try {
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8 -ErrorAction Stop
    Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    return
  } catch {
    $lastErr = $_
  }

  if ($lastErr) { throw $lastErr }
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
  return ([string](Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash).ToLowerInvariant()
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
  $ms = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($seed))
  $hex = (Get-FileHash -InputStream $ms -Algorithm SHA256).Hash.Substring(0,4).ToLowerInvariant()
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
  if ($s -match '[\s&|<>^()]') { return '"' + $s + '"' }
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

function Get-GitDefaultPrefix() {
  $safe = [string]$RepoRoot
  if ($safe) { $safe = $safe -replace "\\","/" }
  $safeArg = ""
  if ($safe) { $safeArg = (" -c safe.directory=" + (Quote-IfNeeded $safe)) }
  return ("git -c core.pager=cat -c color.ui=false --no-pager" + $safeArg)
}

function Get-GitNoLfsPrefix() {
  $safe = [string]$RepoRoot
  if ($safe) { $safe = $safe -replace "\\","/" }
  $safeArg = ""
  if ($safe) { $safeArg = (" -c safe.directory=" + (Quote-IfNeeded $safe)) }
  return ("git -c core.pager=cat -c color.ui=false --no-pager" + $safeArg + " -c filter.lfs.required=false -c filter.lfs.clean= -c filter.lfs.smudge= -c filter.lfs.process=")
}

function Normalize-GitArgs([string]$gitArgs) {
  $args = [string]$gitArgs
  if (-not $args) { return "" }
  $args = $args.Trim()
  if ($args -match '^(?i)git\s+') { $args = $args.Substring(4).Trim() }
  return $args
}

function Test-GitLfsSignalPipeFailure([object]$result, [string]$logPath=$null) {
  $blob = ""
  try {
    $blob = [string](Get-Prop $result "out" "") + "`n" + [string](Get-Prop $result "err" "")
  } catch {
    $blob = ""
  }
  if ($logPath -and (Test-Path -LiteralPath $logPath)) {
    try {
      $blob += "`n" + ((Tail-File $logPath 80) -join "`n")
    } catch { $null = $_ }
  }
  if (-not $blob) { return $false }
  if ($blob -match "(?i)couldn't create signal pipe,\s*Win32 error 5") { return $true }
  if ($blob -match "(?i)CreateFileMapping\s+S-\d-\d+-(\d+-){1,}\d+\.\d+,\s*Win32 error 5") { return $true }
  if ($blob -match "(?i)run_command:\s*'git-lfs filter-process'") { return $true }
  if ($blob -match "(?i)\bgit-lfs filter-process\b") { return $true }
  return $false
}

function Test-GitIndexLockPermissionFailure([object]$result, [string]$logPath=$null) {
  $blob = ""
  try {
    $blob = [string](Get-Prop $result "out" "") + "`n" + [string](Get-Prop $result "err" "")
  } catch {
    $blob = ""
  }
  if ($logPath -and (Test-Path -LiteralPath $logPath)) {
    try {
      $blob += "`n" + ((Tail-File $logPath 80) -join "`n")
    } catch { $null = $_ }
  }
  if (-not $blob) { return $false }
  if ($blob -notmatch "(?i)index\.lock") { return $false }
  if ($blob -match "(?i)Permission denied|Access is denied|Zugriff verweigert") { return $true }
  return $false
}

function Test-GitAddDryRunArgs([string]$gitArgs) {
  $args = Normalize-GitArgs $gitArgs
  if (-not $args) { return $false }
  if ($args -notmatch '^(?i)add(\s|$)') { return $false }
  if ($args -notmatch '(?i)(^|\s)--dry-run(\s|$)') { return $false }
  return $true
}

function Get-GitFailureClassification(
  [string]$cmdName,
  [string]$errMsg,
  [string]$logPath=$null,
  [string]$execCmd=$null
) {
  $msg = [string]$errMsg
  $cmd = [string]$cmdName
  $log = [string]$logPath
  $exec = [string]$execCmd

  $result = @{
    is_git_failure = $false
    type = $null
    cmd = $cmd
    exec_cmd = $exec
    log_path = $log
    lfs_signal_pipe = $false
    index_lock_permission_denied = $false
    acl_report_path = $null
    acl_deny_detected = $false
    deny_sids = @()
    deny_accounts = @()
    deny_sid_matches_current_token = @()
    acl_requires_elevation = $false
    acl_elevation_hint = ""
    acl_remediation_commands = @()
    acl_remediation_summary = @()
    suggested_next_steps = @()
  }

  $isGit = $false
  if ($cmd -match '^(?i)git$') { $isGit = $true }
  elseif ($msg -match '(?i)\bgit command failed\b') { $isGit = $true }
  elseif ($exec -match '(?i)\bgit\s+-c\s+core\.pager=cat\b') { $isGit = $true }
  if (-not $isGit) { return $result }

  $result["is_git_failure"] = $true
  $probe = @{ out = ""; err = $msg }
  $isSignalPipe = Test-GitLfsSignalPipeFailure $probe $log
  $isIndexLockDenied = Test-GitIndexLockPermissionFailure $probe $log

  $result["lfs_signal_pipe"] = $isSignalPipe
  $result["index_lock_permission_denied"] = $isIndexLockDenied

  if ($isSignalPipe) {
    $result["type"] = "git_lfs_signal_pipe"
    $result["suggested_next_steps"] = @(
      'retry command via ".ci\\bin\\ci.cmd git <args>" (wrapper/no-lfs fallback)',
      "inspect git/lfs first-fail log for signal-pipe signature"
    )
    return $result
  }

  if ($isIndexLockDenied) {
    $result["type"] = "git_index_lock_permission"
    $aclReport = $null
    if ($log -and (Test-Path -LiteralPath $log)) {
      $candidate = ($log + ".indexlock-acl.json")
      if (Test-Path -LiteralPath $candidate) { $aclReport = $candidate }
    }
    if ($aclReport) {
      $result["acl_report_path"] = $aclReport
      $diag = Try-ReadJson $aclReport
      if ($diag) {
        $result["acl_deny_detected"] = [bool](Get-Prop $diag "acl_deny_detected" $false)
        $result["deny_sids"] = @((Get-Prop $diag "deny_sids" @()))
        $result["deny_accounts"] = @((Get-Prop $diag "deny_accounts" @()))
        $result["deny_sid_matches_current_token"] = @((Get-Prop $diag "deny_sid_matches_current_token" @()))
        $remediation = Get-Prop $diag "remediation" $null
        if ($remediation) {
          $result["acl_requires_elevation"] = [bool](Get-Prop $remediation "requires_elevation_when_access_denied" $false)
          $result["acl_elevation_hint"] = [string](Get-Prop $remediation "elevation_command_hint" "")
          $result["acl_remediation_commands"] = @((Get-Prop $remediation "suggested_commands" @()))
          $result["acl_remediation_summary"] = @((Get-Prop $remediation "summary" @()))
        }
      }
    }
    if ([bool](Get-Prop $result "acl_deny_detected" $false)) {
      $result["type"] = "git_index_lock_acl_deny"
    }

    $steps = New-Object System.Collections.Generic.List[string]
    $steps.Add('run ".ci\\bin\\ci.cmd git add -A --dry-run" to validate wrapper fallback path')
    if ([bool](Get-Prop $result "acl_deny_detected" $false)) {
      $cmds = @((Get-Prop $result "acl_remediation_commands" @()))
      if ($cmds.Count -gt 0) { $steps.Add([string]$cmds[0]) }
      if ([bool](Get-Prop $result "acl_requires_elevation" $false)) {
        $hint = [string](Get-Prop $result "acl_elevation_hint" "")
        if ($hint) { $steps.Add("if access denied persists, rerun remediation in elevated shell: " + $hint) }
      }
    }
    $result["suggested_next_steps"] = @($steps)
    return $result
  }

  $result["type"] = "git_command_failure"
  $result["suggested_next_steps"] = @(
    "inspect git command log for exact failure signature",
    "retry via .ci wrapper to capture deterministic diagnostics"
  )
  return $result
}

function Get-GitIndexLockAclDiagnosis([string]$cwd=$RepoRoot) {
  $root = [string]$cwd
  if (-not $root) { $root = [string]$RepoRoot }
  $gitDir = Join-Path $root ".git"
  $indexPath = Join-Path $gitDir "index"
  $diag = @{
    ts = (NowIso)
    git_dir = $gitDir
    index_path = $indexPath
    acl_deny_detected = $false
    acl_deny_entries = @()
    icacls_git = @()
    icacls_index = @()
    current_identity = $null
    current_sid = $null
    token_sids = @()
    deny_sid_entries = @()
    deny_sids = @()
    deny_accounts = @()
    deny_sid_matches_current_token = @()
    remediation = @{
      summary = @()
      suggested_commands = @()
      requires_elevation_when_access_denied = $true
      elevation_command_hint = 'Start-Process pwsh -Verb RunAs'
      verify_commands = @(
        'cmd /d /c ".ci\\bin\\ci.cmd git add -A --dry-run"',
        'cmd /d /c ".ci\\bin\\ci.cmd git add -A"'
      )
    }
    error = $null
  }

  try {
    $tokenSidMap = @{}
    try {
      $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
      if ($identity) {
        $diag["current_identity"] = [string]$identity.Name
        $sid = $null
        try {
          if ($identity.User) { $sid = [string]$identity.User.Value }
        } catch { $sid = $null }
        if ($sid) {
          $diag["current_sid"] = $sid
          $tokenSidMap[$sid] = $true
        }

        $tokenSids = @()
        if ($sid) { $tokenSids += $sid }
        try {
          foreach ($g in @($identity.Groups)) {
            if ($null -eq $g) { continue }
            $gSid = $null
            try { $gSid = [string]$g.Value } catch { $gSid = $null }
            if ($gSid) {
              $tokenSids += $gSid
              $tokenSidMap[$gSid] = $true
            }
          }
        } catch { $null = $_ }
        $diag["token_sids"] = @($tokenSids | Sort-Object -Unique)
      }
    } catch { $null = $_ }

    $gitAcl = @()
    $indexAcl = @()
    if (Test-Path -LiteralPath $gitDir) {
      $gitCmd = ("icacls " + (Quote-IfNeeded $gitDir))
      $gitAcl = @(& cmd /d /c $gitCmd 2>&1 | ForEach-Object { [string]$_ })
    }
    if (Test-Path -LiteralPath $indexPath) {
      $indexCmd = ("icacls " + (Quote-IfNeeded $indexPath))
      $indexAcl = @(& cmd /d /c $indexCmd 2>&1 | ForEach-Object { [string]$_ })
    }

    $diag["icacls_git"] = @($gitAcl)
    $diag["icacls_index"] = @($indexAcl)

    $denyRows = @()
    foreach ($line in @($gitAcl + $indexAcl)) {
      $s = [string]$line
      if ($s -match "(?i)\(DENY\)") { $denyRows += $s }
    }
    if ($denyRows.Count -gt 0) {
      $diag["acl_deny_detected"] = $true
      $diag["acl_deny_entries"] = @($denyRows)

      $denySidMap = @{}
      $denyAccountMap = @{}
      $matchingSidMap = @{}
      $denySidEntries = @()

      foreach ($entry in $denyRows) {
        $raw = [string]$entry
        $sidValue = $null
        $accountValue = $null
        try {
          $m = [regex]::Match($raw, '(S-\d-\d+(?:-\d+)+)')
          if ($m.Success) { $sidValue = [string]$m.Groups[1].Value }
        } catch { $sidValue = $null }

        if ($sidValue) {
          $denySidMap[$sidValue] = $true
          if ($tokenSidMap.ContainsKey($sidValue)) { $matchingSidMap[$sidValue] = $true }
          try {
            $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sidValue)
            $accountValue = [string]($sidObj.Translate([System.Security.Principal.NTAccount]).Value)
          } catch { $accountValue = $null }
          if ($accountValue) { $denyAccountMap[$accountValue] = $true }
        }

        $denySidEntries += [pscustomobject]@{
          raw = $raw
          sid = $sidValue
          account = $accountValue
        }
      }

      $denySidList = @($denySidMap.Keys | Sort-Object)
      $matchingSidList = @($matchingSidMap.Keys | Sort-Object)
      $denyAccountList = @($denyAccountMap.Keys | Sort-Object)

      $diag["deny_sid_entries"] = @($denySidEntries)
      $diag["deny_sids"] = @($denySidList)
      $diag["deny_accounts"] = @($denyAccountList)
      $diag["deny_sid_matches_current_token"] = @($matchingSidList)

      $summary = @()
      if ($matchingSidList.Count -gt 0) {
        $summary += "DENY SID intersects current access token and blocks .git/index lock creation."
      } elseif ($denySidList.Count -gt 0) {
        $summary += "DENY SID does not directly match current token; inspect inherited ACL chain and owner context."
      }
      $summary += "If icacls /remove:d returns Access is denied, rerun remediation in an elevated Administrator shell."

      $commands = @()
      foreach ($denySid in $denySidList) {
        $commands += ('icacls "' + $gitDir + '" /remove:d "' + $denySid + '"')
        if (Test-Path -LiteralPath $indexPath) {
          $commands += ('icacls "' + $indexPath + '" /remove:d "' + $denySid + '"')
        }
      }
      if ($denySidList.Count -gt 0) {
        $commands += ('icacls "' + $gitDir + '"')
        if (Test-Path -LiteralPath $indexPath) {
          $commands += ('icacls "' + $indexPath + '"')
        }
      }

      $diag["remediation"] = @{
        summary = @($summary)
        suggested_commands = @($commands)
        requires_elevation_when_access_denied = $true
        elevation_command_hint = 'Start-Process pwsh -Verb RunAs'
        verify_commands = @(
          'cmd /d /c ".ci\\bin\\ci.cmd git add -A --dry-run"',
          'cmd /d /c ".ci\\bin\\ci.cmd git add -A"'
        )
      }
    }
  } catch {
    try { $diag["error"] = [string]$_.Exception.Message } catch { $diag["error"] = "acl diagnosis failed" }
  }

  return $diag
}
function Attach-GitIndexLockAclDiagnosis([object]$result, [string]$logPath, [string]$cwd=$RepoRoot) {
  $diag = Get-GitIndexLockAclDiagnosis $cwd
  $reportPath = $null
  try {
    if ($logPath) {
      $reportPath = ($logPath + ".indexlock-acl.json")
      Write-Json $reportPath $diag
    }
  } catch {
    $reportPath = $null
  }

  $remediation = Get-Prop $diag "remediation" $null
  $remediationCmds = @()
  if ($remediation) {
    try { $remediationCmds = @((Get-Prop $remediation "suggested_commands" @())) } catch { $remediationCmds = @() }
  }

  if ($result -is [hashtable]) {
    $result["index_lock_acl_deny_detected"] = [bool](Get-Prop $diag "acl_deny_detected" $false)
    $result["index_lock_acl_report_path"] = $reportPath
    $result["index_lock_acl_remediation_commands"] = @($remediationCmds)
    $result["index_lock_acl_requires_elevation"] = [bool](Get-Prop $remediation "requires_elevation_when_access_denied" $false)
    $result["index_lock_acl_elevation_hint"] = [string](Get-Prop $remediation "elevation_command_hint" "")
  }
  return $result
}
function Merge-EnvMap([hashtable]$baseMap=$null, [hashtable]$overrideMap=$null) {
  $merged = @{}
  if ($baseMap) {
    foreach ($k in $baseMap.Keys) { $merged[$k] = [string]$baseMap[$k] }
  }
  if ($overrideMap) {
    foreach ($k in $overrideMap.Keys) { $merged[$k] = [string]$overrideMap[$k] }
  }
  return $merged
}

function New-GitTempIndexFile([string]$cwd=$RepoRoot) {
  $root = [string]$cwd
  if (-not $root) { $root = [string]$RepoRoot }
  $tmpDir = Join-Path $env:TEMP "chess-git-index"
  try {
    Ensure-Dir $tmpDir
  } catch {
    $tmpDir = Join-Path $root ".tmp\git-index"
    Ensure-Dir $tmpDir
  }

  $suffix = ([Guid]::NewGuid().ToString("N")).Substring(0,8)
  $tmpPath = Join-Path $tmpDir ("index-" + (TsId) + "-" + $PID + "-" + $suffix + ".tmp")
  $repoIndex = Join-Path $root ".git\index"
  if (Test-Path -LiteralPath $repoIndex) {
    Copy-Item -Force -LiteralPath $repoIndex -Destination $tmpPath
  } else {
    "" | Out-File -LiteralPath $tmpPath -Encoding ASCII -NoNewline
  }
  return $tmpPath
}

function Run-GitCmd(
  [string]$gitArgs,
  [string]$logPath,
  [hashtable]$envMap=$null,
  [string]$cwd=$RepoRoot,
  [switch]$NoLfs,
  [switch]$NoFallback
) {
  $args = Normalize-GitArgs $gitArgs
  if (-not $args) { throw "Run-GitCmd requires git arguments." }

  $useNoLfsPrefix = [bool]$NoLfs
  $prefix = $(if ($useNoLfsPrefix) { Get-GitNoLfsPrefix } else { Get-GitDefaultPrefix })
  $cmd = ($prefix + " " + $args).Trim()
  $res = Run-Cmd $cmd $logPath $envMap $cwd
  if ($res -is [hashtable]) {
    $res["fallback_used"] = $false
    $res["index_lock_fallback_used"] = $false
    $res["index_lock_acl_deny_detected"] = $false
    $res["index_lock_acl_report_path"] = $null
    $res["index_lock_acl_remediation_commands"] = @()
    $res["index_lock_acl_requires_elevation"] = $false
    $res["index_lock_acl_elevation_hint"] = ""
  }

  if (-not $NoFallback -and -not $NoLfs -and $res.exit -ne 0 -and (Test-GitLfsSignalPipeFailure $res $logPath)) {
    $firstFailLog = $null
    try {
      if ($logPath -and (Test-Path -LiteralPath $logPath)) {
        $firstFailLog = ($logPath + ".lfsfail.log")
        Copy-Item -Force -LiteralPath $logPath -Destination $firstFailLog
      }
    } catch { $null = $_ }

    CI-Warn "git-lfs/sh signal-pipe failure detected; retrying once with LFS filters disabled."
    $fallbackCmd = ((Get-GitNoLfsPrefix) + " " + $args).Trim()
    $retry = Run-Cmd $fallbackCmd $logPath $envMap $cwd
    if ($retry -is [hashtable]) {
      $retry["fallback_used"] = $true
      $retry["first_fail_log_path"] = $firstFailLog
      $retry["index_lock_fallback_used"] = $false
      $retry["index_lock_acl_remediation_commands"] = @()
      $retry["index_lock_acl_requires_elevation"] = $false
      $retry["index_lock_acl_elevation_hint"] = ""
    }
    $res = $retry
    $useNoLfsPrefix = $true
  }

  $indexLockFailure = $false
  if ($res.exit -ne 0) {
    $indexLockFailure = Test-GitIndexLockPermissionFailure $res $logPath
  }
  if ($indexLockFailure) {
    $res = Attach-GitIndexLockAclDiagnosis $res $logPath $cwd
  }

  if (-not $NoFallback -and $res.exit -ne 0 -and (Test-GitAddDryRunArgs $args) -and $indexLockFailure) {
    $indexFailLog = $null
    try {
      if ($logPath -and (Test-Path -LiteralPath $logPath)) {
        $indexFailLog = ($logPath + ".indexlockfail.log")
        Copy-Item -Force -LiteralPath $logPath -Destination $indexFailLog
      }
    } catch { $null = $_ }

    $tmpIndex = $null
    try {
      $tmpIndex = New-GitTempIndexFile $cwd
      CI-Warn "git index.lock permission blocker detected; retrying once with temporary GIT_INDEX_FILE for dry-run."
      $retryEnv = Merge-EnvMap $envMap @{ "GIT_INDEX_FILE" = $tmpIndex; "GIT_OPTIONAL_LOCKS" = "0" }
      $retryPrefix = Get-GitNoLfsPrefix
      $retryCmd = ($retryPrefix + " " + $args).Trim()
      $retry = Run-Cmd $retryCmd $logPath $retryEnv $cwd
      if ($retry -is [hashtable]) {
        $retry["fallback_used"] = $true
        $retry["first_fail_log_path"] = (Get-Prop $res "first_fail_log_path" $null)
        $retry["index_lock_fallback_used"] = $true
        $retry["index_lock_fail_log_path"] = $indexFailLog
        $retry["temp_index_path"] = $tmpIndex
        $retry["index_lock_acl_deny_detected"] = [bool](Get-Prop $res "index_lock_acl_deny_detected" $false)
        $retry["index_lock_acl_report_path"] = (Get-Prop $res "index_lock_acl_report_path" $null)
        $retry["index_lock_acl_remediation_commands"] = @((Get-Prop $res "index_lock_acl_remediation_commands" @()))
        $retry["index_lock_acl_requires_elevation"] = [bool](Get-Prop $res "index_lock_acl_requires_elevation" $false)
        $retry["index_lock_acl_elevation_hint"] = [string](Get-Prop $res "index_lock_acl_elevation_hint" "")
      }
      $res = $retry
    } catch {
      $null = $_
    } finally {
      try {
        if ($tmpIndex -and (Test-Path -LiteralPath $tmpIndex)) {
          Remove-Item -Force -LiteralPath $tmpIndex -ErrorAction SilentlyContinue
        }
        $tmpIndexLock = $null
        if ($tmpIndex) { $tmpIndexLock = ($tmpIndex + ".lock") }
        if ($tmpIndexLock -and (Test-Path -LiteralPath $tmpIndexLock)) {
          Remove-Item -Force -LiteralPath $tmpIndexLock -ErrorAction SilentlyContinue
        }
      } catch { $null = $_ }
    }
  }
  return $res
}

function Run-Cmd([string]$cmd, [string]$logPath, [hashtable]$envMap=$null, [string]$cwd=$RepoRoot, [int]$timeoutSecOverride=0) {
  Ensure-Dir (Split-Path -Parent $logPath)
  $script:LastCmdLogPath = $logPath
  $script:LastExecCmd = [string]$cmd
  if (-not $script:LastExecRunner) { $script:LastExecRunner = "pending" }
  $header = "## $(TsId)
CMD: $cmd
PWD: $($cwd)
RUNNER: $($script:LastExecRunner)
"
  Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  CI-Info ("run: " + $cmd + " | log=" + $logPath)
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
  if ($timeoutSecOverride -gt 0) { $timeoutSec = $timeoutSecOverride }
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
  try { Add-Content -LiteralPath $logPath -Value ("RUNNER: " + $script:LastExecRunner + "
") -Encoding UTF8 } catch { $null = $_ }
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
  return @{ exit=$exit; out=$outSb.ToString(); err=$errSb.ToString(); timed_out=$timedOut; prompt_detected=$killedForPrompt }
}



