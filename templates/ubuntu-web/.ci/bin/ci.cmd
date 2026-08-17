@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Immutable CI runtime entrypoint. Can be called from any working directory.
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%..\.."
set "PS1=%SCRIPT_DIR%ci.ps1"

if not exist "%PS1%" (
  echo [CI] FATAL: missing "%PS1%"
  exit /b 2
)

REM Prefer PowerShell 7 (pwsh) if available, fallback to Windows PowerShell 5.1.
set "PSEXE=pwsh.exe"
where /q pwsh.exe >nul 2>&1
if errorlevel 1 set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

pushd "%REPO_ROOT%" >nul 2>&1
"%PSEXE%" -NoProfile -NonInteractive -File "%PS1%" %*
set "EC=%ERRORLEVEL%"
popd >nul 2>&1

exit /b %EC%
