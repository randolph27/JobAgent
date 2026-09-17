#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $root '.ci\bin\modules\sonar-external-issues.ps1')
$config = Get-Content -LiteralPath (Join-Path $root '.ci\ci.config.json') -Raw | ConvertFrom-Json
$fixturePath = Join-Path $root '.ci\bin\modules\sonar-external-issues.ps1'
$outputPath = Join-Path $root 'logs\sonar\test-sq007-generic-report.json'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-Rejected {
  param([scriptblock]$Action, [string]$ExpectedError)
  try { & $Action } catch {
    Assert-True ($_.Exception.Message -eq $ExpectedError) ("Falsche Fehlerklasse: " + $_.Exception.Message)
    return
  }
  throw ("Erwartete Fehlerklasse fehlt: " + $ExpectedError)
}

$toolchain = Test-SonarExternalToolchain -RepoRoot $root -SonarConfig $config.sonar
Assert-True ($toolchain.status -eq 'verified') 'Die lokale Sonar-Lieferkette ist nicht verifiziert.'
$plan = Get-SonarExternalImportPlan -RepoRoot $root -SonarConfig $config.sonar -HostUrl 'http://127.0.0.1:9000'
Assert-True ($plan.project_key -eq 'jobagent-external-powershell') 'Der External-Import besitzt keinen stabilen Projekt-Key.'
Assert-True (Test-Path -LiteralPath $plan.scanner_jar_path -PathType Leaf) 'Der Scanner-JAR fehlt.'
$sourceFiles = Get-SonarExternalSourceFiles -RepoRoot $root
Assert-True ($sourceFiles.Count -gt 0) 'Der versionierte PowerShell-Quellsatz ist leer.'
Assert-True (@($sourceFiles.FullName | Where-Object { $_ -like '*\.ci\bin\*' }).Count -gt 0) 'CI-PowerShell-Quellen fehlen im Include-Satz.'
Assert-True (@($sourceFiles.FullName | Where-Object { $_ -like '*\tests\*' }).Count -eq 0) 'Testquellen duerfen nicht in den Analyseumfang gelangen.'

$record = [pscustomobject]@{
  RuleName = 'PSAvoidUsingWriteHost'
  Severity = 'Warning'
  Message = 'Write-Host vermeiden.'
  ScriptPath = $fixturePath
  Line = 1
  EndLine = 1
}
$result = ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @($record, $record) -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath
Assert-True ($result.issue_count -eq 1) 'Doppelte External Issues wurden nicht deterministisch entfernt.'
$bytes = [IO.File]::ReadAllBytes($outputPath)
Assert-True (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191)) 'Generic-Issue-Report darf kein UTF-8-BOM enthalten.'
$report = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
Assert-True ($report.issues.Count -eq 1) 'Generic-Issue-Report hat eine falsche Befundanzahl.'
Assert-True ($report.issues[0].primaryLocation.filePath -eq '.ci/bin/modules/sonar-external-issues.ps1') 'Generic-Issue-Pfad ist nicht projektrelativ.'
$analysisOutputPath = Join-Path $root 'logs\sonar\test-sq007-local-analysis.json'
$analysisResult = Invoke-SonarExternalIssuesReport -RepoRoot $root -SonarConfig $config.sonar -OutputPath $analysisOutputPath
Assert-True ($analysisResult.issue_count -ge 0) 'Der lokale PSScriptAnalyzer-Lauf lieferte keinen Befundzaehler.'
Assert-True (Test-Path -LiteralPath $analysisResult.output_path -PathType Leaf) 'Der lokale Generic-Issue-Report fehlt.'
$workDirectory = Join-Path $root 'logs\sonar\test-sq007-work'
$scannerArgs = Get-SonarExternalImportScannerArguments -Plan $plan -RepoRoot $root -ReportPath $analysisResult.output_path -WorkDirectory $workDirectory
Assert-True ($scannerArgs -contains '-Dsonar.sources=.ci/bin,tools') 'Der Scanner begrenzt seinen Source-Satz nicht.'
Assert-True (@($scannerArgs | Where-Object { $_ -match 'sonar\.token|sonar\.login' }).Count -eq 0) 'Der Scanner darf kein Secretargument erhalten.'
$brokenPlan = $plan.PSObject.Copy()
$brokenPlan.scanner_jar_path = Join-Path $root 'tests\missing-sonar-scanner.jar'
Assert-Rejected -ExpectedError 'sonar_external_scanner_failed' -Action { Invoke-SonarExternalScanner -Plan $brokenPlan -RepoRoot $root -ReportPath $analysisResult.output_path -WorkDirectory $workDirectory -Token 'fixture-token' | Out-Null }

Assert-Rejected -ExpectedError 'sonar_external_report_empty' -Action { ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @() -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath | Out-Null }
$unknown = $record.PSObject.Copy(); $unknown.RuleName = 'UnknownRule'
Assert-Rejected -ExpectedError 'sonar_external_rule_unknown' -Action { ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @($unknown) -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath | Out-Null }
$outside = $record.PSObject.Copy(); $outside.ScriptPath = [IO.Path]::GetTempPath()
Assert-Rejected -ExpectedError 'sonar_external_path_outside_root' -Action { ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @($outside) -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath | Out-Null }
$excluded = $record.PSObject.Copy(); $excluded.ScriptPath = Join-Path $root 'logs\sonar\test-sq007-generic-report.json'
Assert-Rejected -ExpectedError 'sonar_external_path_not_scannable' -Action { ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @($excluded) -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath | Out-Null }
$invalidLine = $record.PSObject.Copy(); $invalidLine.Line = 0
Assert-Rejected -ExpectedError 'sonar_external_line_invalid' -Action { ConvertTo-SonarGenericExternalIssueReport -RepoRoot $root -Records @($invalidLine) -KnownRules @('PSAvoidUsingWriteHost') -OutputPath $outputPath | Out-Null }

[pscustomobject]@{
  status = 'ok'
  cases = @('verified_toolchain', 'external_import_plan', 'secret_free_scanner_arguments', 'scanner_failure_rejected', 'versioned_source_scope', 'utf8_generic_issue_report', 'deduplicated_issues', 'local_psscriptanalyzer_run', 'empty_report_rejected', 'unknown_rule_rejected', 'outside_path_rejected', 'excluded_path_rejected', 'invalid_line_rejected')
  secret_sanitized = $true
} | ConvertTo-Json -Depth 4
