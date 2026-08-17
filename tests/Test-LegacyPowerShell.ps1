[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profileIds = @('ubuntu-web', 'chess', 'sound-profile')

try {
    $parsedCount = 0
    foreach ($profileId in $profileIds) {
        $runtimeRoot = Join-Path $bootstrapRoot (Join-Path 'profiles' (Join-Path $profileId 'runtime\bin'))
        foreach ($file in @(Get-ChildItem -LiteralPath $runtimeRoot -Recurse -Filter '*.ps1' -File)) {
            $tokens = $null
            $parseErrors = $null
            [Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            ) | Out-Null
            if (@($parseErrors).Count -gt 0) {
                $messages = @($parseErrors | ForEach-Object { $_.Message }) -join ' | '
                throw "PowerShell-5.1-Parsefehler in $($file.FullName): $messages"
            }
            $parsedCount++
        }
    }

    if (-not $Quiet) {
        [pscustomobject]@{
            status = 'ok'
            engine = [string]$PSVersionTable.PSVersion
            profiles = $profileIds.Count
            powershell_files = $parsedCount
        } | ConvertTo-Json -Depth 4
    }
}
catch {
    [Console]::Error.WriteLine("[LEGACY-POWERSHELL] $($_.Exception.Message)")
    exit 1
}
