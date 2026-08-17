function Get-SonarListeningPid() {
  try {
    $listener = Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listener) { return [int]$listener.OwningProcess }
  } catch { $null = $_ }
  return $null
}

function Test-SonarStatusUp([string]$statusUrl) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $statusUrl -TimeoutSec 5
    return ([string]$resp.Content -match '"status":"UP"')
  } catch {
    return $false
  }
}

function Write-SonarPidSnapshot([string]$pidPath, [int]$processId, [string]$cmd, [string]$cwd) {
  @{ ts=(NowIso); pid=$processId; cmd=$cmd; cwd=$cwd; port=9000; url="http://127.0.0.1:9000/" } | ConvertTo-Json -Compress | Set-Content -LiteralPath $pidPath -NoNewline -Encoding UTF8
}

function Get-SonarCommandOutcomePath() {
  return (Join-Path $CiRoot "run\sonar.command.outcome.json")
}

function Clear-SonarCommandOutcome() {
  $path = Get-SonarCommandOutcomePath
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
}

function Read-SonarCommandOutcome() {
  $path = Get-SonarCommandOutcomePath
  if (-not (Test-Path -LiteralPath $path)) {
    return $null
  }

  try {
    return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 30)
  } catch {
    return $null
  }
}

function Read-SonarStartStatus() {
  $path = Join-Path $CiRoot "run\sonar-start.status.json"
  if (-not (Test-Path -LiteralPath $path)) {
    return $null
  }

  try {
    return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 30)
  } catch {
    return $null
  }
}

function Get-SonarReadbackReportPath() {
  return (Join-Path $RepoRoot "logs\review\sonar-readback-latest.json")
}

function Read-SonarReadbackReport() {
  return (Try-ReadJson (Get-SonarReadbackReportPath))
}

function Get-SonarScanContextPath() {
  return (Join-Path $CiRoot "run\sonar.scan.context.json")
}

function Read-SonarScanContext() {
  return (Try-ReadJson (Get-SonarScanContextPath))
}

function Get-SonarParityArtifactPaths() {
  return [pscustomobject]@{
    json_path = Join-Path $RepoRoot "logs\data\SONAR-043-sonar-ui-api-parity.json"
    markdown_path = Join-Path $RepoRoot "logs\review\SONAR-043-sonar-ui-api-parity.md"
  }
}

function ConvertTo-SonarParityNumber($Value) {
  if ($null -eq $Value) {
    return $null
  }

  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) {
    return $null
  }

  $normalized = $text.Replace(',', '.')
  $number = 0.0
  if ([double]::TryParse($normalized, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
    return [math]::Round($number, 3)
  }

  return $null
}

function ConvertTo-SonarParityDateString($Value) {
  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [datetime]) {
    return $Value.ToString('yyyy-MM-ddTHH:mm:sszzz')
  }

  return [string]$Value
}

function Get-SonarQualityGateConditionValue([object]$QualityGate, [string]$MetricKey) {
  foreach ($condition in @(Get-Prop $QualityGate "conditions" @())) {
    if ([string](Get-Prop $condition "metricKey" "") -eq $MetricKey) {
      return ConvertTo-SonarParityNumber (Get-Prop $condition "actualValue" $null)
    }
  }

  return $null
}

function Get-SonarReadbackQualityGate([object]$Readback) {
  return (Get-Prop $Readback "quality_gate" $null)
}

function Get-SonarReadbackNewCodePeriod([object]$Readback) {
  $newCode = Get-Prop $Readback "new_code" $null
  if ($newCode) {
    $period = Get-Prop $newCode "period" $null
    if ($period) {
      return $period
    }
  }

  $qualityGate = Get-SonarReadbackQualityGate $Readback
  return (Get-Prop $qualityGate "period" $null)
}

function Get-SonarReadbackMetricValue([object]$Readback, [string]$MetricKey) {
  $newCode = Get-Prop $Readback "new_code" $null
  $metrics = Get-Prop $newCode "metrics" $null
  $metricValue = Get-Prop $metrics $MetricKey $null
  if ($null -ne $metricValue) {
    return (ConvertTo-SonarParityNumber $metricValue)
  }

  $qualityGate = Get-SonarReadbackQualityGate $Readback
  return (Get-SonarQualityGateConditionValue $qualityGate $MetricKey)
}

function Get-SonarReadbackNewCodeIssueTotal([object]$Readback) {
  $newCode = Get-Prop $Readback "new_code" $null
  $issues = Get-Prop $newCode "issues" $null
  $total = Get-Prop $issues "total" $null
  if ($null -ne $total) {
    return [int]$total
  }

  return $null
}

function Get-SonarReadbackQualityGateHotspotReviewedPercentage([object]$Readback) {
  return (Get-SonarReadbackMetricValue $Readback 'new_security_hotspots_reviewed')
}

function Get-SonarLiveQualityGateHotspotReviewedPercentage([object]$LiveQualityGate, [object]$LiveHotspots) {
  $conditionValue = Get-SonarQualityGateConditionValue $LiveQualityGate 'new_security_hotspots_reviewed'
  if ($null -ne $conditionValue) {
    return $conditionValue
  }

  $reviewedPercentage = ConvertTo-SonarParityNumber (Get-Prop $LiveHotspots 'reviewed_percentage' $null)
  if ($null -ne $reviewedPercentage) {
    return $reviewedPercentage
  }

  $reviewed = ConvertTo-SonarParityNumber (Get-Prop $LiveHotspots 'reviewed' $null)
  $toReview = ConvertTo-SonarParityNumber (Get-Prop $LiveHotspots 'to_review' $null)
  if ($null -ne $reviewed -and $null -ne $toReview) {
    $total = $reviewed + $toReview
    if ($total -gt 0) {
      return [math]::Round(($reviewed * 100.0) / $total, 1)
    }
  }

  if ($null -ne $toReview -and $toReview -eq 0) {
    return 100.0
  }

  return $null
}

function Get-SonarReadbackHotspotSearchReviewedPercentage([object]$Readback) {
  $newCode = Get-Prop $Readback "new_code" $null
  $hotspots = Get-Prop $newCode "hotspots" $null
  $leakPeriodPercentage = Get-Prop $hotspots "since_leak_period_reviewed_percentage" $null
  if ($null -ne $leakPeriodPercentage) {
    return (ConvertTo-SonarParityNumber $leakPeriodPercentage)
  }

  $percentage = Get-Prop $hotspots "reviewed_percentage" $null
  if ($null -ne $percentage) {
    return (ConvertTo-SonarParityNumber $percentage)
  }

  return (Get-SonarReadbackQualityGateHotspotReviewedPercentage $Readback)
}

function Get-SonarReadbackHotspotToReviewTotal([object]$Readback) {
  $newCode = Get-Prop $Readback "new_code" $null
  $hotspots = Get-Prop $newCode "hotspots" $null
  $toReview = Get-Prop $hotspots "to_review" $null
  $total = Get-Prop $toReview "total" $null
  if ($null -ne $total) {
    return [int]$total
  }

  return $null
}

function Get-SonarQualityGateStatusFromAnalysis([object]$Analysis) {
  foreach ($event in @(Get-Prop $Analysis "events" @())) {
    if ([string](Get-Prop $event "category" "") -ne 'QUALITY_GATE') {
      continue
    }

    $name = [string](Get-Prop $event "name" "")
    switch ($name) {
      'Passed' { return 'OK' }
      'Failed' { return 'ERROR' }
      default { return $name.ToUpperInvariant() }
    }
  }

  return $null
}

function Get-SonarReadbackAnalysisQualityGateStatus([object]$Readback) {
  $qualityGateEvent = Get-Prop (Get-Prop $Readback 'analysis' $null) 'quality_gate_event' $null
  if (-not $qualityGateEvent) {
    return $null
  }

  $name = [string](Get-Prop $qualityGateEvent 'name' '')
  switch ($name) {
    'Passed' { return 'OK' }
    'Failed' { return 'ERROR' }
    default { return $name }
  }
}

function Get-SonarAnalysisQualityGateStatusOrFallback([object]$Analysis, [object]$QualityGate) {
  $status = Get-SonarQualityGateStatusFromAnalysis $Analysis
  if (-not [string]::IsNullOrWhiteSpace([string]$status)) {
    return $status
  }

  return [string](Get-Prop $QualityGate 'status' $null)
}

function Get-SonarTokenContext() {
  $tokenFromUser = [string][Environment]::GetEnvironmentVariable("SONAR_TOKEN", "User")
  if (-not [string]::IsNullOrWhiteSpace($tokenFromUser)) {
    return [pscustomobject]@{
      token = $tokenFromUser
      source = 'user'
    }
  }

  $tokenFromProcess = [string]$env:SONAR_TOKEN
  if (-not [string]::IsNullOrWhiteSpace($tokenFromProcess)) {
    return [pscustomobject]@{
      token = $tokenFromProcess
      source = 'process'
    }
  }

  return $null
}

function New-SonarCiAuthHeader([string]$Token) {
  if ([string]::IsNullOrWhiteSpace($Token)) {
    return @{}
  }

  $credential = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:" -f $Token)))
  return @{ Authorization = ("Basic " + $credential) }
}

function Invoke-SonarCiJsonApi(
  [string]$Uri,
  [hashtable]$Headers = @{},
  [int]$TimeoutSec = 20
) {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -SkipHttpErrorCheck -Uri $Uri -Headers $Headers -TimeoutSec $TimeoutSec
    $rawBody = [string]$response.Content
    $body = $null
    if (-not [string]::IsNullOrWhiteSpace($rawBody)) {
      try {
        $body = $rawBody | ConvertFrom-Json -Depth 100
      } catch {
        $body = $null
      }
    }

    return [pscustomobject]@{
      reachable = $true
      status_code = [int]$response.StatusCode
      ok = [bool]($response.StatusCode -ge 200 -and $response.StatusCode -lt 300)
      body = $body
      raw_body = $rawBody
      error = $null
      uri = $Uri
    }
  } catch {
    return [pscustomobject]@{
      reachable = $false
      status_code = $null
      ok = $false
      body = $null
      raw_body = $null
      error = $_.Exception.Message
      uri = $Uri
    }
  }
}

function Get-SonarLiveParityContext([string]$HostUrl, [string]$ProjectKey) {
  $tokenContext = Get-SonarTokenContext
  $headers = $(if ($tokenContext) { New-SonarCiAuthHeader $tokenContext.token } else { @{} })
  $readbackFallback = Read-SonarReadbackReport

  $qualityGateResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/qualitygates/project_status?projectKey=$ProjectKey") -Headers $headers
  $analysisResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/project_analyses/search?project=$ProjectKey&ps=1") -Headers $headers
  $branchResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/project_branches/list?project=$ProjectKey") -Headers $headers
  $newIssueResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/issues/search?componentKeys=$ProjectKey&resolved=false&ps=200&inNewCodePeriod=true&additionalFields=_all") -Headers $headers
  $hotspotToReviewResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/hotspots/search?projectKey=$ProjectKey&ps=100&status=TO_REVIEW&sinceLeakPeriod=true") -Headers $headers
  $hotspotReviewedResponse = Invoke-SonarCiJsonApi -Uri ($HostUrl.TrimEnd('/') + "/api/hotspots/search?projectKey=$ProjectKey&ps=100&status=REVIEWED&sinceLeakPeriod=true") -Headers $headers

  $responses = @($qualityGateResponse, $analysisResponse, $branchResponse, $newIssueResponse, $hotspotToReviewResponse, $hotspotReviewedResponse)
  $available = @($responses | Where-Object { -not [bool]$_.ok }).Count -eq 0
  $errors = @($responses | Where-Object { -not [bool]$_.ok } | ForEach-Object {
    [pscustomobject]@{
      uri = [string](Get-Prop $_ 'uri' '')
      reachable = [bool](Get-Prop $_ 'reachable' $false)
      status_code = Get-Prop $_ 'status_code' $null
      error = [string](Get-Prop $_ 'error' '')
    }
  })

  $analysis = $null
  if ($analysisResponse.ok) {
    $analysisItems = @((Get-Prop $analysisResponse.body 'analyses' @()))
    if ($analysisItems.Count -gt 0) {
      $analysis = $analysisItems[0]
    }
  }
  $analysisFallbackUsed = $false
  if (-not $analysis -and $readbackFallback) {
    $fallbackAnalysis = Get-Prop $readbackFallback 'analysis' $null
    if ($fallbackAnalysis) {
      $analysis = $fallbackAnalysis
      $analysisFallbackUsed = $true
    }
  }

  $branch = $null
  if ($branchResponse.ok) {
    $branches = @((Get-Prop $branchResponse.body 'branches' @()))
    $mainBranch = @($branches | Where-Object { [bool](Get-Prop $_ 'isMain' $false) } | Select-Object -First 1)
    if ($mainBranch.Count -gt 0) {
      $branch = $mainBranch[0]
    } elseif ($branches.Count -gt 0) {
      $branch = $branches[0]
    }
  }

  $qualityGate = if ($qualityGateResponse.ok) { Get-Prop $qualityGateResponse.body 'projectStatus' $null } else { $null }
  $toReviewTotal = if ($hotspotToReviewResponse.ok) { [int](Get-Prop (Get-Prop $hotspotToReviewResponse.body 'paging' $null) 'total' 0) } else { 0 }
  $reviewedTotal = if ($hotspotReviewedResponse.ok) { [int](Get-Prop (Get-Prop $hotspotReviewedResponse.body 'paging' $null) 'total' 0) } else { 0 }
  $hotspotFallbackUsed = $false
  if ((-not $hotspotToReviewResponse.ok -or -not $hotspotReviewedResponse.ok) -and $readbackFallback) {
    $fallbackHotspots = Get-Prop (Get-Prop $readbackFallback 'new_code' $null) 'hotspots' $null
    $fallbackToReview = Get-Prop (Get-Prop $fallbackHotspots 'to_review' $null) 'total' $null
    $fallbackReviewed = Get-Prop (Get-Prop $fallbackHotspots 'reviewed' $null) 'total' $null
    if ($null -ne $fallbackToReview -and $null -ne $fallbackReviewed) {
      $toReviewTotal = [int]$fallbackToReview
      $reviewedTotal = [int]$fallbackReviewed
      $hotspotFallbackUsed = $true
    }
  }
  $hotspotTotal = $toReviewTotal + $reviewedTotal
  $reviewedPercentage = if ($hotspotTotal -gt 0) {
    [math]::Round(($reviewedTotal * 100.0) / $hotspotTotal, 1)
  } else {
    100.0
  }
  $fallbackCompletesPrivilegedReadback =
    [bool]$tokenContext `
    -and [bool]$qualityGateResponse.ok `
    -and [bool]$branchResponse.ok `
    -and [bool]$newIssueResponse.ok `
    -and [bool]$analysis `
    -and ($analysisResponse.ok -or $analysisFallbackUsed) `
    -and ($hotspotToReviewResponse.ok -or $hotspotFallbackUsed) `
    -and ($hotspotReviewedResponse.ok -or $hotspotFallbackUsed)
  if (-not $available -and $fallbackCompletesPrivilegedReadback) {
    $available = $true
  }

  return [pscustomobject]@{
    available = $available
    token_source = $(if ($tokenContext) { [string]$tokenContext.source } else { 'missing' })
    fallback_used = [pscustomobject]@{
      analysis = $analysisFallbackUsed
      hotspots = $hotspotFallbackUsed
    }
    quality_gate = $qualityGate
    analysis = $analysis
    branch = $branch
    new_issues_total = $(if ($newIssueResponse.ok) { [int](Get-Prop $newIssueResponse.body 'total' 0) } else { $null })
    hotspots = [pscustomobject]@{
      to_review = $toReviewTotal
      reviewed = $reviewedTotal
      total = $hotspotTotal
      reviewed_percentage = $reviewedPercentage
    }
    errors = $errors
  }
}

function Test-SonarParityMatch($ReadbackValue, $LiveValue, [string]$Mode = 'string') {
  if ($null -eq $ReadbackValue -and $null -eq $LiveValue) {
    return $true
  }

  if ($Mode -eq 'number') {
    $readbackNumber = ConvertTo-SonarParityNumber $ReadbackValue
    $liveNumber = ConvertTo-SonarParityNumber $LiveValue
    if ($null -eq $readbackNumber -and $null -eq $liveNumber) {
      return $true
    }

    if ($null -eq $readbackNumber -or $null -eq $liveNumber) {
      return $false
    }

    return [math]::Abs($readbackNumber - $liveNumber) -lt 0.05
  }

  return ([string]$ReadbackValue -eq [string]$LiveValue)
}

function Add-SonarParityComparison([System.Collections.Generic.List[object]]$Comparisons, [string]$Field, $ReadbackValue, $LiveValue, [string]$Mode = 'string') {
  $Comparisons.Add([pscustomobject]@{
    field = $Field
    readback = $ReadbackValue
    live = $LiveValue
    matches = (Test-SonarParityMatch $ReadbackValue $LiveValue $Mode)
    mode = $Mode
  })
}

function Get-SonarParityPayload() {
  $readback = Read-SonarReadbackReport
  if (-not $readback) {
    return $null
  }

  $scanContext = Read-SonarScanContext
  $hostUrl = [string](Get-Prop $readback 'host_url' 'http://127.0.0.1:9000')
  $projectKey = [string](Get-Prop $readback 'project_key' '')
  if ([string]::IsNullOrWhiteSpace($projectKey)) {
    return $null
  }

  $liveContext = Get-SonarLiveParityContext -HostUrl $hostUrl -ProjectKey $projectKey
  $qualityGate = Get-SonarReadbackQualityGate $readback
  $readbackPeriod = Get-SonarReadbackNewCodePeriod $readback
  $readbackCoverage = Get-SonarReadbackMetricValue $readback 'new_coverage'
  $readbackViolations = Get-SonarReadbackMetricValue $readback 'new_violations'
  $readbackQualityGateHotspotReviewed = Get-SonarReadbackQualityGateHotspotReviewedPercentage $readback
  $readbackHotspotSearchReviewed = Get-SonarReadbackHotspotSearchReviewedPercentage $readback
  $readbackIssuesTotal = Get-SonarReadbackNewCodeIssueTotal $readback
  $readbackHotspotToReview = Get-SonarReadbackHotspotToReviewTotal $readback

  $liveQualityGate = Get-Prop $liveContext 'quality_gate' $null
  $liveAnalysis = Get-Prop $liveContext 'analysis' $null
  $liveBranch = Get-Prop $liveContext 'branch' $null
  $liveHotspots = Get-Prop $liveContext 'hotspots' $null
  $livePeriod = Get-Prop $liveQualityGate 'period' $null
  $scanAnalysis = Get-Prop $scanContext 'analysis' $null
  $scanCeTask = Get-Prop $scanContext 'ce_task' $null

  $comparisons = New-Object System.Collections.Generic.List[object]
  if ($scanContext) {
    Add-SonarParityComparison $comparisons 'scan_context.host_url' (Get-Prop $scanContext 'host_url' $null) $hostUrl
    Add-SonarParityComparison $comparisons 'scan_context.project_key' (Get-Prop $scanContext 'project_key' $null) $projectKey
    Add-SonarParityComparison $comparisons 'scan_context.ce_task.status' (Get-Prop $scanCeTask 'status' $null) 'SUCCESS'
    Add-SonarParityComparison $comparisons 'scan_context.analysis.key.readback' (Get-Prop $scanAnalysis 'key' $null) (Get-Prop (Get-Prop $readback 'analysis' $null) 'key' $null)
    Add-SonarParityComparison $comparisons 'scan_context.analysis.date.readback' (ConvertTo-SonarParityDateString (Get-Prop $scanAnalysis 'date' $null)) (ConvertTo-SonarParityDateString (Get-Prop (Get-Prop $readback 'analysis' $null) 'date' $null))
    Add-SonarParityComparison $comparisons 'scan_context.analysis.revision.readback' (Get-Prop $scanAnalysis 'revision' $null) (Get-Prop (Get-Prop $readback 'analysis' $null) 'revision' $null)
  }

  if ([bool](Get-Prop $liveContext 'available' $false)) {
    if ($scanContext) {
      Add-SonarParityComparison $comparisons 'scan_context.analysis.key.live' (Get-Prop $scanAnalysis 'key' $null) (Get-Prop $liveAnalysis 'key' $null)
      Add-SonarParityComparison $comparisons 'scan_context.analysis.date.live' (ConvertTo-SonarParityDateString (Get-Prop $scanAnalysis 'date' $null)) (ConvertTo-SonarParityDateString (Get-Prop $liveAnalysis 'date' $null))
      Add-SonarParityComparison $comparisons 'scan_context.analysis.revision.live' (Get-Prop $scanAnalysis 'revision' $null) (Get-Prop $liveAnalysis 'revision' $null)
    }

    Add-SonarParityComparison $comparisons 'quality_gate.status' (Get-Prop $qualityGate 'status' $null) (Get-Prop $liveQualityGate 'status' $null)
    Add-SonarParityComparison $comparisons 'branch.name' (Get-Prop (Get-Prop $readback 'branch' $null) 'name' $null) (Get-Prop $liveBranch 'name' $null)
    Add-SonarParityComparison $comparisons 'branch.analysis_date' (ConvertTo-SonarParityDateString (Get-Prop (Get-Prop $readback 'branch' $null) 'analysis_date' $null)) (ConvertTo-SonarParityDateString (Get-Prop $liveBranch 'analysisDate' $null))
    Add-SonarParityComparison $comparisons 'branch.quality_gate_status' (Get-Prop (Get-Prop $readback 'branch' $null) 'quality_gate_status' $null) (Get-Prop (Get-Prop $liveBranch 'status' $null) 'qualityGateStatus' $null)
    Add-SonarParityComparison $comparisons 'analysis.key' (Get-Prop (Get-Prop $readback 'analysis' $null) 'key' $null) (Get-Prop $liveAnalysis 'key' $null)
    Add-SonarParityComparison $comparisons 'analysis.date' (ConvertTo-SonarParityDateString (Get-Prop (Get-Prop $readback 'analysis' $null) 'date' $null)) (ConvertTo-SonarParityDateString (Get-Prop $liveAnalysis 'date' $null))
    Add-SonarParityComparison $comparisons 'analysis.revision' (Get-Prop (Get-Prop $readback 'analysis' $null) 'revision' $null) (Get-Prop $liveAnalysis 'revision' $null)
    Add-SonarParityComparison $comparisons 'analysis.quality_gate_status' (Get-SonarReadbackAnalysisQualityGateStatus $readback) (Get-SonarAnalysisQualityGateStatusOrFallback $liveAnalysis $liveQualityGate)
    Add-SonarParityComparison $comparisons 'new_code.period.mode' (Get-Prop $readbackPeriod 'mode' $null) (Get-Prop $livePeriod 'mode' $null)
    Add-SonarParityComparison $comparisons 'new_code.period.date' (ConvertTo-SonarParityDateString (Get-Prop $readbackPeriod 'date' $null)) (ConvertTo-SonarParityDateString (Get-Prop $livePeriod 'date' $null))
    Add-SonarParityComparison $comparisons 'new_code.period.parameter' (Get-Prop $readbackPeriod 'parameter' $null) (Get-Prop $livePeriod 'parameter' $null)
    Add-SonarParityComparison $comparisons 'new_code.metrics.new_coverage' $readbackCoverage (Get-SonarQualityGateConditionValue $liveQualityGate 'new_coverage') 'number'
    Add-SonarParityComparison $comparisons 'new_code.metrics.new_violations' $readbackViolations (Get-SonarQualityGateConditionValue $liveQualityGate 'new_violations') 'number'
    Add-SonarParityComparison $comparisons 'new_code.metrics.new_security_hotspots_reviewed' $readbackQualityGateHotspotReviewed (Get-SonarLiveQualityGateHotspotReviewedPercentage $liveQualityGate $liveHotspots) 'number'
    Add-SonarParityComparison $comparisons 'new_code.issues.total' $readbackIssuesTotal (Get-Prop $liveContext 'new_issues_total' $null) 'number'
    Add-SonarParityComparison $comparisons 'new_code.hotspots.to_review' $readbackHotspotToReview (Get-Prop $liveHotspots 'to_review' $null) 'number'
    Add-SonarParityComparison $comparisons 'new_code.hotspots.reviewed_percentage' $readbackHotspotSearchReviewed (Get-Prop $liveHotspots 'reviewed_percentage' $null) 'number'
  }

  $mismatchedFields = @($comparisons | Where-Object { -not [bool](Get-Prop $_ 'matches' $false) } | ForEach-Object { [string](Get-Prop $_ 'field' '') })
  $readbackQualityGateStatus = [string](Get-Prop $qualityGate 'status' '')
  $blockingReason = 'none'

  if ($mismatchedFields.Count -gt 0) {
    $blockingReason = 'context_mismatch'
  } elseif ($readbackQualityGateStatus -and $readbackQualityGateStatus -ne 'OK') {
    $blockingReason = 'quality_gate_failed'
  }

  $blocking = $blockingReason -ne 'none'
  $consistent = $mismatchedFields.Count -eq 0

  return [pscustomobject]@{
    ts = (NowIso)
    host_url = $hostUrl
    project_key = $projectKey
    scan_context = $(if ($scanContext) {
      [pscustomobject]@{
        path = '.ci/run/sonar.scan.context.json'
        ts = [string](Get-Prop $scanContext 'ts' '')
        host_url = [string](Get-Prop $scanContext 'host_url' '')
        project_key = [string](Get-Prop $scanContext 'project_key' '')
        report_task = Get-Prop $scanContext 'report_task' $null
        ce_task = Get-Prop $scanContext 'ce_task' $null
        analysis = Get-Prop $scanContext 'analysis' $null
      }
    } else {
      $null
    })
    readback = [pscustomobject]@{
      path = 'logs/review/sonar-readback-latest.json'
      ts = [string](Get-Prop $readback 'ts' '')
      branch = Get-Prop $readback 'branch' $null
      analysis = Get-Prop $readback 'analysis' $null
      quality_gate = $qualityGate
      new_code = Get-Prop $readback 'new_code' $null
      parity_context = Get-Prop $readback 'parity_context' $null
    }
    live = [pscustomobject]@{
      available = [bool](Get-Prop $liveContext 'available' $false)
      token_source = [string](Get-Prop $liveContext 'token_source' '')
      branch = $(if ($liveBranch) {
        [pscustomobject]@{
          name = [string](Get-Prop $liveBranch 'name' '')
          analysis_date = (ConvertTo-SonarParityDateString (Get-Prop $liveBranch 'analysisDate' $null))
          quality_gate_status = [string](Get-Prop (Get-Prop $liveBranch 'status' $null) 'qualityGateStatus' '')
        }
      } else {
        $null
      })
      analysis = $(if ($liveAnalysis) {
        [pscustomobject]@{
          key = [string](Get-Prop $liveAnalysis 'key' '')
          date = (ConvertTo-SonarParityDateString (Get-Prop $liveAnalysis 'date' $null))
          revision = [string](Get-Prop $liveAnalysis 'revision' '')
          quality_gate_status = [string](Get-SonarAnalysisQualityGateStatusOrFallback $liveAnalysis $liveQualityGate)
        }
      } else {
        $null
      })
      quality_gate = $liveQualityGate
      new_code = [pscustomobject]@{
        issues_total = Get-Prop $liveContext 'new_issues_total' $null
        hotspots = $liveHotspots
      }
      errors = @(Get-Prop $liveContext 'errors' @())
    }
    parity = [pscustomobject]@{
      consistent = $consistent
      blocking = $blocking
      blocking_reason = $blockingReason
      comparisons = $comparisons.ToArray()
      mismatched_fields = $mismatchedFields
    }
  }
}

function Write-SonarParityArtifacts([object]$ParityPayload) {
  $paths = Get-SonarParityArtifactPaths
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $paths.json_path), (Split-Path -Parent $paths.markdown_path) | Out-Null
  Write-Json $paths.json_path $ParityPayload

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('# SONAR-043 Sonar UI/API Parity')
  $lines.Add('')
  $lines.Add('- ts: `' + [string](Get-Prop $ParityPayload 'ts' '') + '`')
  $lines.Add('- host_url: `' + [string](Get-Prop $ParityPayload 'host_url' '') + '`')
  $lines.Add('- project_key: `' + [string](Get-Prop $ParityPayload 'project_key' '') + '`')
  $lines.Add('- blocking: `' + [string](Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'blocking' $false) + '`')
  $lines.Add('- blocking_reason: `' + [string](Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'blocking_reason' '') + '`')
  $lines.Add('- quality_gate_status: `' + [string](Get-Prop (Get-Prop (Get-Prop $ParityPayload 'readback' $null) 'quality_gate' $null) 'status' '') + '`')
  $lines.Add('- live_context_available: `' + [string][bool](Get-Prop (Get-Prop $ParityPayload 'live' $null) 'available' $false) + '`')
  $lines.Add('- scan_context_path: `' + [string](Get-Prop (Get-Prop $ParityPayload 'scan_context' $null) 'path' '') + '`')
  $lines.Add('- scan_context_analysis_key: `' + [string](Get-Prop (Get-Prop (Get-Prop $ParityPayload 'scan_context' $null) 'analysis' $null) 'key' '') + '`')
  $lines.Add('- scan_context_ce_task_id: `' + [string](Get-Prop (Get-Prop (Get-Prop $ParityPayload 'scan_context' $null) 'report_task' $null) 'ce_task_id' '') + '`')
  $lines.Add('')
  $lines.Add('## Comparisons')
  $lines.Add('')
  foreach ($comparison in @(Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'comparisons' @())) {
    $lines.Add('- `' + [string](Get-Prop $comparison 'field' '') + '` readback=`' + [string](Get-Prop $comparison 'readback' '') + '` live=`' + [string](Get-Prop $comparison 'live' '') + '` matches=`' + [string](Get-Prop $comparison 'matches' $false) + '`')
  }
  $lines.Add('')
  $lines.Add('```json')
  $lines.Add((To-Json $ParityPayload))
  $lines.Add('```')
  Atomic-WriteTextUtf8 $paths.markdown_path (($lines -join "`r`n") + "`r`n")

  return $paths
}

function Get-SonarGuardSummary([object]$ParityPayload) {
  $qualityGateStatus = [string](Get-Prop (Get-Prop (Get-Prop $ParityPayload 'readback' $null) 'quality_gate' $null) 'status' '')
  $newCode = Get-Prop (Get-Prop $ParityPayload 'readback' $null) 'new_code' $null
  $metrics = Get-Prop $newCode 'metrics' $null
  $coverage = ConvertTo-SonarParityNumber (Get-Prop $metrics 'new_coverage' $null)
  $violations = ConvertTo-SonarParityNumber (Get-Prop $metrics 'new_violations' $null)
  $hotspotsReviewed = Get-SonarReadbackQualityGateHotspotReviewedPercentage (Get-Prop $ParityPayload 'readback' $null)
  $blockingReason = [string](Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'blocking_reason' '')

  if ([bool](Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'blocking' $false)) {
    return ('sonar blocked: reason=' + $blockingReason + ' quality_gate=' + $qualityGateStatus + ' new_coverage=' + $coverage + ' new_violations=' + $violations + ' new_security_hotspots_reviewed=' + $hotspotsReviewed)
  }

  return ('sonar ok: quality_gate=' + $qualityGateStatus + ' new_coverage=' + $coverage + ' new_violations=' + $violations + ' new_security_hotspots_reviewed=' + $hotspotsReviewed)
}

function Get-SonarGuardNextStep([object]$ParityPayload) {
  $blockingReason = [string](Get-Prop (Get-Prop $ParityPayload 'parity' $null) 'blocking_reason' '')
  switch ($blockingReason) {
    'context_mismatch' { return 'Pruefe SONAR-043 mit logs/data/SONAR-043-sonar-ui-api-parity.json und gleiche Readback, Analyse und Handoff fuer denselben Lauf ab.' }
    'quality_gate_failed' { return 'Bearbeite SONAR-054, SONAR-055 und SONAR-056, bis new_violations = 0 und new_security_hotspots_reviewed = 100 sind.' }
    default { return '' }
  }
}

function Cmd-SonarStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Ensure-NonInteractiveEnv
  CI-Info "sonar-start: starting SonarQube server..."
  $logPath = Join-Path $LogsRoot ("terminal\sonar-start-" + (TsId) + ".log")
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"
  $statusUrl = "http://127.0.0.1:9000/api/system/status"
  $listenerPid = Get-SonarListeningPid
  $alreadyReachable = Test-SonarStatusUp $statusUrl
  if ($alreadyReachable -and -not $listenerPid) { $listenerPid = Get-SonarListeningPid }
  if ($alreadyReachable -and $listenerPid) {
    Write-SonarPidSnapshot $pidPath $listenerPid "sonar already reachable on port 9000" (Get-Location).Path
  }

  New-Item -ItemType Directory -Force .ci/run, logs/terminal | Out-Null
  Clear-SonarCommandOutcome
  $helper = Join-Path $RepoRoot "scripts\sonarqube-start.ps1"
  if (-not (Test-Path -LiteralPath $helper)) {
    throw ("sonar-start: helper script missing: " + $helper)
  }
  $cmd = ('pwsh -NoProfile -File "' + $helper + '"')
  $res = Run-Cmd $cmd $logPath
  if ($res.exit -ne 0) { throw ("sonar-start: helper script failed. See " + $logPath) }

  $listenerPid = Get-SonarListeningPid
  if ($listenerPid) {
    Write-SonarPidSnapshot $pidPath $listenerPid "sonarqube-start.ps1" (Get-Location).Path
  }

  $startStatus = Read-SonarStartStatus
  $decision = $null
  if ($startStatus) { $decision = [string]$startStatus.decision }

  if ($decision -eq "repair_applied") {
    CI-Info ("sonar-start: loopback repair applied. PID: " + $(if ($listenerPid) { $listenerPid } else { "unknown" }))
  } elseif ($decision -eq "server_down") {
    CI-Info ("sonar-start: SonarQube server started in background. PID: " + $(if ($listenerPid) { $listenerPid } else { "unknown" }))
  } elseif ($alreadyReachable) {
    CI-Info ("sonar-start: SonarQube already reachable on port 9000. PID: " + $(if ($listenerPid) { $listenerPid } else { "unknown" }))
  } else {
    CI-Info ("sonar-start: SonarQube reachable on port 9000. PID: " + $(if ($listenerPid) { $listenerPid } else { "unknown" }))
  }
}

function Cmd-SonarStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "sonar-stop: stopping SonarQube server..."
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"

  # 1) Primär: PID-Datei
  if (Test-Path $pidPath) {
    $j = Get-Content -Raw $pidPath | ConvertFrom-Json
    Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
    Remove-Item $pidPath -ErrorAction SilentlyContinue
    CI-Info "sonar-stop: SonarQube server stopped via PID."
    return
  }

  # 2) Fallback: Port 9000
  $processId = (Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
  if ($processId) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    CI-Info "sonar-stop: SonarQube server stopped via port scan."
    return
  }

  CI-Warn "sonar-stop: SonarQube server not found or already stopped."
}
