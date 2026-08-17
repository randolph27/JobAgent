@echo off
setlocal EnableExtensions

REM Root CI entrypoint. Always delegate to the immutable CI runtime under .ci\bin.
REM Headless loop commands such as "codex-loop" and "codex-loop-finish" are handled there as well.
set "REPO_ROOT=%~dp0"
set "BIN=%REPO_ROOT%.ci\bin\ci.cmd"

if not exist "%BIN%" (
  echo [CI] FATAL: missing "%BIN%"
  echo [CI] Hint: restore ".ci\bin\ci.cmd" from template.
  exit /b 2
)

call "%BIN%" %*
exit /b %ERRORLEVEL%
