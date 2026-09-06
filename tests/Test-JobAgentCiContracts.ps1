#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$config = Get-Content -LiteralPath (Join-Path $root '.ci\ci.config.json') -Raw | ConvertFrom-Json
$browserLogic = Get-Content -LiteralPath (Join-Path $root '.ci\bin\modules\browser-logic.ps1') -Raw
$commands = Get-Content -LiteralPath (Join-Path $root '.ci\bin\modules\ci-commands-main.ps1') -Raw

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True ($browserLogic -match 'function Get-ProcessIdentity') 'Devserver-Prozessidentitaet fehlt.'
Assert-True ($browserLogic -match 'if \(\$managed\) \{ "managed" \} else \{ "external" \}') 'Devserver-Start unterscheidet verwaltete und fremde Listener nicht.'
Assert-True ($browserLogic -match 'devserver-" \+ \(TsId\) \+ "\.log') 'Devserver verwendet kein datiertes, konfliktfreies Log.'
Assert-True ($browserLogic -notmatch 'devserver-stop: killing port') 'Devserver-Stop darf keinen beliebigen Prozess auf dem Port beenden.'
Assert-True ($config.verify.shell -eq 'powershell') 'Verify muss den PowerShell-Funktionstest explizit ausfuehren.'
Assert-True ($config.verify.cmd -match 'Test-JobAgentCiContracts\.ps1$') 'Verify verweist nicht auf den CI-Vertragstest.'
Assert-True ($config.sonar.mode -eq 'not-supported') 'Nicht konfigurierte Sonar-Analyse muss explizit als nicht unterstuetzt markiert sein.'
Assert-True (@($config.immutable_policy.mutable_paths) -contains 'Roadmap.md') 'Roadmap.md ist nicht als autorisierte mutable Planungsdatei gebunden.'
Assert-True ($commands -match 'status="not-supported"') 'Sonar-Nichtunterstuetzung wird nicht als eigener Status protokolliert.'
Assert-True ($commands -match 'analysis_started=\$false') 'Sonar-Nichtunterstuetzung muss einen nicht gestarteten Analysepfad ausweisen.'

[pscustomobject]@{
    status = 'ok'
    cases = @('powershell_verify_lane', 'explicit_sonar_not_supported', 'mutable_roadmap_policy', 'devserver_listener_identity', 'external_listener_protection', 'unique_devserver_logs')
} | ConvertTo-Json -Depth 4
