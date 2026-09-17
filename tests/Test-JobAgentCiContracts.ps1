#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$config = Get-Content -LiteralPath (Join-Path $root '.ci\ci.config.json') -Raw | ConvertFrom-Json
$browserLogic = Get-Content -LiteralPath (Join-Path $root '.ci\bin\modules\browser-logic.ps1') -Raw
$commands = Get-Content -LiteralPath (Join-Path $root '.ci\bin\modules\ci-commands-main.ps1') -Raw
$ciRuntime = Get-Content -LiteralPath (Join-Path $root '.ci\bin\ci.ps1') -Raw
$dailyRunScript = Get-Content -LiteralPath (Join-Path $root 'tools\Invoke-JobAgentDailyRun.ps1') -Raw

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True ($browserLogic -match 'function Get-ProcessIdentity') 'Devserver-Prozessidentitaet fehlt.'
Assert-True ($browserLogic -match 'if \(\$managed\) \{ "managed" \} else \{ "external" \}') 'Devserver-Start unterscheidet verwaltete und fremde Listener nicht.'
Assert-True ($browserLogic -match 'devserver-" \+ \(TsId\) \+ "\.log') 'Devserver verwendet kein datiertes, konfliktfreies Log.'
Assert-True ($browserLogic -notmatch 'devserver-stop: killing port') 'Devserver-Stop darf keinen beliebigen Prozess auf dem Port beenden.'
Assert-True ($browserLogic -match 'netstat -ano -p tcp' -and $browserLogic.Contains('ABH\S*REN')) 'Devserver-Listenererkennung braucht einen netstat-Fallback fuer eingeschraenkte Get-NetTCPConnection-Umgebungen.'
Assert-True ($config.verify.shell -eq 'powershell') 'Verify muss den PowerShell-Funktionstest explizit ausfuehren.'
Assert-True ($config.verify.cmd -match 'Test-JobAgentCiContracts\.ps1$') 'Verify verweist nicht auf den CI-Vertragstest.'
Assert-True ($config.sonar.mode -eq 'not-supported') 'Nicht konfigurierte Sonar-Analyse muss explizit als nicht unterstuetzt markiert sein.'
Assert-True (@($config.immutable_policy.mutable_paths) -contains 'Roadmap.md') 'Roadmap.md ist nicht als autorisierte mutable Planungsdatei gebunden.'
Assert-True ($commands -match 'status="not-supported"') 'Sonar-Nichtunterstuetzung wird nicht als eigener Status protokolliert.'
Assert-True ($commands -match 'analysis_started=\$false') 'Sonar-Nichtunterstuetzung muss einen nicht gestarteten Analysepfad ausweisen.'
Assert-True ($config.sonar.auth.token_file -eq 'D:\_Scripte\_Sonar\token.txt') 'Sonar-Tokenquelle ist nicht explizit konfiguriert.'
Assert-True ($config.sonar.toolchain.status -eq 'verified') 'Die beschaffte Sonar-Lieferkette muss verifiziert bleiben.'
Assert-True ($config.sonar.toolchain.analysis_scope -eq 'external-powershell-issues-only') 'Der Sonar-Analyseumfang ist nicht auf externe PowerShell-Befunde begrenzt.'
$sonarToolchainTest = Join-Path $PSScriptRoot 'Test-SonarToolchain.ps1'
Assert-True (Test-Path -LiteralPath $sonarToolchainTest) 'Sonar-Lieferkettenfunktionstest fehlt.'
Assert-True (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Test-SonarExternalIssues.ps1')) 'Sonar-External-Issues-Funktionstest fehlt.'
Assert-True ($commands -match 'function ConvertTo-SonarNormalizedToken') 'Sonar-Token-Normalisierung fehlt.'
Assert-True ($commands -match 'function Cmd-SonarAuth') 'Sekretfreier Sonar-Authentifizierungscommand fehlt.'
Assert-True ($commands -match 'Register-CiCommand "sonar-auth"') 'Sonar-Authentifizierungscommand ist nicht registriert.'
Assert-True ($commands -match 'function Cmd-SonarExternalImport') 'Sonar-External-Importcommand fehlt.'
Assert-True ($commands -match 'Register-CiCommand "sonar-external-import"') 'Sonar-External-Importcommand ist nicht registriert.'
Assert-True ($config.sonar.external_import.project_key -eq 'jobagent-external-powershell') 'Der External-Import-Projekt-Key fehlt.'
$sonarAuthTest = Join-Path $PSScriptRoot 'Test-SonarAuth.ps1'
Assert-True (Test-Path -LiteralPath $sonarAuthTest) 'Sonar-Authentifizierungsfunktionstest fehlt.'
Assert-True ([int]$config.jobagent.daily_run.live_pilot_max_companies -eq 1000) 'Der reguläre Live-Lauf muss bis zu 1000 Firmen und damit den aktuellen Gesamtbestand verarbeiten können.'
Assert-True ($dailyRunScript -match '\[Parameter\(\)\]\[ValidateRange\(1, 1000\)\]\[int\]\$MaxCompanies\s*=\s*1000') 'Der reguläre Daily-Run-Default muss dem Live-Limit von 1000 entsprechen.'
Assert-True ($dailyRunScript -match '\[Parameter\(\)\]\[switch\]\$FullScan') 'Der Daily-Run muss einen expliziten Vollscanmodus ohne lange Befehlszeile bereitstellen.'
Assert-True ($dailyRunScript -match 'Read-JobAgentStore -ProjectRoot \$ProjectRoot -DataRoot \$DataRoot') 'Der Vollscan muss die Firmenliste intern aus dem aktuellen Store ableiten.'
Assert-True ($ciRuntime -match '& \$script:CiCommands\[\$cmdKey\] @Args') 'Der CI-Entrypoint muss verbleibende Daily-Run-Argumente an den registrierten Command weiterreichen.'

$ci005Test = Join-Path $PSScriptRoot 'Test-Ci005Invariants.ps1'
Assert-True (Test-Path -LiteralPath $ci005Test) 'CI-005-Invariantentest fehlt.'
& $ci005Test | Out-Null

[pscustomobject]@{
    status = 'ok'
    cases = @('powershell_verify_lane', 'explicit_sonar_not_supported', 'sonar_auth_contract', 'sonar_external_import_contract', 'sonar_toolchain_verified_contract', 'sonar_external_issues_test_contract', 'live_daily_run_limit_1000', 'mutable_roadmap_policy', 'devserver_listener_identity', 'external_listener_protection', 'unique_devserver_logs', 'devserver_netstat_listener_fallback', 'ci005_immutable_and_handoff_invariants')
} | ConvertTo-Json -Depth 4
