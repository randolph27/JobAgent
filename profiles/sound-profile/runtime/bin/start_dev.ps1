$logDir = "logs/devserver"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir }
$runDir = ".ci/run"
if (!(Test-Path $runDir)) { New-Item -ItemType Directory -Force $runDir }

$cmd = "npm run dev"
$log = "logs/devserver/devserver.log"

$p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command","$cmd *>> $log" -WorkingDirectory (Get-Location) -PassThru -WindowStyle Hidden

$json = @{
    ts = (Get-Date).ToString("o")
    pid = $p.Id
    cmd = $cmd
    cwd = (Get-Location).Path
    port = 8200
    url = "http://localhost:8200/"
} | ConvertTo-Json -Compress

$json | Set-Content -NoNewline .ci/run/devserver.pid.json
Write-Host "Dev server started with PID $($p.Id)"

