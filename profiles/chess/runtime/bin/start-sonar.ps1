# Guard: falls PID-Datei existiert oder Port 9000 belegt ist -> stop
$pidPath = Join-Path $PSScriptRoot "..\run\sonar.pid.json"
if (Test-Path $pidPath) {
  try {
    $j = Get-Content -Raw $pidPath | ConvertFrom-Json
    Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
  } catch {}
  Remove-Item $pidPath -ErrorAction SilentlyContinue
}
$pidExisting = (Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
if ($pidExisting) {
  Stop-Process -Id $pidExisting -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot "..\run"), (Join-Path $PSScriptRoot "..\..\logs\devserver") | Out-Null
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$cmd = Join-Path $repoRoot ".sonarqube\sonarqube-26.1.0.118079\bin\windows-x86-64\StartSonar.bat"
if (-not (Test-Path -LiteralPath $cmd -PathType Leaf)) {
  throw "SonarQube-Startskript fehlt: $cmd"
}
$log = Join-Path $PSScriptRoot "..\..\logs\devserver\sonar.log"
if (Test-Path $log) {
  if ((Get-Item $log).Length -gt 200kb) {
    Move-Item $log (Join-Path (Split-Path $log) ("sonar-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log"))
  }
}
$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$cmd`" > `"$log`" 2>&1" -WorkingDirectory (Get-Location) -PassThru -WindowStyle Hidden
@{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=(Get-Location).Path; port=9000; url="http://localhost:9000/" } | ConvertTo-Json -Compress | Set-Content -NoNewline $pidPath
