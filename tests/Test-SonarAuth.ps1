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
if ($errors.Count -gt 0) { throw ('Syntaxfehler in ci-commands-main.ps1: ' + ($errors[0].Message)) }

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
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

foreach ($name in @('Get-SonarBaseUrl', 'ConvertTo-SonarNormalizedToken', 'New-SonarApiHeadersFromToken', 'Test-SonarAuthentication')) {
  Import-FunctionFromAst $name
}

$plain = ConvertTo-SonarNormalizedToken "plain-token"
Assert-True ([bool]$plain.ok) 'Reiner Tokenwert wurde nicht akzeptiert.'
Assert-True ($plain.format -eq 'plain') 'Reiner Tokenwert erhielt falsche Formatklasse.'
Assert-True ($plain.token -eq 'plain-token') 'Reiner Tokenwert wurde veraendert.'

$marked = ConvertTo-SonarNormalizedToken "Hinweis`r`nToken: 'marked-token'`r`n"
Assert-True ([bool]$marked.ok) 'Markierter Tokenwert wurde nicht akzeptiert.'
Assert-True ($marked.format -eq 'marked') 'Markierter Tokenwert erhielt falsche Formatklasse.'
Assert-True ($marked.token -eq 'marked-token') 'Markierter Tokenwert wurde nicht normalisiert.'

$invalid = ConvertTo-SonarNormalizedToken "SONAR_TOKEN=first`nSONAR_TOKEN=second"
Assert-True (-not [bool]$invalid.ok) 'Mehrdeutiges Tokenformat wurde akzeptiert.'
Assert-True ($invalid.error_class -eq 'sonar_token_format_invalid') 'Mehrdeutiges Tokenformat erhielt falsche Fehlerklasse.'

$candidate = @{ source='fixture'; token='fixture-token'; token_format='plain' }
$valid = Test-SonarAuthentication -TokenCandidates @($candidate) -Request { param($endpoint, $headers, $timeout) [pscustomobject]@{ valid=$true } }
Assert-True ([bool]$valid.ok) 'Gueltige Authentifizierungsantwort wurde nicht akzeptiert.'
Assert-True ($valid.status_code -eq 200) 'Gueltige Authentifizierungsantwort erhielt keinen HTTP-200-Status.'
Assert-True ($valid.token_source -eq 'fixture') 'Tokenquelle wurde nicht sekretfrei klassifiziert.'

$invalidAuth = Test-SonarAuthentication -TokenCandidates @($candidate) -Request { param($endpoint, $headers, $timeout) [pscustomobject]@{ valid=$false } }
Assert-True (-not [bool]$invalidAuth.ok) 'Ungueltige Authentifizierungsantwort wurde akzeptiert.'
Assert-True ($invalidAuth.error_class -eq 'sonar_auth_invalid') 'Ungueltige Authentifizierungsantwort erhielt falsche Fehlerklasse.'

[pscustomobject]@{ status='ok'; cases=@('plain_token', 'marked_token', 'ambiguous_token_rejected', 'valid_auth_response', 'invalid_auth_response') } | ConvertTo-Json -Depth 3
