$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ciEntry = Join-Path $repoRoot 'ci.cmd'

if (!(Test-Path -LiteralPath $ciEntry)) {
    throw "Missing CI entrypoint: $ciEntry"
}

New-Item -ItemType Directory -Force (Join-Path $repoRoot '.ci\run') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $repoRoot 'logs\devserver') | Out-Null

$logPath = Join-Path $repoRoot 'logs\devserver\start-devserver-bootstrap.log'
$cmd = 'cmd /d /c .\ci.cmd dev'
$process = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList '/d', '/c', ($cmd + ' >> "' + $logPath + '" 2>&1') `
    -WorkingDirectory $repoRoot `
    -PassThru `
    -WindowStyle Hidden

$snapshot = @{
    ts = (Get-Date).ToString('o')
    pid = $process.Id
    cmd = '.\\ci.cmd dev'
    cwd = $repoRoot
    port = 8200
    url = 'http://localhost:8200/'
    log = 'logs\\devserver\\start-devserver-bootstrap.log'
} | ConvertTo-Json -Compress

Set-Content -LiteralPath (Join-Path $repoRoot '.ci\run\devserver-bootstrap.pid.json') -Value $snapshot -NoNewline -Encoding UTF8
Write-Host ("Devserver bootstrap started with PID {0}; monitor .\\ci\\run\\devserver.pid.json for the detached runtime server." -f $process.Id)
