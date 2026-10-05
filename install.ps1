# Husan Reels Master - one-command Windows installer
$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/sadullayevhusan78-a11y/HusanPLUGIN.git"
$ZipUrl = "https://github.com/sadullayevhusan78-a11y/HusanPLUGIN/archive/refs/heads/main.zip"
$InstallRoot = Join-Path $env:USERPROFILE "Documents\Husan Reels Master"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "HUSAN REELS MASTER" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Magenta

$insideProject = (Test-Path (Join-Path $scriptRoot "manifest.json")) -and (Test-Path (Join-Path $scriptRoot "backend\requirements.txt"))

if (-not $insideProject) {
    # Git is optional. If it exists, use it; otherwise download the GitHub ZIP.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if (Test-Path $InstallRoot) {
            Write-Host "[1/6] Existing plugin yangilanmoqda..." -ForegroundColor Cyan
            git -C $InstallRoot pull --ff-only
        } else {
            Write-Host "[1/6] Plugin GitHubdan yuklanmoqda..." -ForegroundColor Cyan
            git clone $RepoUrl $InstallRoot
        }
    } else {
        Write-Host "[1/6] Git topilmadi — GitHub ZIP orqali yuklanmoqda..." -ForegroundColor Cyan
        $tmpZip = Join-Path $env:TEMP "HusanReelsMaster.zip"
        $tmpDir = Join-Path $env:TEMP "HusanReelsMasterExtract"
        if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }

        Invoke-WebRequest -Uri $ZipUrl -OutFile $tmpZip
        Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
        $source = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
        if (-not $source) { throw "GitHub ZIP ochilmadi." }

        if (Test-Path $InstallRoot) { Remove-Item $InstallRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
        Copy-Item (Join-Path $source.FullName "*") $InstallRoot -Recurse -Force
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot "install.ps1")
    exit $LASTEXITCODE
}

$Root = $scriptRoot
Set-Location $Root

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python topilmadi. Python 3.11+ o'rnating."
}

$devDir = Join-Path $env:CommonProgramFiles "Adobe\UXP\Developer"
New-Item -ItemType Directory -Force -Path $devDir | Out-Null
$settings = Join-Path $devDir "settings.json"
$settingsJson = @{ developer = $true } | ConvertTo-Json
Set-Content -Path $settings -Value $settingsJson -Encoding UTF8
Write-Host "[2/6] UXP Developer Mode yoqildi." -ForegroundColor Green

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "[3/6] Python environment yaratilmoqda..." -ForegroundColor Cyan
    py -3.11 -m venv .venv
}

Write-Host "[4/6] AI dependencylari o'rnatilmoqda..." -ForegroundColor Cyan
& ".venv\Scripts\python.exe" -m pip install --upgrade pip
& ".venv\Scripts\python.exe" -m pip install -r "backend\requirements.txt"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
if (-not $ffmpeg -or -not $ffprobe) {
    Write-Host "[!] FFmpeg/ffprobe topilmadi." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id Gyan.FFmpeg.Shared -e --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Host "FFmpegni qo'lda o'rnatish kerak." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Winget topilmadi. FFmpegni qo'lda o'rnating." -ForegroundColor Yellow
    }
}

$healthOk = $false
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8765/health" -TimeoutSec 2
    if ($health.ok -eq $true) { $healthOk = $true }
} catch {}

if (-not $healthOk) {
    Write-Host "[5/6] Local AI engine ishga tushmoqda..." -ForegroundColor Cyan
    Start-Process -FilePath (Join-Path $Root "start_server.bat") -WorkingDirectory $Root
} else {
    Write-Host "[5/6] Local AI engine allaqachon ishlayapti." -ForegroundColor Green
}

$udtCandidates = @(
  "$env:ProgramFiles\Adobe\UXP Developer Tool\UXP Developer Tool.exe",
  "$env:ProgramFiles\Adobe\UXP Developer Tools\UXP Developer Tools.exe",
  "$env:LOCALAPPDATA\Programs\Adobe\UXP Developer Tool\UXP Developer Tool.exe"
)
$udt = $udtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($udt) {
    Start-Process $udt
    Write-Host "[6/6] UXP Developer Tool ochildi." -ForegroundColor Green
} else {
    Write-Host "[6/6] UXP Developer Tool topilmadi — keyin o'rnatamiz." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " INSTALL TAYYOR" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Plugin papkasi: $Root"
Write-Host ""
Write-Host "BIRINCHI MARTA:" -ForegroundColor Cyan
Write-Host "1. UXP Developer Tool -> Add Plugin"
Write-Host "2. $Root"
Write-Host "3. Load & Watch"
Write-Host "4. After Effects -> Window -> Husan Reels Master"
Write-Host "5. Video layerni tanlang -> AUTO MONTAGE"
