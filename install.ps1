$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
Write-Host ""
Write-Host "HUSAN REELS MASTER - INSTALLER" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git topilmadi. Git o'rnating." }
if (-not (Get-Command py -ErrorAction SilentlyContinue)) { throw "Python topilmadi. Python 3.11+ o'rnating." }

$devDir = Join-Path $env:CommonProgramFiles "Adobe\UXP\Developer"
New-Item -ItemType Directory -Force -Path $devDir | Out-Null
$settings = Join-Path $devDir "settings.json"
Set-Content -Path $settings -Value '{ "developer": true }' -Encoding UTF8
Write-Host "[OK] UXP Developer Mode enabled." -ForegroundColor Green

if (-not (Test-Path ".venv")) { py -3.11 -m venv .venv }
& ".venv\Scripts\python.exe" -m pip install --upgrade pip
& ".venv\Scripts\python.exe" -m pip install -r "backend\requirements.txt"
Start-Process -FilePath (Join-Path $Root "start_server.bat") -WorkingDirectory $Root

$udtCandidates = @(
  "$env:ProgramFiles\Adobe\UXP Developer Tool\UXP Developer Tool.exe",
  "$env:ProgramFiles\Adobe\UXP Developer Tools\UXP Developer Tools.exe",
  "$env:LOCALAPPDATA\Programs\Adobe\UXP Developer Tool\UXP Developer Tool.exe"
)
$udt = $udtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($udt) { Start-Process $udt; Write-Host "[OK] UXP Developer Tool launched." -ForegroundColor Green }
else { Write-Host "[!] UXP Developer Tool topilmadi. Creative Cloud orqali o'rnating." -ForegroundColor Yellow }

Write-Host ""
Write-Host "KEYINGI QADAM:" -ForegroundColor Cyan
Write-Host "1. After Effectsni oching."
Write-Host "2. UXP Developer Toolda Add Plugin bosing."
Write-Host "3. Shu papkani tanlang: $Root"
Write-Host "4. Load & Watch bosing."
Write-Host "5. AE ichidan Husan Reels Master panelini oching."
Write-Host "6. Video layerni tanlang -> AUTO MONTAGE."
Write-Host ""
Write-Host "Tayyor. Local AI server alohida oynada ishlayapti." -ForegroundColor Green
