# Husan Reels Master - one-command Windows installer
$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/sadullayevhusan78-a11y/HusanPLUGIN.git"
$InstallRoot = Join-Path $env:USERPROFILE "Documents\Husan Reels Master"
$Marker = Join-Path $InstallRoot ".husan-installed"

Write-Host ""
Write-Host "HUSAN REELS MASTER" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Magenta

# If this script was launched from a temporary/download folder, clone the real project
# into Documents and re-run the installer from there.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$insideProject = (Test-Path (Join-Path $scriptRoot "manifest.json")) -and (Test-Path (Join-Path $scriptRoot "backend\requirements.txt"))

if (-not $insideProject) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git topilmadi. Git o'rnating va PowerShellni qayta oching."
    }

    if (Test-Path $InstallRoot) {
        Write-Host "[1/6] Existing Husan Reels Master papkasi yangilanmoqda..." -ForegroundColor Cyan
        git -C $InstallRoot pull --ff-only
    } else {
        Write-Host "[1/6] Plugin GitHubdan yuklanmoqda..." -ForegroundColor Cyan
        git clone $RepoUrl $InstallRoot
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot "install.ps1")
    exit $LASTEXITCODE
}

$Root = $scriptRoot
Set-Location $Root

if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    throw "Python topilmadi. Python 3.11+ o'rnating: https://www.python.org/downloads/"
}

# Enable UXP development mode for local plugin loading.
$devDir = Join-Path $env:CommonProgramFiles "Adobe\UXP\Developer"
New-Item -ItemType Directory -Force -Path $devDir | Out-Null
$settings = Join-Path $devDir "settings.json"
Set-Content -Path $settings -Value '{ "developer": true }' -Encoding UTF8
Write-Host "[2/6] UXP Developer Mode yoqildi." -ForegroundColor Green

# Python environment.
if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "[3/6] Python virtual environment yaratilmoqda..." -ForegroundColor Cyan
    py -3.11 -m venv .venv
}

Write-Host "[4/6] AI engine dependencylari o'rnatilmoqda..." -ForegroundColor Cyan
& ".venv\Scripts\python.exe" -m pip install --upgrade pip
& ".venv\Scripts\python.exe" -m pip install -r "backend\requirements.txt"

# FFmpeg check. The backend needs ffmpeg/ffprobe available in PATH.
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue

if (-not $ffmpeg -or -not $ffprobe) {
    Write-Host "[!] FFmpeg/ffprobe PATHda topilmadi." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "    Winget orqali FFmpeg o'rnatishga urinilmoqda..." -ForegroundColor Yellow
        try {
            winget install --id Gyan.FFmpeg.Shared -e --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Host "    Avtomatik FFmpeg o'rnatilmadi. Uni qo'lda PATHga qo'shing." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    Winget yo'q. FFmpegni qo'lda o'rnating va PATHga qo'shing." -ForegroundColor Yellow
    }
}

# Start local AI server if it is not already running.
$healthOk = $false
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8765/health" -TimeoutSec 2
    if ($health.status -eq "ok") { $healthOk = $true }
} catch {}

if (-not $healthOk) {
    Write-Host "[5/6] Local AI engine ishga tushmoqda..." -ForegroundColor Cyan
    Start-Process -FilePath (Join-Path $Root "start_server.bat") -WorkingDirectory $Root
} else {
    Write-Host "[5/6] Local AI engine allaqachon ishlayapti." -ForegroundColor Green
}

# Try to launch Adobe UXP Developer Tool.
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
    Write-Host "[6/6] UXP Developer Tool topilmadi." -ForegroundColor Yellow
    Write-Host "      Adobe UXP Developer Toolni o'rnating, keyin plugin papkasini Add Plugin qiling." -ForegroundColor Yellow
}

Set-Content -Path $Marker -Value (Get-Date -Format o) -Encoding UTF8

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
Write-Host "4. After Effects -> Husan Reels Master paneli"
Write-Host "5. Video layerni tanlang -> AUTO MONTAGE"
Write-Host ""
Write-Host "Keyingi safar plugin shu papkada qoladi; installer qayta ishlatilsa GitHubdan yangilanadi." -ForegroundColor Green
