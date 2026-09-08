@echo off
setlocal EnableExtensions

set "CONTAINER_NAME=jobagent-sonarqube-local"
set "SONAR_IMAGE=sonarqube:lts-community"
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

if /I "%ACTION%"=="start" goto :start
if /I "%ACTION%"=="stop" goto :stop
if /I "%ACTION%"=="status" goto :status
if /I "%ACTION%"=="rm" goto :rm

echo [sonar.cmd] usage: sonar.cmd [start^|stop^|status^|rm]
exit /b 2

:start
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:9000/api/system/status' -TimeoutSec 5; if ($r.Content -match '\"status\"\s*:\s*\"UP\"') { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>nul
if "%ERRORLEVEL%"=="0" (
  echo [sonar.cmd] SonarQube already reachable at http://localhost:9000/.
  exit /b 0
)
for /f "usebackq delims=" %%I in (`docker ps -a -q -f name^=%CONTAINER_NAME% 2^>nul`) do set "CID=%%I"
if defined CID (
  for /f "usebackq delims=" %%R in (`docker inspect -f "{{.State.Running}}" %CONTAINER_NAME% 2^>nul`) do set "RUNNING=%%R"
  if /I "%RUNNING%"=="true" (
    echo [sonar.cmd] %CONTAINER_NAME% already running.
    exit /b 0
  )
  echo [sonar.cmd] starting existing container %CONTAINER_NAME%...
  docker start %CONTAINER_NAME%
  exit /b %ERRORLEVEL%
)

echo [sonar.cmd] creating container %CONTAINER_NAME% from %SONAR_IMAGE%...
docker run -d --name %CONTAINER_NAME% -p 9000:9000 -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true %SONAR_IMAGE%
exit /b %ERRORLEVEL%

:stop
echo [sonar.cmd] stopping %CONTAINER_NAME%...
docker stop %CONTAINER_NAME% >nul 2>nul
exit /b 0

:status
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:9000/api/system/status' -TimeoutSec 5; Write-Output $r.Content; if ($r.Content -match '\"status\"\s*:\s*\"UP\"') { exit 0 }; exit 1 } catch { exit 1 }"
if "%ERRORLEVEL%"=="0" exit /b 0
docker ps -a --filter "name=%CONTAINER_NAME%" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
exit /b %ERRORLEVEL%

:rm
echo [sonar.cmd] removing %CONTAINER_NAME%...
docker rm -f %CONTAINER_NAME% >nul 2>nul
exit /b 0
