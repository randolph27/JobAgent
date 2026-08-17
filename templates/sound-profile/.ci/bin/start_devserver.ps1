# Guard: falls PID-Datei existiert oder Port 8200 belegt ist → stop
if (Test-Path .ci/run/devserver.pid.json) {
    try {
        $j = Get-Content -Raw .ci/run/devserver.pid.json | ConvertFrom-Json;
        Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
    } catch {} ;
    Remove-Item .ci/run/devserver.pid.json -ErrorAction SilentlyContinue
}
$pidExisting = (Get-NetTCPConnection -LocalPort 8200 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
if ($pidExisting) {
    Stop-Process -Id $pidExisting -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force .ci/run, logs/devserver | Out-Null
$cmd_str = "npm run dev"
$log = "logs/devserver/devserver.log"
# Rotate/clear log before fresh start to avoid stale errors
if (Test-Path $log) {
    $size = (Get-Item $log).Length
    if ($size -gt 0) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Move-Item $log ("logs/devserver/devserver-$stamp.log")
    }
}
New-Item -ItemType File -Force -Path $log | Out-Null
$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$cmd_str >> $log 2>&1" -WorkingDirectory (Get-Location) -PassThru -WindowStyle Hidden
$pid_val = $p.Id
$cwd_val = (Get-Location).Path
$json_content = '{ "ts":"' + (Get-Date).ToString("o") + '", "pid":' + $pid_val + ', "cmd":"' + $cmd_str + '", "cwd":"' + $cwd_val + '", "port":8200, "url":"http://localhost:8200/" }'
Set-Content -NoNewline -Path .ci/run/devserver.pid.json -Value $json_content

