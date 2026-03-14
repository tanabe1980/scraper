param(
    [string]$NasReleasesRoot = "",
    [string]$Version = "",
    [switch]$SkipGitChecks
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

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($NasReleasesRoot)) {
    $NasReleasesRoot = $env:DL_APP_NAS_RELEASES_ROOT
}
if ([string]::IsNullOrWhiteSpace($NasReleasesRoot)) {
    throw "Specify -NasReleasesRoot or set DL_APP_NAS_RELEASES_ROOT."
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Date -Format "yyyyMMdd-HHmmss")
}

$nasRootResolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NasReleasesRoot)

Ensure-Command -CommandName "git"
Ensure-Command -CommandName "robocopy"

if (-not $SkipGitChecks) {
    Push-Location $repoRoot
    try {
        $branch = (git rev-parse --abbrev-ref HEAD).Trim()
        if ($branch -ne "main") {
            throw "Current branch must be main. Current: $branch"
        }

        $dirty = git status --porcelain
        if (-not [string]::IsNullOrWhiteSpace(($dirty | Out-String))) {
            throw "Working tree is not clean. Commit/stash changes before publish."
        }

        git fetch origin main | Out-Null
        $localCommit = (git rev-parse HEAD).Trim()
        $remoteCommit = (git rev-parse origin/main).Trim()
        if ($localCommit -ne $remoteCommit) {
            throw "Local HEAD is not origin/main. Run git pull before publish."
        }
    } finally {
        Pop-Location
    }
}

$tempRoot = Join-Path $env:TEMP ("dl_app_release_" + [guid]::NewGuid().ToString("N"))
$stageRoot = Join-Path $tempRoot "payload"
$zipName = "dl_app-$Version.zip"
$zipLocalPath = Join-Path $tempRoot $zipName

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

$rootFiles = @(
    "docker-compose.yml",
    "install_dl_app.bat",
    "update_dl_app.bat",
    "update_dl_app.ps1",
    "dl_app_release_config.json.example"
)

foreach ($file in $rootFiles) {
    $source = Join-Path $repoRoot $file
    if (-not (Test-Path $source)) {
        throw "Required release file is missing: $file"
    }
    Copy-Item -Path $source -Destination (Join-Path $stageRoot $file) -Force
}

$sourceDlApp = Join-Path $repoRoot "dl_app"
$destDlApp = Join-Path $stageRoot "dl_app"
Invoke-RobocopyChecked -Source $sourceDlApp -Destination $destDlApp -Options @(
    "/E",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/XD", "docker\data\postgres", "docker\data\downloads", "docker\data\history",
    "/XF", "*.pyc"
)

Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $zipLocalPath -Force

$hashValue = (Get-FileHash -Path $zipLocalPath -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseDir = Join-Path $nasRootResolved $Version
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$zipNasPath = Join-Path $releaseDir $zipName
Copy-Item -Path $zipLocalPath -Destination $zipNasPath -Force
Set-Content -Path (Join-Path $releaseDir "$zipName.sha256") -Value $hashValue -NoNewline

$manifest = [ordered]@{
    version = $Version
    package = "$Version/$zipName"
    sha256 = $hashValue
    released_at = (Get-Date).ToString("o")
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4

Set-Content -Path (Join-Path $releaseDir "release.json") -Value $manifestJson

$latestTemp = Join-Path $nasRootResolved "latest.json.tmp"
$latestPath = Join-Path $nasRootResolved "latest.json"
Set-Content -Path $latestTemp -Value $manifestJson
Move-Item -Path $latestTemp -Destination $latestPath -Force

Remove-Item -Path $tempRoot -Recurse -Force

Write-Host "[INFO] Published release to NAS."
Write-Host "[INFO] Version: $Version"
Write-Host "[INFO] Latest manifest: $latestPath"
