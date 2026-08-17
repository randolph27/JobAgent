@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not exist "%~dp0.ci\bin\ci.cmd" (
  echo [BOOTSTRAP] Projekt-Launcher fehlt: %~dp0.ci\bin\ci.cmd 1>&2
  echo [BOOTSTRAP] Zuerst das passende Profil installieren oder reparieren. 1>&2
  exit /b 2
)
call "%~dp0.ci\bin\ci.cmd" %*
exit /b %errorlevel%
