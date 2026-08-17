@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%~dp0..\.."
set "LEGACY_PS1=%~dp0legacy-ci.ps1"
set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
if defined CI_BOOTSTRAP_ROOT (
  set "BOOTSTRAP_RUN=%CI_BOOTSTRAP_ROOT%\run.cmd"
) else (
  set "BOOTSTRAP_RUN=D:\_Scripte\Bootstrap\run.cmd"
)
if exist "%BOOTSTRAP_RUN%" if exist "%PWSH%" (
  call "%BOOTSTRAP_RUN%" "%REPO_ROOT%" %*
  exit /b %errorlevel%
)
echo [BOOTSTRAP] WARNUNG: Zentrale Runtime oder PowerShell 7 fehlt; verwende unverkuerzten Legacy-Fallback. 1>&2
echo [BOOTSTRAP] Zentral: %BOOTSTRAP_RUN% 1>&2
if not exist "%LEGACY_PS1%" (
  echo [BOOTSTRAP] Legacy-Entrypoint fehlt: %LEGACY_PS1% 1>&2
  echo [BOOTSTRAP] Reparatur: D:\_Scripte\Bootstrap\bootstrap.cmd Repair -TargetRoot "%REPO_ROOT%" 1>&2
  exit /b 2
)
if exist "%PWSH%" (
  set "PS_EXE=%PWSH%"
) else (
  set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)
if not exist "%PS_EXE%" (
  echo [BOOTSTRAP] Weder PowerShell 7 noch Windows PowerShell 5.1 gefunden. 1>&2
  exit /b 2
)
pushd "%REPO_ROOT%" >nul
"%PS_EXE%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%LEGACY_PS1%" %*
set "CI_EXIT=%errorlevel%"
popd
exit /b %CI_EXIT%
