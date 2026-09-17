#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = Join-Path $root '.ci\bin\modules\ci-commands-main.ps1'
$source = Get-Content -Raw -LiteralPath $sourcePath
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw ('Syntaxfehler in ci-commands-main.ps1: ' + $errors[0].Message) }

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-ThrowsClass {
  param([string]$ExpectedClass, [scriptblock]$Action)
  try {
    & $Action
  } catch {
    Assert-True ($_.Exception.Message -match [regex]::Escape($ExpectedClass)) ('Erwartete Fehlerklasse fehlt: ' + $ExpectedClass + '; erhalten: ' + $_.Exception.Message)
    return
  }
  throw ('Erwartete Fehlerklasse wurde nicht geworfen: ' + $ExpectedClass)
}

function Import-FunctionFromAst {
  param([string]$Name)
  $match = $ast.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and $node.Name -eq $Name }, $true) | Select-Object -First 1
  if ($null -eq $match) { throw ('Fehlende Funktion: ' + $Name) }
  $definition = $match.Extent.Text -replace ('(?m)^function\s+' + [regex]::Escape($Name)), ('function script:' + $Name)
  Invoke-Expression $definition
}

function Get-Prop([object]$Object, [string]$Name, [object]$Default = $null) {
  if ($null -eq $Object) { return $Default }
  if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) { return $Object[$Name] }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) { return $property.Value }
  return $Default
}

Import-FunctionFromAst 'Get-SonarExternalImportFailureClass'
Import-FunctionFromAst 'Cmd-SonarExternalImport'
Import-FunctionFromAst 'Cmd-Sonar'

$script:RepoRoot = $root
$script:LogsRoot = Join-Path $root 'logs'
$script:Lifecycle = @{}
$script:Evidence = @()

function Ensure-CoreFolders {}
function Ensure-BootstrapFiles {}
function Get-ConfigPath { return (Join-Path $script:RepoRoot '.ci\ci.config.json') }
function Try-ReadJson([string]$Path) { return [pscustomobject]@{ sonar = [pscustomobject]@{ mode = (Get-Prop $script:Lifecycle 'mode' '') } } }
function TsId { return 'fixture' }
function NowIso { return '2026-09-17T15:00:00.000+02:00' }
function CI-Info([string]$Message) { $script:Lifecycle.info = $Message }
function Write-Json([string]$Path, [object]$Object) { $script:Evidence += $Object }
function Start-Sleep { param([int]$Seconds) }
function Get-SonarStatusSnapshot([string]$Url, [int]$Timeout) { return @{ ok = -not [bool](Get-Prop $script:Lifecycle 'status_failure' $false) } }
function Get-SonarStatusUrl { return 'http://fixture:9000/api/system/status' }
function Test-SonarAuthentication { return @{ ok = -not [bool](Get-Prop $script:Lifecycle 'auth_failure' $false); error_class = 'sonar_auth_invalid'; token_source = 'fixture' } }
function Get-SonarTokenCandidates { return @(@{ source = 'fixture'; token = 'fixture-token' }) }
function Get-SonarBaseUrl { return 'http://fixture:9000' }
function Get-SonarExternalImportPlan {
  if (Get-Prop $script:Lifecycle 'plan_failure' $null) { throw (Get-Prop $script:Lifecycle 'plan_failure') }
  return [pscustomobject]@{ project_key = 'fixture-project'; project_name = 'Fixture project'; timeout_sec = 0; analysis_scope = 'external-powershell-issues-only' }
}
function Invoke-SonarExternalIssuesReport {
  if (Get-Prop $script:Lifecycle 'report_failure' $null) { throw (Get-Prop $script:Lifecycle 'report_failure') }
  return [pscustomobject]@{ output_path = (Join-Path $script:LogsRoot 'sonar\fixture.json'); report_sha256 = 'A' * 64; issue_count = 3 }
}
function Invoke-SonarApiJson([string]$RelativeUrl) {
  if ([bool](Get-Prop $script:Lifecycle 'project_failure' $false) -and $RelativeUrl -match '/api/projects/search') { throw 'fixture project request failed' }
  if ($RelativeUrl -match '/api/projects/search') { return [pscustomobject]@{ components = @([pscustomobject]@{ key = 'fixture-project' }) } }
  $computeFailure = [string](Get-Prop $script:Lifecycle 'compute_failure' '')
  if ($computeFailure -eq 'api') { throw 'fixture task request failed' }
  if ($computeFailure -eq 'failed') { return [pscustomobject]@{ task = [pscustomobject]@{ status = 'FAILED'; analysisId = '' } } }
  if ($computeFailure -eq 'timeout') { return [pscustomobject]@{ task = [pscustomobject]@{ status = 'PENDING'; analysisId = '' } } }
  return [pscustomobject]@{ task = [pscustomobject]@{ status = 'SUCCESS'; analysisId = 'analysis-fixture' } }
}
function Invoke-SonarExternalScanner {
  if ([bool](Get-Prop $script:Lifecycle 'scanner_failure' $false)) { throw 'sonar_external_scanner_failed' }
  return [pscustomobject]@{ task_id = 'task-fixture' }
}
function Get-SonarCommitReference { return ('a' * 40) }

function Invoke-LifecycleFixture([hashtable]$State) {
  $script:Lifecycle = $State
  $script:Evidence = @()
  Cmd-SonarExternalImport -CommandName '.\ci.cmd sonar'
  return $script:Evidence[-1]
}

$success = Invoke-LifecycleFixture @{}
Assert-True ($success.cmd -eq '.\ci.cmd sonar') 'Der kanonische sonar-Command wird nicht als Evidence-Quelle protokolliert.'
Assert-True ($success.task_status -eq 'SUCCESS' -and $success.analysis_id -eq 'analysis-fixture') 'Erfolgsfall verliert Task- oder Analyse-ID.'
Assert-True ($success.report_issue_count -eq 3 -and $success.analysis_scope -eq 'external-powershell-issues-only') 'Erfolgsfall verliert Befundzähler oder Analyseumfang.'
Assert-True ($success.commit_reference -match '^[a-f]{40}$') 'Erfolgsfall verliert die Commitreferenz.'
Assert-True ($success.quality_gate_statement -eq 'not-applicable-for-external-issues') 'External-Issue-Lauf behauptet unzulässig ein Quality Gate.'

foreach ($case in @(
  @{ state = @{ status_failure = $true }; expected = 'sonar_server_unreachable' },
  @{ state = @{ auth_failure = $true }; expected = 'sonar_auth_invalid' },
  @{ state = @{ plan_failure = 'sonar_toolchain_artifact_missing' }; expected = 'sonar_toolchain_artifact_missing' },
  @{ state = @{ report_failure = 'sonar_external_report_empty' }; expected = 'sonar_external_report_empty' },
  @{ state = @{ project_failure = $true }; expected = 'sonar_external_project_access_failed' },
  @{ state = @{ scanner_failure = $true }; expected = 'sonar_external_scanner_failed' },
  @{ state = @{ compute_failure = 'failed' }; expected = 'sonar_external_compute_engine_failed' },
  @{ state = @{ compute_failure = 'timeout' }; expected = 'sonar_external_compute_engine_timeout' },
  @{ state = @{ compute_failure = 'api' }; expected = 'sonar_external_compute_engine_lookup_failed' }
)) {
  Assert-ThrowsClass -ExpectedClass $case.expected -Action {
    $script:Lifecycle = $case.state
    $script:Evidence = @()
    Cmd-SonarExternalImport -CommandName '.\ci.cmd sonar'
  }
  Assert-True ($script:Evidence[-1].error_class -eq $case.expected) ('Fehlerevidence enthält nicht die erwartete Klasse: ' + $case.expected)
}

[pscustomobject]@{
  status = 'ok'
  cases = @('success', 'server_unreachable', 'auth_invalid', 'toolchain_missing', 'report_invalid', 'project_access_failed', 'scanner_failed', 'compute_engine_failed', 'compute_engine_timeout', 'compute_engine_api_failed')
  secret_sanitized = $true
} | ConvertTo-Json -Depth 4
