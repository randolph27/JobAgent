#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'JobAgent.SchemaValidation.psm1') -Force

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$originalNpmCache = [Environment]::GetEnvironmentVariable('NPM_CONFIG_CACHE', 'Process')
$cliPath = Get-JobAgentAjvCliPath -RepositoryRoot $root
Assert-True -Condition ([IO.Path]::GetFullPath($cliPath).StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) -Message 'AJV-CLI liegt nicht im Projektverzeichnis.'
Assert-True -Condition ($cliPath -notmatch [regex]::Escape([Environment]::GetFolderPath('UserProfile'))) -Message 'AJV-CLI darf nicht aus dem Benutzerprofil geladen werden.'

$help = Invoke-JobAgentAjvCli -CliPath $cliPath -Arguments @('help') -RepositoryRoot $root
Assert-True -Condition ($help.exit -eq 0) -Message "Lokale AJV-CLI liefert Exit $($help.exit): $($help.output -join "`n")"
Assert-True -Condition ($help.cache_path -eq (Join-Path $root '.ci\cache\ajv-cli')) -Message 'AJV-CLI verwendet keinen projektlokalen Cachepfad.'
Assert-True -Condition (([string][Environment]::GetEnvironmentVariable('NPM_CONFIG_CACHE', 'Process')) -eq ([string]$originalNpmCache)) -Message 'NPM_CONFIG_CACHE wurde nicht wiederhergestellt.'

$missingRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-missing-ajv-' + [guid]::NewGuid().ToString('N'))
try {
    [IO.Directory]::CreateDirectory($missingRoot) | Out-Null
    $missingRejected = $false
    try { Get-JobAgentAjvCliPath -RepositoryRoot $missingRoot | Out-Null } catch { $missingRejected = $_.Exception.Message -match 'Lokale AJV-CLI fehlt' }
    Assert-True -Condition $missingRejected -Message 'Fehlende lokale AJV-CLI wird nicht fail-closed abgelehnt.'
}
finally {
    if (Test-Path -LiteralPath $missingRoot) { Remove-Item -LiteralPath $missingRoot -Recurse -Force }
}

[pscustomobject]@{
    status = 'ok'
    cases = @('project_local_cli', 'project_local_cache_environment', 'environment_restoration', 'missing_cli_fail_closed')
} | ConvertTo-Json -Depth 5
