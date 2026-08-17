$cmd = "./gradlew :server:run --console=plain"
$logOut = "logs/server/server.log"
$logErr = "logs/server/server.err.log"
if (!(Test-Path "logs/server")) { New-Item -ItemType Directory -Force logs/server | Out-Null }
if (!(Test-Path ".ci/run")) { New-Item -ItemType Directory -Force .ci/run | Out-Null }
$p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd -WorkingDirectory (Get-Location) -RedirectStandardOutput $logOut -RedirectStandardError $logErr -PassThru -WindowStyle Hidden
$json = @{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=(Get-Location).Path; port=8081; url="http://localhost:8081/" } | ConvertTo-Json -Compress
$json | Set-Content -NoNewline .ci/run/server.pid.json
Write-Host "Ktor-Server gestartet mit PID $($p.Id)"
