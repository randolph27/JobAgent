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
Import-FunctionFromAst 'Get-SonarComputeEngineReadFailureClass'
Import-FunctionFromAst 'Invoke-SonarComputeEngineTaskRead'
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
function To-RelPath([string]$Path) { return $Path }
function CI-Info([string]$Message) { $script:Lifecycle.info = $Message }
function Write-Json([string]$Path, [object]$Object) { if ($Path -match 'verify\.digest\.json$') { $script:Lifecycle.verify_digest = $Object; return }; $script:Evidence += $Object }
function Start-Sleep { param([int]$Seconds) }
function Get-SonarStatusSnapshot([string]$Url, [int]$Timeout) { return @{ ok = -not [bool](Get-Prop $script:Lifecycle 'status_failure' $false) } }
function Get-SonarStatusUrl { return 'http://fixture:9000/api/system/status' }
function Test-SonarAuthentication { return @{ ok = -not [bool](Get-Prop $script:Lifecycle 'auth_failure' $false); error_class = 'sonar_auth_invalid'; token_source = 'fixture' } }
function Get-SonarTokenCandidates { return @(@{ source = 'fixture'; token = 'fixture-token' }) }
function Get-SonarBaseUrl { return 'http://fixture:9000' }
function Get-SonarApiHeaders { return @{ Authorization = 'Basic fixture' } }
function Get-SonarHttpStatusCodeFromError([object]$ErrorRecord) { return (Get-Prop $script:Lifecycle 'direct_status_code' $null) }
function Test-SonarTimeoutError([object]$ErrorRecord) { return [bool](Get-Prop $script:Lifecycle 'direct_timeout' $false) }
function Invoke-RestMethod { param($Headers, $Uri, $TimeoutSec) if ([bool](Get-Prop $script:Lifecycle 'direct_request_failure' $false)) { throw 'fixture request failure' }; return (Get-Prop $script:Lifecycle 'direct_response' ([pscustomobject]@{ task = [pscustomobject]@{ status = 'SUCCESS'; analysisId = 'analysis-fixture' } })) }

foreach ($case in @(
  @{ state = @{ direct_request_failure = $true; direct_status_code = 401 }; expected = 'sonar_external_compute_engine_unauthorized' },
  @{ state = @{ direct_request_failure = $true; direct_status_code = 403 }; expected = 'sonar_external_compute_engine_forbidden' },
  @{ state = @{ direct_request_failure = $true; direct_status_code = 404 }; expected = 'sonar_external_compute_engine_task_not_found' },
  @{ state = @{ direct_request_failure = $true; direct_status_code = 503 }; expected = 'sonar_external_compute_engine_server_error' },
  @{ state = @{ direct_request_failure = $true; direct_timeout = $true }; expected = 'sonar_external_compute_engine_transport_timeout' },
  @{ state = @{ direct_request_failure = $true }; expected = 'sonar_external_compute_engine_transport_failed' }
)) {
  $script:Lifecycle = $case.state
  $read = Invoke-SonarComputeEngineTaskRead -TaskId 'task-fixture' -TimeoutSec 1
  Assert-True (-not $read.ok -and $read.error_class -eq $case.expected) ('Compute-Engine-Read klassifiziert die API-Grenze nicht: ' + $case.expected)
  Assert-True ($read.endpoint_class -eq 'sonar-api-ce-task' -and -not ($read.PSObject.Properties.Name -match 'token|header|url')) 'Compute-Engine-Read gibt geheime oder queryhaltige Diagnosefelder aus.'
}

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
  return [pscustomobject]@{ components = @([pscustomobject]@{ key = 'fixture-project' }) }
}
function Invoke-SonarComputeEngineTaskRead([string]$TaskId, [int]$TimeoutSec) {
  $computeFailure = [string](Get-Prop $script:Lifecycle 'compute_failure' '')
  $base = [ordered]@{ ok=$true; endpoint_class='sonar-api-ce-task'; http_status=200; transport_class=$null; task_status=$null; task=$null; error_class='ok' }
  if ($computeFailure -eq 'api401') { $base.ok=$false; $base.http_status=401; $base.error_class='sonar_external_compute_engine_unauthorized'; return $base }
  if ($computeFailure -eq 'api403') { $base.ok=$false; $base.http_status=403; $base.error_class='sonar_external_compute_engine_forbidden'; return $base }
  if ($computeFailure -eq 'api404') { $base.ok=$false; $base.http_status=404; $base.error_class='sonar_external_compute_engine_task_not_found'; return $base }
  if ($computeFailure -eq 'api5xx') { $base.ok=$false; $base.http_status=503; $base.error_class='sonar_external_compute_engine_server_error'; return $base }
  if ($computeFailure -eq 'transport_timeout') { $base.ok=$false; $base.http_status=$null; $base.transport_class='timeout'; $base.error_class='sonar_external_compute_engine_transport_timeout'; return $base }
  if ($computeFailure -eq 'transport') { $base.ok=$false; $base.http_status=$null; $base.transport_class='request-failed'; $base.error_class='sonar_external_compute_engine_transport_failed'; return $base }
  if ($computeFailure -eq 'missing_task') { return $base }
  if ($computeFailure -eq 'invalid_status') { $base.task=[pscustomobject]@{ status='UNKNOWN'; analysisId='' }; return $base }
  if ($computeFailure -eq 'failed') { $base.task=[pscustomobject]@{ status='FAILED'; analysisId='' }; return $base }
  if ($computeFailure -eq 'canceled') { $base.task=[pscustomobject]@{ status='CANCELED'; analysisId='' }; return $base }
  if ($computeFailure -eq 'timeout') { $base.task=[pscustomobject]@{ status='PENDING'; analysisId='' }; return $base }
  if ($computeFailure -eq 'analysis_id_invalid') { $base.task=[pscustomobject]@{ status='SUCCESS'; analysisId='' }; return $base }
  $base.task=[pscustomobject]@{ status='SUCCESS'; analysisId='analysis-fixture' }
  return $base
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
Assert-True ($script:Lifecycle.verify_digest.status -eq 'ok' -and $script:Lifecycle.verify_digest.analysis_id -eq 'analysis-fixture') 'Verify-Digest verliert die bestätigte Analyse-ID.'

foreach ($case in @(
  @{ state = @{ status_failure = $true }; expected = 'sonar_server_unreachable' },
  @{ state = @{ auth_failure = $true }; expected = 'sonar_auth_invalid' },
  @{ state = @{ plan_failure = 'sonar_toolchain_artifact_missing' }; expected = 'sonar_toolchain_artifact_missing' },
  @{ state = @{ report_failure = 'sonar_external_report_empty' }; expected = 'sonar_external_report_empty' },
  @{ state = @{ project_failure = $true }; expected = 'sonar_external_project_access_failed' },
  @{ state = @{ scanner_failure = $true }; expected = 'sonar_external_scanner_failed' },
  @{ state = @{ compute_failure = 'failed' }; expected = 'sonar_external_compute_engine_failed' },
  @{ state = @{ compute_failure = 'canceled' }; expected = 'sonar_external_compute_engine_canceled' },
  @{ state = @{ compute_failure = 'timeout' }; expected = 'sonar_external_compute_engine_timeout' },
  @{ state = @{ compute_failure = 'api401' }; expected = 'sonar_external_compute_engine_unauthorized' },
  @{ state = @{ compute_failure = 'api403' }; expected = 'sonar_external_compute_engine_forbidden' },
  @{ state = @{ compute_failure = 'api404' }; expected = 'sonar_external_compute_engine_task_not_found' },
  @{ state = @{ compute_failure = 'api5xx' }; expected = 'sonar_external_compute_engine_server_error' },
  @{ state = @{ compute_failure = 'transport_timeout' }; expected = 'sonar_external_compute_engine_transport_timeout' },
  @{ state = @{ compute_failure = 'transport' }; expected = 'sonar_external_compute_engine_transport_failed' },
  @{ state = @{ compute_failure = 'missing_task' }; expected = 'sonar_external_compute_engine_response_invalid' },
  @{ state = @{ compute_failure = 'invalid_status' }; expected = 'sonar_external_compute_engine_response_invalid' },
  @{ state = @{ compute_failure = 'analysis_id_invalid' }; expected = 'sonar_external_compute_engine_analysis_id_invalid' }
)) {
  Assert-ThrowsClass -ExpectedClass $case.expected -Action {
    $script:Lifecycle = $case.state
    $script:Evidence = @()
    Cmd-SonarExternalImport -CommandName '.\ci.cmd sonar'
  }
  Assert-True ($script:Evidence[-1].error_class -eq $case.expected) ('Fehlerevidence enthält nicht die erwartete Klasse: ' + $case.expected)
  Assert-True ($script:Lifecycle.verify_digest.status -eq 'failed' -and $script:Lifecycle.verify_digest.error_class -eq $case.expected) 'Verify-Digest verliert die Fehlerklasse.'
  if ($case.expected -match '^sonar_external_compute_engine_') {
    Assert-True ($script:Evidence[-1].stage -eq 'compute_engine' -and $script:Evidence[-1].compute_engine_endpoint_class -eq 'sonar-api-ce-task') 'Compute-Engine-Fehlerevidence verliert Stage oder Endpointklasse.'
    Assert-True (-not ($script:Evidence[-1].PSObject.Properties.Name -match 'token|header|url')) 'Compute-Engine-Fehlerevidence enthält geheime oder queryhaltige Felder.'
  }
}

[pscustomobject]@{
  status = 'ok'
  cases = @('success', 'server_unreachable', 'auth_invalid', 'toolchain_missing', 'report_invalid', 'project_access_failed', 'scanner_failed', 'compute_engine_failed', 'compute_engine_canceled', 'compute_engine_timeout', 'compute_engine_http', 'compute_engine_transport', 'compute_engine_response', 'compute_engine_analysis_id')
  secret_sanitized = $true
} | ConvertTo-Json -Depth 4
