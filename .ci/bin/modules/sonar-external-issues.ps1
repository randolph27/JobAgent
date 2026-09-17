function Get-SonarExternalProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) { return $Default }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $Default }
  return $property.Value
}

function Resolve-SonarExternalContainedPath {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
    throw 'sonar_external_path_invalid'
  }
  $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $candidate = [IO.Path]::GetFullPath((Join-Path $normalizedRoot $RelativePath))
  if (-not $candidate.StartsWith($normalizedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'sonar_external_path_outside_root'
  }
  return $candidate
}

function Get-SonarExternalRelativePath {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Path)
  $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $fullPath = [IO.Path]::GetFullPath($Path)
  if (-not $fullPath.StartsWith($normalizedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'sonar_external_path_outside_root'
  }
  return $fullPath.Substring($normalizedRoot.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, '/')
}

function Test-SonarExternalFileHash {
  param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelativePath, [Parameter(Mandatory)][string]$ExpectedHash)
  $path = Resolve-SonarExternalContainedPath -Root $Root -RelativePath $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'sonar_toolchain_artifact_missing' }
  if ($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'sonar_toolchain_pin_invalid' }
  $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  if ($actualHash -ne $ExpectedHash.ToUpperInvariant()) { throw 'sonar_toolchain_hash_mismatch' }
  return $path
}

function Test-SonarExternalToolchain {
  param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][object]$SonarConfig)
  $toolchain = Get-SonarExternalProperty -Object $SonarConfig -Name 'toolchain'
  if (([string](Get-SonarExternalProperty -Object $toolchain -Name 'status')) -ne 'verified') { throw 'sonar_toolchain_not_verified' }
  if (([string](Get-SonarExternalProperty -Object $toolchain -Name 'analysis_scope')) -ne 'external-powershell-issues-only') { throw 'sonar_analysis_scope_invalid' }
  $artifactRoot = Resolve-SonarExternalContainedPath -Root $RepoRoot -RelativePath ([string](Get-SonarExternalProperty -Object $toolchain -Name 'artifact_root'))
  $artifacts = @((Get-SonarExternalProperty -Object $toolchain -Name 'artifacts' -Default @()))
  if ($artifacts.Count -ne 3 -or (@($artifacts.id | Sort-Object) -join ',') -ne 'java-runtime,PSScriptAnalyzer,sonar-scanner-cli') {
    throw 'sonar_toolchain_artifact_set_invalid'
  }
  foreach ($artifact in $artifacts) {
    $null = Test-SonarExternalFileHash -Root $artifactRoot -RelativePath ([string](Get-SonarExternalProperty $artifact 'package_relative_path')) -ExpectedHash ([string](Get-SonarExternalProperty $artifact 'package_sha256'))
    $null = Test-SonarExternalFileHash -Root $artifactRoot -RelativePath ([string](Get-SonarExternalProperty $artifact 'relative_path')) -ExpectedHash ([string](Get-SonarExternalProperty $artifact 'sha256'))
  }
  return [pscustomobject]@{ status = 'verified'; artifact_root = $artifactRoot; artifact_count = $artifacts.Count; secret_sanitized = $true }
}

function Get-SonarExternalSourceFiles {
  param([Parameter(Mandatory)][string]$RepoRoot)
  $includeRoots = @('.ci/bin', 'tools')
  $files = foreach ($relativeRoot in $includeRoots) {
    $sourceRoot = Resolve-SonarExternalContainedPath -Root $RepoRoot -RelativePath $relativeRoot
    if (Test-Path -LiteralPath $sourceRoot -PathType Container) {
      Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Include '*.ps1', '*.psm1'
    }
  }
  return @($files | Sort-Object FullName)
}

function Test-SonarExternalAllowedRelativePath {
  param([Parameter(Mandatory)][string]$RelativePath)
  return $RelativePath.StartsWith('.ci/bin/', [StringComparison]::OrdinalIgnoreCase) -or $RelativePath.StartsWith('tools/', [StringComparison]::OrdinalIgnoreCase)
}

function Get-SonarExternalPssaRuleIds {
  param([Parameter(Mandatory)][string]$ModuleManifestPath)
  Import-Module -Name $ModuleManifestPath -Force -ErrorAction Stop
  return @((Get-ScriptAnalyzerRule | ForEach-Object { [string]$_.RuleName } | Sort-Object -Unique))
}

function ConvertTo-SonarExternalSeverity {
  param([Parameter(Mandatory)][string]$Severity)
  switch ($Severity) {
    'Error' { return 'MAJOR' }
    'Warning' { return 'MINOR' }
    'Information' { return 'INFO' }
    default { throw 'sonar_external_severity_invalid' }
  }
}

function ConvertTo-SonarGenericExternalIssueReport {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [object[]]$Records = @(),
    [Parameter(Mandatory)][string[]]$KnownRules,
    [Parameter(Mandatory)][string]$OutputPath
  )
  if ($Records.Count -eq 0) { throw 'sonar_external_report_empty' }
  $knownRuleSet = @{}
  foreach ($rule in $KnownRules) { if (-not [string]::IsNullOrWhiteSpace($rule)) { $knownRuleSet[$rule] = $true } }
  if ($knownRuleSet.Count -eq 0) { throw 'sonar_external_rule_registry_empty' }
  $issues = New-Object System.Collections.Generic.List[object]
  $seen = @{}
  foreach ($record in $Records) {
    $ruleId = [string](Get-SonarExternalProperty $record 'RuleName')
    if (-not $knownRuleSet.ContainsKey($ruleId)) { throw 'sonar_external_rule_unknown' }
    $message = ([string](Get-SonarExternalProperty $record 'Message')).Trim()
    if ([string]::IsNullOrWhiteSpace($message)) { throw 'sonar_external_message_invalid' }
    $relativePath = Get-SonarExternalRelativePath -Root $RepoRoot -Path ([string](Get-SonarExternalProperty $record 'ScriptPath'))
    if (-not (Test-SonarExternalAllowedRelativePath -RelativePath $relativePath)) { throw 'sonar_external_path_not_scannable' }
    $sourcePath = Resolve-SonarExternalContainedPath -Root $RepoRoot -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw 'sonar_external_source_missing' }
    $lineValue = Get-SonarExternalProperty $record 'Line' $null
    $textRange = $null
    $startLine = $null
    $endLine = $null
    if ($null -ne $lineValue) {
      $startLine = [int]$lineValue
      $endLineValue = Get-SonarExternalProperty $record 'EndLine' $null
      $endLine = if ($null -eq $endLineValue) { $startLine } else { [int]$endLineValue }
      $lineCount = @([IO.File]::ReadAllLines($sourcePath)).Count
      if ($startLine -lt 1 -or $endLine -lt $startLine -or $endLine -gt $lineCount) { throw 'sonar_external_line_invalid' }
      $textRange = [ordered]@{ startLine = $startLine; endLine = $endLine }
    }
    $severity = ConvertTo-SonarExternalSeverity -Severity ([string](Get-SonarExternalProperty $record 'Severity'))
    $dedupeKey = $ruleId + '|' + $relativePath + '|' + $startLine + '|' + $endLine + '|' + $message
    if ($seen.ContainsKey($dedupeKey)) { continue }
    $seen[$dedupeKey] = $true
    $location = [ordered]@{
      message = $message
      filePath = $relativePath
    }
    if ($null -ne $textRange) { $location.textRange = $textRange }
    $issues.Add([ordered]@{
      engineId = 'PSScriptAnalyzer'
      ruleId = $ruleId
      severity = $severity
      type = 'CODE_SMELL'
      primaryLocation = $location
    })
  }
  $outputFullPath = [IO.Path]::GetFullPath($OutputPath)
  $outputDirectory = Split-Path -Parent $outputFullPath
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
  $json = [ordered]@{ issues = @($issues.ToArray()) } | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText($outputFullPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  return [pscustomobject]@{ output_path = $outputFullPath; issue_count = $issues.Count; report_sha256 = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash; secret_sanitized = $true }
}

function Invoke-SonarExternalIssuesReport {
  param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][object]$SonarConfig, [Parameter(Mandatory)][string]$OutputPath)
  $toolchain = Test-SonarExternalToolchain -RepoRoot $RepoRoot -SonarConfig $SonarConfig
  $analyzer = @((Get-SonarExternalProperty $SonarConfig 'toolchain').artifacts | Where-Object { $_.id -eq 'PSScriptAnalyzer' } | Select-Object -First 1)
  $manifestPath = Resolve-SonarExternalContainedPath -Root $toolchain.artifact_root -RelativePath ([string]$analyzer.relative_path)
  $knownRules = Get-SonarExternalPssaRuleIds -ModuleManifestPath $manifestPath
  $files = Get-SonarExternalSourceFiles -RepoRoot $RepoRoot
  if ($files.Count -eq 0) { throw 'sonar_external_source_empty' }
  $records = @(foreach ($file in $files) { Invoke-ScriptAnalyzer -Path $file.FullName -ErrorAction Stop })
  return ConvertTo-SonarGenericExternalIssueReport -RepoRoot $RepoRoot -Records $records -KnownRules $knownRules -OutputPath $OutputPath
}

function Get-SonarExternalToolchainArtifact {
  param([Parameter(Mandatory)][object]$SonarConfig, [Parameter(Mandatory)][string]$Id)
  $artifact = @((Get-SonarExternalProperty $SonarConfig 'toolchain').artifacts | Where-Object { ([string]$_.id) -eq $Id } | Select-Object -First 1)
  if ($artifact.Count -ne 1) { throw 'sonar_toolchain_artifact_missing' }
  return $artifact[0]
}

function Get-SonarExternalImportPlan {
  param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][object]$SonarConfig, [Parameter(Mandatory)][string]$HostUrl)
  $toolchain = Test-SonarExternalToolchain -RepoRoot $RepoRoot -SonarConfig $SonarConfig
  $import = Get-SonarExternalProperty $SonarConfig 'external_import'
  $projectKey = [string](Get-SonarExternalProperty $import 'project_key')
  $projectName = [string](Get-SonarExternalProperty $import 'project_name')
  if ($projectKey -notmatch '^[A-Za-z0-9_.:-]{1,400}$' -or [string]::IsNullOrWhiteSpace($projectName)) { throw 'sonar_external_import_config_invalid' }
  if ($HostUrl -notmatch '^https?://[^/]+(?:/[^?#]+)?$') { throw 'sonar_external_host_invalid' }
  $java = Get-SonarExternalToolchainArtifact -SonarConfig $SonarConfig -Id 'java-runtime'
  $scanner = Get-SonarExternalToolchainArtifact -SonarConfig $SonarConfig -Id 'sonar-scanner-cli'
  $javaPath = Test-SonarExternalFileHash -Root $toolchain.artifact_root -RelativePath ([string]$java.relative_path) -ExpectedHash ([string]$java.sha256)
  $jarPath = Test-SonarExternalFileHash -Root $toolchain.artifact_root -RelativePath ([string](Get-SonarExternalProperty $scanner 'scanner_jar_relative_path')) -ExpectedHash ([string](Get-SonarExternalProperty $scanner 'scanner_jar_sha256'))
  $scannerHome = Split-Path -Parent (Split-Path -Parent $jarPath)
  return [pscustomobject]@{ project_key=$projectKey; project_name=$projectName; host_url=$HostUrl.TrimEnd('/'); java_path=$javaPath; scanner_jar_path=$jarPath; scanner_home=$scannerHome; timeout_sec=[int](Get-SonarExternalProperty $import 'timeout_sec' 120); analysis_scope=[string](Get-SonarExternalProperty $import 'analysis_scope') }
}

function Get-SonarExternalImportScannerArguments {
  param([Parameter(Mandatory)][object]$Plan, [Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$ReportPath, [Parameter(Mandatory)][string]$WorkDirectory)
  $relativeReport = Get-SonarExternalRelativePath -Root $RepoRoot -Path $ReportPath
  if (-not $relativeReport.StartsWith('logs/sonar/', [StringComparison]::OrdinalIgnoreCase)) { throw 'sonar_external_report_path_invalid' }
  $workPath = Resolve-SonarExternalContainedPath -Root $RepoRoot -RelativePath (Get-SonarExternalRelativePath -Root $RepoRoot -Path $WorkDirectory)
  $properties = @(
    ('scanner.home=' + $Plan.scanner_home),
    ('project.home=' + $RepoRoot),
    ('sonar.host.url=' + $Plan.host_url),
    ('sonar.projectKey=' + $Plan.project_key),
    ('sonar.projectName=' + $Plan.project_name),
    'sonar.sources=.ci/bin,tools',
    'sonar.exclusions=**/data/**,**/logs/**,**/.git/**,**/tests/**,**/.ci/cache/**,**/.ci/tools/**',
    ('sonar.externalIssuesReportPaths=' + $relativeReport),
    ('sonar.working.directory=' + $workPath)
  )
  if (@($properties | Where-Object { $_ -match '["\r\n]' }).Count -gt 0) { throw 'sonar_external_scanner_argument_invalid' }
  return @(
    ('-Dscanner.home=' + $Plan.scanner_home),
    ('-Dproject.home=' + $RepoRoot),
    '-cp',
    $Plan.scanner_jar_path,
    'org.sonarsource.scanner.cli.Main'
  ) + @($properties | Select-Object -Skip 2 | ForEach-Object { '-D' + $_ })
}

function Read-SonarExternalReportTask {
  param([Parameter(Mandatory)][string]$WorkDirectory)
  $taskPath = Join-Path $WorkDirectory 'report-task.txt'
  if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) { throw 'sonar_external_task_missing' }
  $values = @{}
  foreach ($line in Get-Content -LiteralPath $taskPath) {
    if ($line -match '^([^=]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
  }
  $taskId = [string]$values['ceTaskId']
  if ($taskId -notmatch '^[A-Za-z0-9_-]+$') { throw 'sonar_external_task_invalid' }
  return [pscustomobject]@{ task_id=$taskId }
}

function Invoke-SonarExternalScanner {
  param([Parameter(Mandatory)][object]$Plan, [Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$ReportPath, [Parameter(Mandatory)][string]$WorkDirectory, [Parameter(Mandatory)][string]$Token)
  if ([string]::IsNullOrWhiteSpace($Token)) { throw 'sonar_token_missing' }
  New-Item -ItemType Directory -Force -Path $WorkDirectory | Out-Null
  $arguments = Get-SonarExternalImportScannerArguments -Plan $Plan -RepoRoot $RepoRoot -ReportPath $ReportPath -WorkDirectory $WorkDirectory
  $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $processInfo.FileName = $Plan.java_path
  $processInfo.WorkingDirectory = $RepoRoot
  $processInfo.UseShellExecute = $false
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.Environment['SONAR_TOKEN'] = $Token
  $processInfo.Environment['SONAR_USER_HOME'] = $WorkDirectory
  foreach ($argument in $arguments) { [void]$processInfo.ArgumentList.Add($argument) }
  $process = [System.Diagnostics.Process]::Start($processInfo)
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $null = $stdoutTask.GetAwaiter().GetResult()
  $null = $stderrTask.GetAwaiter().GetResult()
  if ($process.ExitCode -ne 0) { throw 'sonar_external_scanner_failed' }
  return Read-SonarExternalReportTask -WorkDirectory $WorkDirectory
}
