$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ciEntry = Join-Path $repoRoot 'ci.cmd'

if (!(Test-Path -LiteralPath $ciEntry)) {
    throw "Missing CI entrypoint: $ciEntry"
}

New-Item -ItemType Directory -Force (Join-Path $repoRoot 'logs\devserver') | Out-Null
$logPath = Join-Path $repoRoot 'logs\devserver\start-dev-bootstrap.log'
$cmd = 'cmd /d /c .\ci.cmd dev'

$process = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList '/d', '/c', ($cmd + ' >> "' + $logPath + '" 2>&1') `
    -WorkingDirectory $repoRoot `
    -PassThru `
    -WindowStyle Hidden

Write-Host ("Dev bootstrap started with PID {0}. CI devserver contract uses http://localhost:8200/." -f $process.Id)
