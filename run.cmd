@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not exist "%PWSH%" (
  echo [BOOTSTRAP] PowerShell 7.4 oder neuer ist erforderlich. 1>&2
  echo [BOOTSTRAP] Erwarteter Pfad: %PWSH% 1>&2
  exit /b 2
)
"%PWSH%" -NoLogo -NoProfile -NonInteractive -File "%~dp0Run.ps1" %*
exit /b %errorlevel%
