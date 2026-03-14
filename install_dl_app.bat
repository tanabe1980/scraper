@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%.") do set "REPO_ROOT=%%~fI"

if not exist "%REPO_ROOT%\docker-compose.yml" (
  echo [ERROR] docker-compose.yml was not found in:
  echo         %REPO_ROOT%
  exit /b 1
)

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] docker command was not found.
  echo [HINT] Install Docker Desktop and ensure docker is on PATH.
  exit /b 1
)

docker compose version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] docker compose command is not available.
  echo [HINT] Update Docker Desktop to a version that supports docker compose.
  exit /b 1
)

call :ensure_dir "%REPO_ROOT%\dl_app\docker\data\history"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\docker\data\downloads"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\docker\data\postgres"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\docker\src\bootstrap"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\docker\src\overrides"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\test\unit"
if errorlevel 1 exit /b 1
call :ensure_dir "%REPO_ROOT%\dl_app\test\fixtures"
if errorlevel 1 exit /b 1

echo [INFO] Building container image...
docker compose -f "%REPO_ROOT%\docker-compose.yml" build dl-app-worker
if errorlevel 1 goto :docker_failed

echo [INFO] Starting containers...
docker compose -f "%REPO_ROOT%\docker-compose.yml" up -d dl-app-postgres dl-app-worker
if errorlevel 1 goto :docker_failed

echo [INFO] Install completed.
echo [INFO] Check status with:
echo        docker compose -f "%REPO_ROOT%\docker-compose.yml" ps
exit /b 0

:ensure_dir
set "TARGET_DIR=%~1"
if not exist "%TARGET_DIR%" (
  mkdir "%TARGET_DIR%" >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Failed to create directory: %TARGET_DIR%
    exit /b 1
  )
  echo [INFO] Created directory: %TARGET_DIR%
) else (
  echo [INFO] Directory exists: %TARGET_DIR%
)
exit /b 0

:docker_failed
echo [ERROR] Docker command failed.
echo [HINT] Start Docker Desktop, then retry this batch.
exit /b 1
