# Husan Reels Master - Professional One-Click Windows Installer
# Installs the local AI engine, Python environment, FFmpeg check and opens UXP Developer Tool.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoName = "sadullayevhusan78-a11y/HusanPLUGIN"
$ZipUrl = "https://codeload.github.com/$RepoName/zip/refs/heads/main"
$InstallRoot = Join-Path $env:USERPROFILE "Documents\Husan Reels Master"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path ([IO.Path]::GetTempPath()) ("husan-reels-" + [guid]::NewGuid().ToString("N"))
$logRoot = Join-Path $env:LOCALAPPDATA "HusanReelsMaster"
$logPath = Join-Path $logRoot "install.log"

$previousProgress = $ProgressPreference
$ProgressPreference = "SilentlyContinue"
$transcriptStarted = $false

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Invoke-Download {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$OutFile
    )
    $attempt = 0
    while ($attempt -lt 3) {
        $attempt++
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            if ((Test-Path -LiteralPath $OutFile) -and ((Get-Item -LiteralPath $OutFile).Length -gt 0)) {
                return
            }
            throw "Downloaded file is empty."
        } catch {
            if ($attempt -ge 3) { throw }
            Start-Sleep -Seconds 2
        }
    }
}

function Find-Python {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        foreach ($version in @("-3.12","-3.11","-3.10")) {
            try {
                $candidate = (& py $version -c "import sys; print(sys.executable)" 2>$null)
                if ($LASTEXITCODE -eq 0 -and $candidate) {
                    $path = $candidate.Trim()
                    if (Test-Path -LiteralPath $path) { return $path }
                }
            } catch {}
        }
    }

    foreach ($command in @("python","python3")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { continue }
        try {
            $version = (& $command -c "import sys; print('%d.%d' % (sys.version_info[0], sys.version_info[1]))" 2>$null)
            if ($LASTEXITCODE -eq 0 -and $version -match "^3\.(10|11|12)$") {
                $path = (& $command -c "import sys; print(sys.executable)" 2>$null).Trim()
                if (Test-Path -LiteralPath $path) { return $path }
            }
        } catch {}
    }

    return $null
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path","Machine")
    $user = [Environment]::GetEnvironmentVariable("Path","User")
    $env:Path = "$machine;$user"
}

try {
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

    try {
        Start-Transcript -Path $logPath -Append -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
    } catch {
        Write-Warn "Install log yozilmadi: $($_.Exception.Message)"
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "        HUSAN REELS MASTER INSTALLER" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "Local AI + After Effects UXP"
    Write-Host "Log: $logPath"

    $insideProject = (Test-Path (Join-Path $scriptRoot "manifest.json")) -and
                     (Test-Path (Join-Path $scriptRoot "backend\requirements.txt"))

    if (-not $insideProject) {
        Write-Step "[1/8] Husan Reels Master GitHubdan yuklanmoqda..."

        $archive = Join-Path $work "HusanReelsMaster.zip"
        $extract = Join-Path $work "extract"

        Invoke-Download -Uri $ZipUrl -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force

        $source = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if (-not $source) {
            throw "GitHub ZIP ichidan loyiha topilmadi."
        }

        if (-not (Test-Path (Join-Path $source.FullName "manifest.json"))) {
            throw "Plugin manifest.json topilmadi."
        }

        if (Test-Path -LiteralPath $InstallRoot) {
            Write-Host "Eski plugin yangilanmoqda..." -ForegroundColor Yellow
            Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        }

        New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $source.FullName "*") -Destination $InstallRoot -Recurse -Force

        Write-Ok "Plugin fayllari yuklandi."
        $next = Join-Path $InstallRoot "install.ps1"
        if (-not (Test-Path -LiteralPath $next)) {
            throw "Installer nusxasi topilmadi."
        }

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $next
        if ($LASTEXITCODE -ne 0) {
            throw "Ichki installer $LASTEXITCODE kodi bilan tugadi."
        }
        exit 0
    }

    $Root = $scriptRoot
    Set-Location -LiteralPath $Root

    Write-Step "[2/8] Loyiha fayllari tekshirilmoqda..."
    $requiredFiles = @(
        "manifest.json",
        "index.html",
        "style.css",
        "main.js",
        "backend\server.py",
        "backend\requirements.txt",
        "start_server.bat"
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $file))) {
            throw "Kerakli fayl topilmadi: $file"
        }
    }
    Write-Ok "Barcha asosiy fayllar mavjud."

    Write-Step "[3/8] Python tekshirilmoqda..."
    $python = Find-Python

    if (-not $python) {
        Write-Warn "Python 3.10-3.12 topilmadi."

        $uv = $null
        if (Get-Command uv -ErrorAction SilentlyContinue) {
            $uv = (Get-Command uv).Source
        } else {
            $uvScript = Join-Path $work "uv-install.ps1"
            Write-Host "uv o'rnatilmoqda..." -ForegroundColor Yellow
            Invoke-Download -Uri "https://astral.sh/uv/install.ps1" -OutFile $uvScript
            $uvInstallDir = Join-Path $work "uv-bin"
            $env:UV_UNMANAGED_INSTALL = $uvInstallDir
            $shell = (Get-Process -Id $PID).Path
            & $shell -NoProfile -ExecutionPolicy Bypass -File $uvScript
            if ($LASTEXITCODE -ne 0) {
                throw "uv o'rnatilmadi. Kod: $LASTEXITCODE"
            }
            $uv = Join-Path $uvInstallDir "uv.exe"
        }

        if (-not (Test-Path -LiteralPath $uv)) {
            throw "uv.exe topilmadi."
        }

        Write-Host "Python 3.12 yuklanmoqda..." -ForegroundColor Yellow
        & $uv python install 3.12
        if ($LASTEXITCODE -ne 0) {
            throw "Python 3.12 yuklanmadi."
        }

        $python = (& $uv python find 3.12 2>$null).Trim()
        if (-not $python -or -not (Test-Path -LiteralPath $python)) {
            throw "Python 3.12 executable topilmadi."
        }
    }

    $pythonVersion = (& $python -c "import sys; print('%d.%d.%d' % sys.version_info[:3])").Trim()
    Write-Ok "Python $pythonVersion topildi."

    Write-Step "[4/8] Virtual environment tayyorlanmoqda..."
    $venvPython = Join-Path $Root ".venv\Scripts\python.exe"

    if (-not (Test-Path -LiteralPath $venvPython)) {
        & $python -m venv (Join-Path $Root ".venv")
        if ($LASTEXITCODE -ne 0) {
            throw "Python virtual environment yaratilmadi."
        }
    }
    Write-Ok "Python environment tayyor."

    Write-Step "[5/8] AI dependencylari o'rnatilmoqda..."
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw "pip yangilanmadi."
    }

    & $venvPython -m pip install -r (Join-Path $Root "backend\requirements.txt")
    if ($LASTEXITCODE -ne 0) {
        throw "AI dependencylari o'rnatilmadi."
    }
    Write-Ok "Faster-Whisper va backend dependencylari tayyor."

    Write-Step "[6/8] FFmpeg tekshirilmoqda..."
    Refresh-Path
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue

    if (-not $ffmpeg -or -not $ffprobe) {
        Write-Warn "FFmpeg/ffprobe topilmadi."

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Winget orqali FFmpeg o'rnatilmoqda..." -ForegroundColor Yellow
            try {
                winget install --id Gyan.FFmpeg.Shared -e --accept-source-agreements --accept-package-agreements
            } catch {
                Write-Warn "Winget FFmpegni o'rnata olmadi."
            }

            Refresh-Path
            $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
            $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
        }
    }

    if (-not $ffmpeg -or -not $ffprobe) {
        Write-Warn "FFmpeg hali topilmadi. Video montaj ishlashi uchun FFmpeg PATHda bo'lishi kerak."
    } else {
        $ffVersion = (& ffmpeg -version 2>$null | Select-Object -First 1)
        Write-Ok "FFmpeg tayyor: $ffVersion"
    }

    Write-Step "[7/8] UXP Developer Mode va Local AI Engine tayyorlanmoqda..."
    $devDir = Join-Path $env:CommonProgramFiles "Adobe\UXP\Developer"
    New-Item -ItemType Directory -Path $devDir -Force | Out-Null

    $settings = Join-Path $devDir "settings.json"
    $settingsJson = @{ developer = $true } | ConvertTo-Json
    Set-Content -LiteralPath $settings -Value $settingsJson -Encoding UTF8
    Write-Ok "UXP Developer Mode konfiguratsiyasi yozildi."

    $healthOk = $false
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8765/health" -TimeoutSec 2
        if ($health.ok -eq $true) {
            $healthOk = $true
        }
    } catch {}

    if (-not $healthOk) {
        $serverBat = Join-Path $Root "start_server.bat"
        Start-Process -FilePath $serverBat -WorkingDirectory $Root
        Write-Host "Local AI Engine ishga tushirildi. Server tayyorlanmoqda..." -ForegroundColor Yellow
    } else {
        Write-Ok "Local AI Engine allaqachon ishlayapti."
    }

    Start-Sleep -Seconds 2

    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8765/health" -TimeoutSec 3
        if ($health.ok -eq $true) {
            Write-Ok "Local AI Engine /health javob berdi."
        }
    } catch {
        Write-Warn "Server hali ishga tushayotgan bo'lishi mumkin. start_server.bat ni yopmang."
    }

    Write-Step "[8/8] UXP Developer Tool topilmoqda..."
    $udtCandidates = @(
        (Join-Path $env:ProgramFiles "Adobe\UXP Developer Tool\UXP Developer Tool.exe"),
        (Join-Path $env:ProgramFiles "Adobe\UXP Developer Tools\UXP Developer Tools.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Adobe\UXP Developer Tool\UXP Developer Tool.exe")
    )

    $udt = $udtCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if ($udt) {
        Start-Process -FilePath $udt
        Write-Ok "UXP Developer Tool ochildi."
    } else {
        Write-Warn "UXP Developer Tool topilmadi."
        Write-Host "Uni o'rnatgandan keyin pluginni Add Plugin -> Load & Watch qiling." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "          HUSAN REELS MASTER READY" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Plugin papkasi:" -ForegroundColor Cyan
    Write-Host $Root
    Write-Host ""
    Write-Host "AFTER EFFECTSDA:" -ForegroundColor Cyan
    Write-Host "1. UXP Developer Tool -> Add Plugin"
    Write-Host "2. $Root"
    Write-Host "3. Load & Watch"
    Write-Host "4. After Effects -> Window -> Husan Reels Master"
    Write-Host "5. Video layerni tanlang"
    Write-Host "6. AUTO MONTAGE bosing"
    Write-Host ""
    Write-Host "AI Engine: http://localhost:8765/health"
    Write-Host "Log: $logPath"
    Write-Host ""
    Write-Host "O'rnatish tugadi." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "       HUSAN REELS MASTER INSTALL ERROR" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Xato jurnali: $logPath" -ForegroundColor Yellow
    throw
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    $ProgressPreference = $previousProgress
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
