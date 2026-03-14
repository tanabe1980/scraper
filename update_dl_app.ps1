param(
    [string]$InstallRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-RobocopyChecked {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$Options
    )

    & robocopy $Source $Destination @Options | Out-Null
    $exitCode = $LASTEXITCODE
    if ($exitCode -gt 7) {
        throw "robocopy failed (exit code: $exitCode) Source=$Source Destination=$Destination"
    }
}

function Ensure-Command {
    param([string]$CommandName)
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $CommandName"
    }
}

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = $PSScriptRoot
}

$installRootResolved = (Resolve-Path $InstallRoot).Path
$configPath = Join-Path $installRootResolved "dl_app_release_config.json"
$configExamplePath = Join-Path $installRootResolved "dl_app_release_config.json.example"

if (-not (Test-Path $configPath)) {
    $message = "Config file not found: $configPath"
    if (Test-Path $configExamplePath) {
        $message += ". Copy from dl_app_release_config.json.example and set nas_releases_root."
    }
    throw $message
}

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
if (-not $config.nas_releases_root) {
    throw "nas_releases_root is required in dl_app_release_config.json."
}
$nasRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string]$config.nas_releases_root)

$latestPath = Join-Path $nasRoot "latest.json"
if (-not (Test-Path $latestPath)) {
    throw "latest.json not found: $latestPath"
}
$latest = Get-Content -Path $latestPath -Raw | ConvertFrom-Json
if (-not $latest.version -or -not $latest.package) {
    throw "latest.json must include version and package."
}

$versionFile = Join-Path $installRootResolved ".installed-version"
$currentVersion = ""
if (Test-Path $versionFile) {
    $currentVersion = (Get-Content -Path $versionFile -Raw).Trim()
}
if ($currentVersion -eq [string]$latest.version) {
    Write-Host "[INFO] Already up-to-date. version=$currentVersion"
    exit 0
}

$packageRelative = ([string]$latest.package).Replace("/", "\")
$packagePath = Join-Path $nasRoot $packageRelative
if (-not (Test-Path $packagePath)) {
    throw "Release package not found: $packagePath"
}

$tempRoot = Join-Path $env:TEMP ("dl_app_update_" + [guid]::NewGuid().ToString("N"))
$localZip = Join-Path $tempRoot "release.zip"
$extractRoot = Join-Path $tempRoot "extract"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

Copy-Item -Path $packagePath -Destination $localZip -Force

if ($latest.sha256) {
    $actualHash = (Get-FileHash -Path $localZip -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = ([string]$latest.sha256).ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA256 mismatch. expected=$expectedHash actual=$actualHash"
    }
}

Expand-Archive -Path $localZip -DestinationPath $extractRoot -Force

$extractComposePath = Join-Path $extractRoot "docker-compose.yml"
if (-not (Test-Path $extractComposePath)) {
    throw "Release package is invalid. docker-compose.yml is missing."
}

Ensure-Command -CommandName "docker"
Ensure-Command -CommandName "robocopy"

$currentComposePath = Join-Path $installRootResolved "docker-compose.yml"
if (Test-Path $currentComposePath) {
    Write-Host "[INFO] Stopping current containers..."
    & docker compose -f $currentComposePath down
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose down failed."
    }
}

Write-Host "[INFO] Applying release files..."
Get-ChildItem -Path $extractRoot -Force | ForEach-Object {
    $destination = Join-Path $installRootResolved $_.Name
    if ($_.PSIsContainer) {
        Invoke-RobocopyChecked -Source $_.FullName -Destination $destination -Options @(
            "/E",
            "/NFL",
            "/NDL",
            "/NJH",
            "/NJS",
            "/XF", "*.pyc"
        )
    } else {
        Copy-Item -Path $_.FullName -Destination $destination -Force
    }
}

$installBatchPath = Join-Path $installRootResolved "install_dl_app.bat"
if (-not (Test-Path $installBatchPath)) {
    throw "install_dl_app.bat not found after update."
}

Write-Host "[INFO] Running install script..."
& cmd.exe /c "`"$installBatchPath`""
if ($LASTEXITCODE -ne 0) {
    throw "install_dl_app.bat failed."
}

Set-Content -Path $versionFile -Value ([string]$latest.version) -NoNewline
Remove-Item -Path $tempRoot -Recurse -Force

Write-Host "[INFO] Update completed. version=$($latest.version)"
