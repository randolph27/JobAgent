function Normalize-HandoffSummaryAnchor([string]$summary) {
  $value = [string]$summary
  if ([string]::IsNullOrWhiteSpace($value)) { return $value }

  $normalized = $value.Trim()
  if ($normalized -match '(?i)^es gibt keinen aktiven Folgepunkt\.?$') {
    return 'kein aktiver Folgepunkt'
  }

  return ($value -replace '(?i)\bkeinen aktiven Folgepunkt\b', 'kein aktiver Folgepunkt')
}

function Test-RoadmapHasOpenMainTask([string]$roadmapPath) {
  if ([string]::IsNullOrWhiteSpace($roadmapPath)) { return $false }
  if (-not (Test-Path -LiteralPath $roadmapPath)) { return $false }

  $content = Get-Content -Raw -LiteralPath $roadmapPath
  return [bool]([regex]::IsMatch($content, '(?m)^- \[ \] \S'))
}

function Test-TodoStateHasActiveWork([object]$state) {
  if (-not $state) { return $false }

  $activeId = [string](Get-Prop $state 'active_id' '')
  if (-not [string]::IsNullOrWhiteSpace($activeId)) { return $true }

  foreach ($item in @((Get-Prop $state 'items' @()))) {
    $status = ([string](Get-Prop $item 'status' 'open')).Trim().ToLowerInvariant()
    if ($status -in @('open', 'in-progress', 'blocked')) {
      return $true
    }
  }

  return $false
}

function Test-HandoffNoActiveFollowup([object]$state, [string]$roadmapPath) {
  if (Test-TodoStateHasActiveWork $state) { return $false }
  if (Test-RoadmapHasOpenMainTask $roadmapPath) { return $false }
  return $true
}

function Get-HandoffActiveBlockedTodo([object]$state) {
  if (-not $state) { return $null }

  $activeId = ([string](Get-Prop $state 'active_id' '')).Trim()
  if (-not $activeId) { return $null }

  foreach ($item in @((Get-Prop $state 'items' @()))) {
    $todoId = ([string](Get-Prop $item 'todo_id' (Get-Prop $item 'id' ''))).Trim()
    $status = ([string](Get-Prop $item 'status' 'open')).Trim().ToLowerInvariant()
    if ($todoId -eq $activeId -and $status -eq 'blocked') {
      return $item
    }
  }

  return $null
}

function Get-Ci050UiReleaseGateDoneStatus() {
  $reportPath = Join-Path $RepoRoot 'logs\data\CI-050-ui-release-gate.json'
  if (-not (Test-Path -LiteralPath $reportPath)) {
    return @{ allowed = $false; status = 'missing'; reason = 'ci050_report_missing' }
  }

  $report = Try-ReadJson $reportPath
  if (-not $report) {
    return @{ allowed = $false; status = 'fail'; reason = 'ci050_report_invalid_json' }
  }

  $status = ([string](Get-Prop $report 'status' '')).Trim().ToLowerInvariant()
  $doneAllowed = [bool](Get-Prop $report 'done_handoff_allowed' $false)
  $externalWriteStarted = [bool](Get-Prop $report 'external_write_started' $false)
  $currentGitSha = ([string](Get-Prop $report 'current_git_sha' '')).Trim().ToLowerInvariant()
  $git = $null
  try { $git = Get-GitStatusSnapshot } catch { $git = $null }
  $head = ([string](Get-Prop $git 'head' '')).Trim().ToLowerInvariant()
  if ($status -ne 'pass') {
    return @{ allowed = $false; status = $status; reason = 'ci050_report_not_pass' }
  }
  if (-not $doneAllowed) {
    return @{ allowed = $false; status = 'fail'; reason = 'ci050_done_handoff_not_allowed' }
  }
  if ($externalWriteStarted) {
    return @{ allowed = $false; status = 'fail'; reason = 'ci050_external_write_started' }
  }
  if (-not $currentGitSha -or -not $head -or $currentGitSha -ne $head) {
    return @{ allowed = $false; status = 'stale'; reason = 'ci050_report_head_mismatch' }
  }
  return @{ allowed = $true; status = 'pass'; reason = 'ci050_report_pass' }
}

function Resolve-HandoffSonarCheckpointStatus([object]$state, [string]$roadmapPath, [bool]$blocking) {
  if ($blocking) { return 'blocked' }
  if (Get-HandoffActiveBlockedTodo $state) { return 'blocked' }
  if (Test-HandoffNoActiveFollowup $state $roadmapPath) {
    $ci050 = Get-Ci050UiReleaseGateDoneStatus
    if ([bool](Get-Prop $ci050 'allowed' $false)) { return 'done' }
    return 'blocked'
  }
  return 'open'
}

function Resolve-HandoffSonarCheckpointSummary([string]$sonarSummary, [string]$status) {
  if ($status -eq 'done') { return 'kein aktiver Folgepunkt' }
  return (Normalize-HandoffSummaryAnchor $sonarSummary)
}
