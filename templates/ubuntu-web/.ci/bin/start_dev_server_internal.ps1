$cmd = "npm run dev"
$log = "logs/devserver/devserver.log"
New-Item -ItemType Directory -Force .ci/run, logs/devserver | Out-Null
$p = Start-Process powershell -ArgumentList "-NoProfile -NonInteractive -Command $cmd" -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "logs/devserver/devserver.err.log"
$data = @{ 
    ts = (Get-Date).ToString("o")
    pid = $p.Id
    cmd = $cmd
    cwd = (Get-Location).Path
    port = 8090
    url = "http://localhost:8090/"
} | ConvertTo-Json -Compress
Set-Content -Path .ci/run/devserver.pid.json -Value $data -NoNewline
Write-Output "Dev server started with PID $($p.Id)"
